
################################################################################
#wget -O /tmp/octoprintinstance https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.sh && chmod +x /tmp/octoprintinstance && /tmp/octoprintinstance 003

set -x
set -e

if [ -n ${1} ]; then
	INSTANCE_NUM=${1}
fi

INSTANCE_NAME="op_"${INSTANCE_NUM}

if [ -z ${INSTANCE_NUM} ]; then
	exit 1
fi

################################################################################

adduser --disabled-password --disabled-login --quiet --gecos ${INSTANCE_NAME} ${INSTANCE_NAME}
usermod -a -G tty ${INSTANCE_NAME}
usermod -a -G dialout ${INSTANCE_NAME}

################################################################################

apt-get update && apt-get -qyy install python-pip python-dev python-setuptools python-virtualenv git libyaml-dev build-essential

sudo -u ${INSTANCE_NAME} sh -c 'mkdir /home/'${INSTANCE_NAME}'/OctoPrint && cd /home/'${INSTANCE_NAME}'/OctoPrint && \
virtualenv venv && \
. venv/bin/activate && \
pip install pip --upgrade && \
pip install https://get.octoprint.org/latest'

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
  secretKey: nUb1QT8ZMy9JjGt6lAgs5GgJTVH4kyBY
  seenWizards:
    corewizard: 3
    cura: null

EOF

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

#service op_003 stop
#userdel op_003
#rm -Rf /home/op_003

################################################################################
