#!/bin/sh

help () {
    echo -e 'Please fill all required fields.\nAborting ...';
}

if [ $# -lt "3" ]
then
    help
    exit 1
fi

VENV_PATH="/opt/stuff/fuel-devops-env"
ISO_DIRECTORY="/opt/other/iso"
AVAILABLE_SIZE=`df /dev/mapper/openstack-ins | tail -1 | awk '{ print $4; }'`
AVAILABLE_INODES=`df -i /dev/mapper/openstack-ins | tail -1 | awk '{ print $4; }'`
ENV_NAME=$1
export NODES_COUNT=$2
ISO_NAME=$3
ISO_PATH="${ISO_DIRECTORY}/${ISO_NAME}"
export SLAVE_NODE_MEMORY=3072
export POOL_DEFAULT='10.122.0.0/16:24'

if ! [ -f $ISO_PATH ]
then
    echo -e "ISO file does not exist or is not accessible.\nAborting ..."
    exit 1
fi

if [ "$AVAILABLE_SIZE" -lt "90000000" ]
then
    echo -e "Low space: $AVAILABLE_SIZE kb\nAborting ..."
    exit 1
fi

if [ "$AVAILABLE_INODES" -lt "1000" ]
then
    echo -e "Low value: $AVAILABLE_SIZE n\nAborting ..."
    exit 1
fi

if [ `dos list | grep -o "^${ENV_NAME}$"` ]
then
    echo -e "Env with $ENV_NAME already exists.\nAborting ..."
    exit 1
fi

cd /opt/stuff/fuel-main/
./utils/jenkins/system_tests.sh -t test -w $(pwd) -j fuelweb_test -e $ENV_NAME -i $ISO_PATH -o --group=setup -V $VENV_PATH

dos start ${ENV_NAME}
dos net-list ${ENV_NAME}
ADMIN_NODE_IP=`virsh net-dumpxml ${ENV_NAME}_admin | grep -P "(\d+\.){3}" -o | awk '{print $0"2"}'`
echo "Admin node IP: ${ADMIN_NODE_IP}"
sleep 120

if ! [ `nc -w 2 $ADMIN_NODE_IP 22` ]
then
    echo -e "Could not connect to SSH server at ${ADMIN_NODE_IP}\nAborting ..."
    dos2 destroy ${ENV_NAME}
    exit 1
fi
