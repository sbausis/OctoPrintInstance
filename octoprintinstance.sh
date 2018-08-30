
################################################################################
#wget -O /tmp/octoprintinstance.sh https://github.com/sbausis/OctoPrintInstance/raw/master/octoprintinstance.sh && bash /tmp/octoprintinstance.sh 003

if [ -z "$1" ]; then
	INSTANCE_NUM="$1"
fi

INSTANCE_NAME="op_"${INSTANCE_NUM}

################################################################################

adduser ${INSTANCE_NAME}
usermod -a -G tty ${INSTANCE_NAME}
usermod -a -G dialout ${INSTANCE_NAME}

################################################################################

login ${INSTANCE_NAME}
cd ~
sudo apt update
sudo apt install python-pip python-dev python-setuptools python-virtualenv git libyaml-dev build-essential
mkdir OctoPrint && cd OctoPrint
virtualenv venv
source venv/bin/activate
pip install pip --upgrade
pip install https://get.octoprint.org/latest

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
