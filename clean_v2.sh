#!/bin/sh

help () {
    echo -e 'Please fill all fields.\nAborting ...';
}

if [ $# -lt "1" ]
then
    help
    exit 1
fi

ENV_NAME=$1

if ! [ `dos2 list | grep -o "^${ENV_NAME}$"` ]
then
    echo -e "Env with $ENV_NAME name doesn not exist.\nAborting ..."
    exit 1
fi

dos2 destroy ${ENV_NAME}
dos2 erase ${ENV_NAME}
