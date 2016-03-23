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
# Usage: bootstrap-cloudera-1.0.sh {clusterName} {managment_node} {cluster_nodes} {isHA} {sshUserName} [{sshPassword}]

# Put the command line parameters into named variables
IPPREFIX=$1
MASTERSTARTINGIP=$2
WORKERSTARTINGIP=$3
FULLIPADDRESS=$4
NAMEPREFIX=$5
NAMESUFFIX=$6
MASTERNODES=$7
DATANODES=$8
ADMINUSER=$9
HA=${10}
PASSWORD=${11}
CMUSER=${12}
CMPASSWORD=${13}
EMAILADDRESS=${14}
BUSINESSPHONE=${15}
FIRSTNAME=${16}
LASTNAME=${17}
JOBROLE=${18}
JOBFUNCTION=${19}
COMPANY=${20}
INSTALLCDH=${21}
VMSIZE=${22}

MasterWorderNodeAddressGap=10

CLUSTERNAME=$NAMEPREFIX

execname=$0

function atoi
{
#Returns the integer representation of an IP arg, passed in ascii dotted-decimal notation (x.x.x.x)
IP=$1; IPNUM=0
for (( i=0 ; i<4 ; ++i )); do
((IPNUM+=${IP%%.*}*$((256**$((3-${i}))))))
IP=${IP#*.}
done
echo $IPNUM
}

function itoa
{
#returns the dotted-decimal ascii form of an IP arg passed in integer format
echo -n $(($(($(($((${1}/256))/256))/256))%256)).
echo -n $(($(($((${1}/256))/256))%256)).
echo -n $(($((${1}/256))%256)).
echo $((${1}%256))
}

log() {
  echo "$(date): [${execname}] $@" 
}

log "my vmsize: $VMSIZE"
# Converts a domain like machine.domain.com to domain.com by removing the machine name
NAMESUFFIX=`echo $NAMESUFFIX | sed 's/^[^.]*\.//'`

if [[ !  -z  ${FULLIPADDRESS}  ]]; then
    IP=`atoi ${FULLIPADDRESS}`
    let "IP=i+IP"
    HOSTIP=`itoa ${IP}`
else
    let "IP=i+MASTERSTARTINGIP"
    HOSTIP="$IPPREFIX$IP"
fi

ManagementNode="$HOSTIP:${NAMEPREFIX}-mn0.$NAMESUFFIX:${NAMEPREFIX}-mn0"
mip=$(echo "$ManagementNode" | sed 's/:/ /' | sed 's/:/ /' | cut -d ' ' -f 1)

log "set private key"
#use the key from the key vault as the SSH private key
openssl rsa -in /var/lib/waagent/*.prv -out /home/$ADMINUSER/.ssh/id_rsa
chmod 600 /home/$ADMINUSER/.ssh/id_rsa
chown $ADMINUSER /home/$ADMINUSER/.ssh/id_rsa

file="/home/$ADMINUSER/.ssh/id_rsa"
key="/tmp/id_rsa.pem"
openssl rsa -in $file -outform PEM > $key

#Generate IP Addresses for the cloudera setup
NODES=()

let "NAMEEND=MASTERNODES-1"
for i in $(seq 1 $NAMEEND)
do 
  if [[ !  -z  ${FULLIPADDRESS}  ]]; then
      IP=`atoi ${FULLIPADDRESS}`
      let "IP=i+IP"
      HOSTIP=`itoa ${IP}`
  else
      let "IP=i+MASTERSTARTINGIP"
      HOSTIP="$IPPREFIX$IP"
  fi
  NODES+=("$HOSTIP:${NAMEPREFIX}-mn$i.$NAMESUFFIX:${NAMEPREFIX}-mn$i")
done

let "DATAEND=DATANODES-1"
for i in $(seq 0 $DATAEND)
do 
  if [[ !  -z  ${FULLIPADDRESS}  ]]; then
      IP=`atoi ${FULLIPADDRESS}`
      let "IP=i+IP+MasterWorderNodeAddressGap"
      HOSTIP=`itoa ${IP}`
  else
      let "IP=i+WORKERSTARTINGIP"
      HOSTIP="$IPPREFIX$IP"
  fi
  NODES+=("$HOSTIP:${NAMEPREFIX}-dn$i.$NAMESUFFIX:${NAMEPREFIX}-dn$i")
done

IFS=',';NODE_IPS="${NODES[*]}";IFS=$' \t\n'

wip_string=''
OIFS=$IFS
IFS=','
for x in $NODE_IPS
do
  log "Workier IP: $x"
  line=$(echo "$x" | sed 's/:/ /' | sed 's/:/ /')
  wip_string+=$(echo "$line" | cut -d ' ' -f 1 | sed 's/$/,/')
  log "current wip_string is: $wip_string"
done
IFS=${OIFS}
worker_ip=$(echo "${wip_string%?}")
log "Worker ip to be supplied to next script: $worker_ip"
log "BEGIN: Starting detached script to finalize initialization"
if [ "$INSTALLCDH" == "True" ]
then
  sh initialize-cloudera-server.sh "$CLUSTERNAME" "$key" "$mip" "$worker_ip" "$HA" "$ADMINUSER" "$PASSWORD" "$CMUSER" "$CMPASSWORD" "$EMAILADDRESS" "$BUSINESSPHONE" "$FIRSTNAME" "$LASTNAME" "$JOBROLE" "$JOBFUNCTION" "$COMPANY" "$VMSIZE">/dev/null 2>&1
fi
log "END: Detached script to finalize initialization running. PID: $!"

