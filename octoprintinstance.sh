#!/bin/bash
################################################################################
# wget --no-check-certificate -O /root/octoprintinstance https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.sh && chmod +x /root/octoprintinstance && /root/octoprintinstance -l
# for ((i=1; i<=9; i++)); do ./octoprintinstance 00$i &; done
################################################################################

function OctoPrintInstance_installDeps() {
	echo "Installing needed Packages ..."
	#apt-get update && 
	apt-get -qyy install psmisc virtualenv python-pip python-dev python-setuptools python-virtualenv git libyaml-dev build-essential
}

################################################################################

function OctoPrintInstance_createUser() {
	local INSTANCE_NAME="${1}"
	local USER=$(OctoPrintInstance_exists ${INSTANCE_NAME})
	if [ -n "${USER}" ]; then
		echo "The User ${INSTANCE_NAME} already exists !!!"
		exit 1
	fi
	if [ -d "/home/${INSTANCE_NAME}" ]; then
		echo "The User '${INSTANCE_NAME}' already exist, or at least his Homefolder '/home/${INSTANCE_NAME}' !!!"
		exit 1
	fi
	echo "Creating new User ${INSTANCE_NAME} ..."
	adduser --disabled-password --disabled-login --quiet --gecos ${INSTANCE_NAME} ${INSTANCE_NAME}
	usermod -a -G tty ${INSTANCE_NAME}
	usermod -a -G dialout ${INSTANCE_NAME}
}

function OctoPrintInstance_deleteUser() {
	local INSTANCE_NAME="${1}"
	local USER=$(OctoPrintInstance_exists ${INSTANCE_NAME})
	if [ -z "${USER}" ]; then
		echo "The User ${INSTANCE_NAME} seems not to exists !!!"
		exit 1
	fi
	killall --user ${INSTANCE_NAME}
	userdel ${INSTANCE_NAME}
	rm -Rf /home/${INSTANCE_NAME}
}

################################################################################

function OctoPrintInstance_installOctoprint() {
	local INSTANCE_NAME="${1}"
	echo "Create Virtual Environment and install Octoprint for ${INSTANCE_NAME} ..."
	sudo -u ${INSTANCE_NAME} sh -c 'cd /home/'${INSTANCE_NAME}' && mkdir OctoPrint && cd OctoPrint && \
virtualenv venv && \
. venv/bin/activate && \
pip install pip --upgrade && \
pip install https://github.com/foosel/OctoPrint/archive/1.4.2.zip'
}

function OctoPrintInstance_configureOctoprint() {
	local INSTANCE_NAME="${1}"
	local INSTANCE_API_SYSTEM=$(date | md5sum | awk -F" " '{print toupper($1)}')
	local INSTANCE_API_ADMIN=$(date | md5sum | awk -F" " '{print toupper($1)}')
	local INSTANCE_SALT="QmcSp5B7fubFuyTFkBMIbIs8fkahkbRf"
	local INSTANCE_PASS="e90d9e087935fb5b0d5b0b3f66a44b0459fefe41b52e9a79c397c2ec1cffc7162a51de796ee85839990ed91e4358c358bf664e796aa9ebe878329a4f1e5022fe"
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
  name: OctoPrint Instance ${INSTANCE_NAME}
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
}

function OctoPrintInstance_removeOctoprint() {
	local INSTANCE_NAME="${1}"
	rm -Rf /home/${INSTANCE_NAME}/.octoprint
	rm -Rf /home/${INSTANCE_NAME}/OctoPrint
}

function OctoPrintInstance_addPluginOctoprint() {
	local INSTANCE_NAME="${1}"
	local PLUGIN_URL="${2}"
	[ -x "/home/${INSTANCE_NAME}/OctoPrint/venv/bin/pip" ] && /home/${INSTANCE_NAME}/OctoPrint/venv/bin/pip install ${PLUGIN_URL}
	#service ${INSTANCE_NAME} restart
	#/etc/init.d/${INSTANCE_NAME} restart
}

