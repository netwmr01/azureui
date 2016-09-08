#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# 
# See the License for the specific language governing permissions and
# limitations under the License.
log() {
  echo "$(date): [${execname}] $@" >> /tmp/initialize-director-server.log
}

ADMINUSER=$1
INTERNAL_FQDN_SUFFIX=$2
HOST_IP=$3
log $1
log $2
log $3
log "initializing Director Server..."

# Disable the need for a tty when running sudo and allow passwordless sudo for the admin user
sed -i '/Defaults[[:space:]]\+!*requiretty/s/^/#/' /etc/sudoers
echo "$ADMINUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install Director Server
sudo yum clean all >> /tmp/initialize-director-server.log
n=0
until [ $n -ge 5 ]
do
    sudo yum install -y wget epel-release>> /tmp/initialize-director-server.log 2>> /tmp/initialize-director-server.err && break
    n=$[$n+1]
    sleep 15s
done
if [ $n -ge 5 ]; then log "yum install error, exiting..." & exit 1; fi

sudo wget -t 5 http://archive.cloudera.com/director/redhat/6/x86_64/director/cloudera-director.repo -O /etc/yum.repos.d/cloudera-director.repo >> /tmp/initialize-director-server.log

# this often fails so adding retry logic
n=0
until [ $n -ge 5 ]
do
    sudo yum install -y bind bind-utils python-pip oracle-j2sdk* cloudera-director-server-2.1.* cloudera-director-client-2.1.* >> /tmp/initialize-director-server.log 2>> /tmp/initialize-director-server.err && break
    n=$[$n+1]
    sleep 15s
done
if [ $n -ge 5 ]; then log "yum install error, exiting..." & exit 1; fi

n=0
until [ $n -ge 5 ]
do
    sudo pip install -r requirements.txt >> /tmp/initialize-director-server.log 2>> /tmp/initialize-director-server.err && break
    n=$[$n+1]
    sleep 15s
done
if [ $n -ge 5 ]; then log "pip install error, exiting..." & exit 1; fi

sudo service cloudera-director-server start
sudo chkconfig iptables off
sudo service iptables stop

# Setup DNS server
bash ./initialize-dns-server.sh ${INTERNAL_FQDN_SUFFIX} ${HOST_IP}
status=$?
if [ $status -ne 0 ]; then log "fail to setup dns server" & exit status; fi

log "Everything should be working!"
exit 0

