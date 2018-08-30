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
  password: b78c1d7b2b02194f102ae192c6246e084cc22a81ab7d7bc11bf6afc369ba47d42606061ba14e97085ce1b6720929b135ff3238af61030ab576cff696b564ce9e
  roles:
  - user
  - admin
  settings: {}
EOF

chown -R ${INSTANCE_NAME}:${INSTANCE_NAME} /home/${INSTANCE_NAME}/.octoprint
chmod -R +x /home/${INSTANCE_NAME}/.octoprint

################################################################################

wget -O /tmp/octoprintinstance.init https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.init
wget -O /tmp/octoprintinstance.default https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.default
cat /tmp/octoprintinstance.init | sed 's/@@@OP_NUM@@/'${INSTANCE_NUM}'/g' > /tmp/${INSTANCE_NAME}.init
cat /tmp/octoprintinstance.default | sed 's/@@@OP_NUM@@/'${INSTANCE_NUM}'/g' > /tmp/${INSTANCE_NAME}.default
mv -f /tmp/${INSTANCE_NAME}.init /etc/init.d/${INSTANCE_NAME}
mv -f /tmp/${INSTANCE_NAME}.default /etc/default/${INSTANCE_NAME}
chmod +x /etc/init.d/${INSTANCE_NAME}

update-rc.d ${INSTANCE_NAME} defaults
service ${INSTANCE_NAME} start

################################################################################
# delete a existing OctoPrint Instance
#service op_003 stop
#userdel op_003
#rm -Rf /home/op_003

################################################################################
