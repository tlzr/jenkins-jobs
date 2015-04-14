#!/bin/sh

help () {
    echo -e 'Please fill all required fields.\nAborting ...';
}

if [ $# -lt "4" ]
then
    help
    exit 1
fi

VENV_PATH="/opt/stuff/fuel-devops-env-v2"
FUEL_MAIN_PATH="/opt/stuff/fuel-qa"
ISO_DIRECTORY="/opt/other/iso"
AVAILABLE_SIZE=`df /dev/mapper/openstack-ins | tail -1 | awk '{ print $4; }'`
AVAILABLE_INODES=`df -i /dev/mapper/openstack-ins | tail -1 | awk '{ print $4; }'`
ENV_NAME=$1
export NODES_COUNT=$2
ISO_NAME=$3
ISO_PATH="${ISO_DIRECTORY}/${ISO_NAME}"
ISO_URL=$4
export SLAVE_NODE_MEMORY=3072
export POOL_DEFAULT='10.177.0.0/16:24'
status_code=`curl -s --head -w %{http_code} $ISO_URL -o /dev/null`

if [ $status_code -ne 200 ]
then
    echo "Returned HTTP Code: $status_code Aborting ..."
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

if ! [ -f $ISO_PATH ]
then
    echo -e "ISO file does not exist or is not accessible.\nAborting ..."
    echo "Trying to download $ISO_NAME"
    #aria2c -d $ISO_DIRECTORY --force-save=true --allow-piece-length-change=true --allow-overwrite=true --auto-file-renaming=false --max-overall-download-limit=9000K --seed-time=0 --summary-interval=1200 $ISO_URL
    aria2c -d $ISO_DIRECTORY --force-save=true --allow-piece-length-change=true --allow-overwrite=true --auto-file-renaming=false --seed-time=0 --summary-interval=1200 $ISO_URL
fi

if [ `dos2 list | grep -o "^${ENV_NAME}$"` ]
then
    echo -e "Env with $ENV_NAME already exists.\nAborting ..."
    exit 1
fi

cd $FUEL_MAIN_PATH
./utils/jenkins/system_tests.sh -t test -w $(pwd) -j fuelweb_test -e $ENV_NAME -i $ISO_PATH -o --group=setup -V $VENV_PATH

dos2 start ${ENV_NAME}
dos2 net-list ${ENV_NAME}
ADMIN_NODE_IP=`virsh net-dumpxml ${ENV_NAME}_admin | grep -P "(\d+\.){3}" -o | awk '{print $0"2"}'`
echo "Admin node IP: ${ADMIN_NODE_IP}"
sleep 120

if ! [ `nc -w 2 $ADMIN_NODE_IP 22` ]
then
    echo -e "Could not connect to SSH server at ${ADMIN_NODE_IP}\nAborting ..."
    dos2 destroy ${ENV_NAME}
    exit 1
fi
