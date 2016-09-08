from pyhocon import ConfigFactory
from pyhocon import tool
from urllib2 import HTTPError
from cloudera.director.latest.models import Login, User
from cloudera.director.common.client import ApiClient
from cloudera.director.latest import AuthenticationApi, UsersApi
import sys
import os
import logging

#loging starts
logging.basicConfig(filename='/tmp/prepare-director-conf.log', level=logging.DEBUG)
logging.info('started')

class ExitCodes(object):
    OK = 0
    DUPLICATE_USER = 10

def setInstanceParameters (section, machineType, networkSecurityGroupResourceGroup, networkSecurityGroup, virtualNetworkResourceGroup,
                           virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix):
  conf.put(section+'.type', machineType)
  conf.put(section+'.networkSecurityGroupResourceGroup', networkSecurityGroupResourceGroup)
  conf.put(section+'.networkSecurityGroup', networkSecurityGroup)
  conf.put(section+'.virtualNetworkResourceGroup', virtualNetworkResourceGroup)
  conf.put(section+'.virtualNetwork', virtualNetwork)
  conf.put(section+'.subnetName', subnetName)
  conf.put(section+'.computeResourceGroup', computeResourceGroup)
  conf.put(section+'.hostFqdnSuffix', hostFqdnSuffix)

def writeToFile(privateKey, keyFileName):
  target = open(keyFileName, 'w')
  target.truncate()
  target.write(privateKey)
  target.close()

def secure_user(username, password):
    """
    Create a new user account
    @param args: dict of parsed command line arguments that include
                 an username and a password for the new account
    @return:     script exit code
    """
    # Cloudera Director server runs at http://127.0.0.1:7189
    try:
      client = ApiClient("http://localhost:7189")
      AuthenticationApi(client).login(Login(username="admin", password="admin"))
      #create new login base on user input
      users_api = UsersApi(client)
      users_api.create(User(username=username, password=password, enabled=True, roles=["ROLE_ADMIN"]))

      # delete default user access
      AuthenticationApi(client).login(Login(username=username, password=password))
      users_api.delete("admin")
      return ExitCodes.OK

    except HTTPError, e:
      if  e.code == 302:  # found
        # sys.stderr.write("Cannot create duplicate user '%s'.\n" % (username,))
        return ExitCodes.DUPLICATE_USER
      else:
        raise e

conf = ConfigFactory.parse_file('azure.simple.conf')
logging.info('parsed conf')
name = sys.argv[1]
region = sys.argv[2]
subscriptionId = sys.argv[3]
tenantId = sys.argv[4]
clientId = sys.argv[5]
clientSecret = sys.argv[6]

username = sys.argv[7]
passphrase = sys.argv[8]
privateKey = sys.argv[9]
keyFileName = "/tmp/keyfile"
writeToFile(privateKey, keyFileName)
logging.info(privateKey)

networkSecuritGroupResourceGroup = sys.argv[10]
networkSecurityGroup = sys.argv[11]
virtualNetworkResourceGroup = sys.argv[12]
virtualNetwork = sys.argv[13]
subnetName = sys.argv[14]
computeResourceGroup = sys.argv[15]
hostFqdnSuffix = sys.argv[16]

dbHostOrIP = sys.argv[17]
dbUsername = sys.argv[18]
dbPassword = sys.argv[19]

masterType = sys.argv[20].upper()
workerType = sys.argv[21].upper()
edgeType = sys.argv[22].upper()
dirUsername = sys.argv[23]
dirPassword = sys.argv[24]

logging.info('parameters assigned')

secure_user(dirUsername, dirPassword)
logging.info('director server secured')

conf.put('name', name)
conf.put('provider.region', region)
conf.put('provider.subscriptionId', subscriptionId)
conf.put('provider.tenantId', tenantId)
conf.put('provider.clientId', clientId)
conf.put('provider.clientSecret', clientSecret)

conf.put('ssh.username', username)
if passphrase:
  conf.put('ssh.passphrase', passphrase)
conf.put('ssh.privateKey', keyFileName)


setInstanceParameters('instances.ds14-master', masterType, networkSecuritGroupResourceGroup, networkSecurityGroup,
                      virtualNetworkResourceGroup, virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix)
setInstanceParameters('instances.ds14-worker', workerType, networkSecuritGroupResourceGroup, networkSecurityGroup,
                      virtualNetworkResourceGroup, virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix)
setInstanceParameters('instances.ds14-edge', edgeType, networkSecuritGroupResourceGroup, networkSecurityGroup,
                      virtualNetworkResourceGroup, virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix)
setInstanceParameters('cloudera-manager.instance', edgeType, networkSecuritGroupResourceGroup, networkSecurityGroup,
                      virtualNetworkResourceGroup, virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix)
setInstanceParameters('cluster.masters.instance', masterType, networkSecuritGroupResourceGroup, networkSecurityGroup,
                      virtualNetworkResourceGroup, virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix)
setInstanceParameters('cluster.workers.instance', masterType, networkSecuritGroupResourceGroup, networkSecurityGroup,
                      virtualNetworkResourceGroup, virtualNetwork, subnetName, computeResourceGroup, hostFqdnSuffix)

conf.put('databaseServers.mysqlprod1.host', dbHostOrIP)
conf.put('databaseServers.mysqlprod1.user', dbUsername)
conf.put('databaseServers.mysqlprod1.password', dbPassword)

logging.info('conf value replaced')

with open("/tmp/azure.conf", "w") as text_file:
    text_file.write(tool.HOCONConverter.to_hocon(conf))

logging.info("conf file has been written")

command="python setup-default.py --admin-username %s --admin-password %s /tmp/azure.conf"%(dirUsername, dirPassword)
logging.info(command)
os.system(command)

logging.info('finish')