function OctoPrintInstance_addPluginsOctoprint() {
	local INSTANCE_NAME="${1}"
	local PLUGINS="https://github.com/jneilliii/OctoPrint-CustomBackground/archive/0.10.1.zip
https://github.com/amsbr/OctoPrint-EEPROM-Marlin/archive/1.2.1.zip
https://github.com/jslay88/OctoPrint-Dropbox-Timelapse/archive/0.1.4.zip
https://github.com/OctoPrint/OctoPrint-FirmwareUpdater/archive/1.7.0.zip
https://github.com/jneilliii/OctoPrint-M117PopUp/archive/0.6.2.zip
https://github.com/OctoPrint/OctoPrint-MQTT/archive/0.8.7.zip
https://github.com/imrahil/OctoPrint-PrintHistory/archive/1.2.zip
https://github.com/amsbr/OctoPrint-Stats/archive/2.0.2.zip
https://github.com/OctoPrint/OctoPrint-Pushbullet/archive/0.1.10.zip
https://github.com/Birkbjo/OctoPrint-Themeify/archive/1.2.2.zip
https://github.com/OctoPrint/OctoPrint-CommandSplitter/archive/0.2.3.zip"
	for PLUGIN in ${PLUGINS}
	do
		OctoPrintInstance_addPluginOctoprint ${INSTANCE_NAME} ${PLUGIN}
	done
	chown --recursive ${INSTANCE_NAME} /home/${INSTANCE_NAME}/OctoPrint/
	#service ${INSTANCE_NAME} restart
	/etc/init.d/${INSTANCE_NAME} restart
}

################################################################################

function OctoPrintInstance_createService() {
	local INSTANCE_NAME="${1}"
	echo "Creating Octoprint Service for ${INSTANCE_NAME} ..."
	wget --no-check-certificate -O /tmp/octoprintinstance.init https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.init
	wget --no-check-certificate -O /tmp/octoprintinstance.default https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.default
	cat /tmp/octoprintinstance.init | sed 's/@@@OP_NAME@@@/'${INSTANCE_NAME}'/g' > /tmp/${INSTANCE_NAME}.init
	cat /tmp/octoprintinstance.default | sed 's/@@@OP_NAME@@@/'${INSTANCE_NAME}'/g' > /tmp/${INSTANCE_NAME}.default
	mv -f /tmp/${INSTANCE_NAME}.init /etc/init.d/${INSTANCE_NAME}
	mv -f /tmp/${INSTANCE_NAME}.default /etc/default/${INSTANCE_NAME}
	chmod +x /etc/init.d/${INSTANCE_NAME}
}

function OctoPrintInstance_enableService() {
	local INSTANCE_NAME="${1}"
	echo "Enabling Octoprint Service for ${INSTANCE_NAME} ..."
	[ -x "/etc/init.d/${INSTANCE_NAME}" ] && update-rc.d ${INSTANCE_NAME} defaults
}

function OctoPrintInstance_startService() {
	local INSTANCE_NAME="${1}"
	echo "Starting Octoprint Service for ${INSTANCE_NAME} ..."
	#service ${INSTANCE_NAME} start
	[ -x "/etc/init.d/${INSTANCE_NAME}" ] && /etc/init.d/${INSTANCE_NAME} start
}

function OctoPrintInstance_runningService() {
	local INSTANCE_NAME="${1}"
	local SERVICE=$(service --status-all | grep "${INSTANCE_NAME}" | awk '{print $2}')
}

function OctoPrintInstance_stopService() {
	local INSTANCE_NAME="${1}"
	echo "Stopping Octoprint Service for ${INSTANCE_NAME} ..."
	#service ${INSTANCE_NAME} stop
	[ -x "/etc/init.d/${INSTANCE_NAME}" ] && /etc/init.d/${INSTANCE_NAME} stop
}

