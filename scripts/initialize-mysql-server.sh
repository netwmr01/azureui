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

#
# This script will walk you through setting up BIND on the host and making the changes needed in
# Azure portal.
#

#
# WARNING
#
# - This script only creates one zone file which supports <= 255 hosts. It has not been tested
#   with > 255 hosts trying to use the same zone file. It "might just work", or it may require
#   manually configuring additional zone files in `/etc/named/named.conf.local` and
#   `/etc/named/zones/`.
# - It is assumed that the Azure nameserver IP address will always be `168.63.129.16`. See more
#   info: https://blogs.msdn.microsoft.com/mast/2015/05/18/what-is-the-ip-address-168-63-129-16/.
#

log() {
  echo "$(date): [${execname}] $@" >> /tmp/initialize-mysql-server.log
}

MYSQL_USER=$1
MYSQL_PASSWORD=$2

SLEEP_INTERVAL=10

log "initializing MySQL Server..."

bash ./prepare-mysql-disks.sh
status=$?
if [ $status -ne 0 ]; then log "fail to mount disk for mysql server" & exit status; fi

n=0
until [ $n -ge 5 ]
do
    sudo sudo yum install -y mysql-server >> /tmp/initialize-mysql-server.log 2>> /tmp/initialize-mysql-server.err && break
    n=$[$n+1]
    sleep ${SLEEP_INTERVAL}
done
if [ $n -ge 5 ]; then log "yum install error, exiting..." & exit 1; fi
sudo service mysqld stop

sudo cat > /etc/my.cnf <<EOF
[mysqld]
transaction-isolation = READ-COMMITTED
# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
# symbolic-links = 0

key_buffer = 16M
key_buffer_size = 32M
max_allowed_packet = 32M
thread_stack = 256K
thread_cache_size = 64
query_cache_limit = 8M
query_cache_size = 64M
query_cache_type = 1

max_connections = 550
#expire_logs_days = 10
#max_binlog_size = 100M

#log_bin should be on a disk with enough free space. Replace '/var/lib/mysql/mysql_binary_log' with an appropriate path for your system
#and chown the specified folder to the mysql user.
log_bin=/var/lib/mysql/mysql_binary_log

# For MySQL version 5.1.8 or later. Comment out binlog_format for older versions.
binlog_format = mixed

read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M

# InnoDB settings
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit  = 2
innodb_log_buffer_size = 64M
innodb_buffer_pool_size = 4G
innodb_thread_concurrency = 8
innodb_flush_method = O_DIRECT
innodb_log_file_size = 512M

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

sql_mode=STRICT_ALL_TABLES
EOF


sudo /sbin/chkconfig mysqld on
sudo service mysqld start

i=0
until [ $i -ge 5 ]
do
  i=$[$i+1]
  mysql -u root -e "SHOW DATABASES"
  n=$?
  if [ $n -eq 0 ]; then
    break;
  fi
  sleep ${SLEEP_INTERVAL}
done
if [ $i -ge 5 ]; then
  echo "DB failed to start, exit with status 1"
  exit 1
fi

log "Creating user for mysql"
mysql -u root -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'localhost' WITH GRANT OPTION"

mysql -u root -e "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD'"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' WITH GRANT OPTION"

sudo yum install -y expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"

yum remove -y expect

log "Everything should be working!"
exit 0
