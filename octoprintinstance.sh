#!/bin/bash
################################################################################
# wget -O /tmp/octoprintinstance https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.sh && chmod +x /tmp/octoprintinstance && /tmp/octoprintinstance 003
################################################################################

#set -x
set -e

################################################################################

if [ -n ${1} ]; then
	INSTANCE_NUM=${1}
fi

INSTANCE_NAME="op_"${INSTANCE_NUM}
INSTANCE_API_SYSTEM=$(date | md5sum | awk -F" " '{print toupper($1)}')
INSTANCE_API_ADMIN=$(date | md5sum | awk -F" " '{print toupper($1)}')
INSTANCE_SALT="QmcSp5B7fubFuyTFkBMIbIs8fkahkbRf"
INSTANCE_PASS="e90d9e087935fb5b0d5b0b3f66a44b0459fefe41b52e9a79c397c2ec1cffc7162a51de796ee85839990ed91e4358c358bf664e796aa9ebe878329a4f1e5022fe"

if [ -z ${INSTANCE_NUM} ]; then
	echo "Argument 1 has to be a unique User Identifier, like '001' !!!"
	exit 1
fi

if [ -d /home/${INSTANCE_NUM} ]; then
	echo "The User '${INSTANCE_NAME}' already exist, or at least his Homefolder '/home/${INSTANCE_NAME}' !!!"
	exit 1
fi

################################################################################

echo "Creating new OctoPrint Instance with User ${INSTANCE_NAME} ..."

echo "Creating new User ${INSTANCE_NAME} ..."
adduser --disabled-password --disabled-login --quiet --gecos ${INSTANCE_NAME} ${INSTANCE_NAME}
usermod -a -G tty ${INSTANCE_NAME}
usermod -a -G dialout ${INSTANCE_NAME}

################################################################################

echo "Installing needed Packages ..."
apt-get update && apt-get -qyy install python-pip python-dev python-setuptools python-virtualenv git libyaml-dev build-essential

echo "Create Virtual Environment and install Octoprint for ${INSTANCE_NAME} ..."
sudo -u ${INSTANCE_NAME} sh -c 'mkdir /home/'${INSTANCE_NAME}'/OctoPrint && cd /home/'${INSTANCE_NAME}'/OctoPrint && \
virtualenv venv && \
. venv/bin/activate && \
pip install pip --upgrade && \
pip install https://get.octoprint.org/latest'

echo "Configuring Octoprint for ${INSTANCE_NAME} ..."
mkdir /home/${INSTANCE_NAME}/.octoprint
cat <<EOF > /home/${INSTANCE_NAME}/.octoprint/config.yaml
accessControl:
  salt: ${INSTANCE_SALT}
api:
  key: ${INSTANCE_API_SYSTEM}
appearance:
  color: black
  defaultLanguage: en
  name: OctoPrint Instance ${INSTANCE_NUM}
server:
  commands:
    serverRestartCommand: sudo service ${INSTANCE_NAME} restart
    systemRestartCommand: sudo shutdown -r now
    systemShutdownCommand: sudo shutdown -h now
  firstRun: false
  onlineCheck:
    enabled: true
  pluginBlacklist:
    enabled: true
  seenWizards:
    corewizard: 3
    cura: null
EOF
cat <<EOF > /home/${INSTANCE_NAME}/.octoprint/users.yaml
admin:
  active: true
  apikey: null
  apikey: ${INSTANCE_API_ADMIN}
  password: ${INSTANCE_PASS}
  roles:
  - user
  - admin
  settings: {}
EOF

chown -R ${INSTANCE_NAME}:${INSTANCE_NAME} /home/${INSTANCE_NAME}/.octoprint
chmod -R +x /home/${INSTANCE_NAME}/.octoprint

################################################################################

echo "Creating Octoprint Service for ${INSTANCE_NAME} ..."
wget -O /tmp/octoprintinstance.init https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.init
wget -O /tmp/octoprintinstance.default https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.default
cat /tmp/octoprintinstance.init | sed 's/@@@OP_NUM@@/'${INSTANCE_NUM}'/g' > /tmp/${INSTANCE_NAME}.init
cat /tmp/octoprintinstance.default | sed 's/@@@OP_NUM@@/'${INSTANCE_NUM}'/g' > /tmp/${INSTANCE_NAME}.default
mv -f /tmp/${INSTANCE_NAME}.init /etc/init.d/${INSTANCE_NAME}
mv -f /tmp/${INSTANCE_NAME}.default /etc/default/${INSTANCE_NAME}
chmod +x /etc/init.d/${INSTANCE_NAME}

echo "Enabling Octoprint Service for ${INSTANCE_NAME} ..."
update-rc.d ${INSTANCE_NAME} defaults

echo "Starting Octoprint Service for ${INSTANCE_NAME} ..."
service ${INSTANCE_NAME} start

################################################################################
# delete a existing OctoPrint Instance
#service op_003 stop
#userdel op_003
#rm -Rf /home/op_003

################################################################################

exit 0