function OctoPrintInstance_disableService() {
	local INSTANCE_NAME="${1}"
	echo "Disabling Octoprint Service for ${INSTANCE_NAME} ..."
	[ -x "/etc/init.d/${INSTANCE_NAME}" ] && update-rc.d ${INSTANCE_NAME} remove
}

function OctoPrintInstance_removeService() {
	local INSTANCE_NAME="${1}"
	rm -f /etc/init.d/${INSTANCE_NAME}
	rm -f /etc/default/${INSTANCE_NAME}
}

################################################################################

function OctoPrintInstance_exists() {
	local INSTANCE_NAME="${1}"
	local USERS=$(sed 's/:.*//' /etc/passwd | grep ${INSTANCE_NAME})
	echo "${USERS}"
}

function OctoPrintInstance_list() {
	local INSTANCE_PREFIX="op_"
	local USERS=$(sed 's/:.*//' /etc/passwd | grep ${INSTANCE_PREFIX})
	echo "${USERS}"
}

function OctoPrintInstance_delete() {
	local INSTANCE_NAME="${1}"
	OctoPrintInstance_stopService ${INSTANCE_NAME}
	OctoPrintInstance_disableService ${INSTANCE_NAME}
	OctoPrintInstance_removeService ${INSTANCE_NAME}
	OctoPrintInstance_removeOctoprint ${INSTANCE_NAME}
	OctoPrintInstance_deleteUser ${INSTANCE_NAME}
}

function OctoPrintInstance_create() {
	local INSTANCE_NAME="${1}"
	echo "Creating new OctoPrint Instance with User ${INSTANCE_NAME} ..."
	OctoPrintInstance_createUser ${INSTANCE_NAME}
	OctoPrintInstance_installOctoprint ${INSTANCE_NAME}
	OctoPrintInstance_configureOctoprint ${INSTANCE_NAME}
	OctoPrintInstance_createService ${INSTANCE_NAME}
	OctoPrintInstance_enableService ${INSTANCE_NAME}
	OctoPrintInstance_startService ${INSTANCE_NAME}
}

################################################################################

#set -x
#set -e

MODE="none"
while getopts "le:d:c:p:s:n:" option; do
	case "${option}" in
		l) MODE="list"; INSTANCE_NUM=0;;
		e) MODE="exists"; INSTANCE_NUM=${OPTARG};;
		d) MODE="delete"; INSTANCE_NUM=${OPTARG};;
		c) MODE="create"; INSTANCE_NUM=${OPTARG};;
		p) MODE="plugins"; INSTANCE_NUM=${OPTARG};;
		s) MODE="service"${OPTARG}; INSTANCE_NUM=0;;
		n) INSTANCE_NUM=${OPTARG};;
	esac
done

if [ -z ${INSTANCE_NUM} ]; then
	echo "Argument 1 has to be a unique User Identifier, like '001' !!!"
	exit 1
fi

INSTANCE_NAME="op_"${INSTANCE_NUM}

#OctoPrintInstance_installDeps

case "${MODE}" in
	"list") OctoPrintInstance_list; exit 0;;
	"exists") OctoPrintInstance_exists ${INSTANCE_NAME}; exit 0;;
	"delete") OctoPrintInstance_delete ${INSTANCE_NAME}; exit 0;;
	"create") OctoPrintInstance_create ${INSTANCE_NAME}; exit 0;;
	"plugins") OctoPrintInstance_addPluginsOctoprint ${INSTANCE_NAME}; exit 0;;
	"servicestart") OctoPrintInstance_startService ${INSTANCE_NAME}; exit 0;;
	"servicestop") OctoPrintInstance_stopService ${INSTANCE_NAME}; exit 0;;
	"servicestatus") OctoPrintInstance_runningService ${INSTANCE_NAME}; exit 0;;
	"servicerestart") OctoPrintInstance_stopService ${INSTANCE_NAME}; OctoPrintInstance_startService ${INSTANCE_NAME}; exit 0;;
	"none") echo "Mode is ${MODE} !!!"; exit 1;;
esac

exit 1

################################################################################

