#!/bin/bash

set -e
# set -x

/config.sh &

IFS=',' read -r -a NODES <<< "$CONFIG_SERVER_NODES"
S=""
CONFIGDB=""
for N in "${NODES[@]}"; do
    echo "Config node $N"
    CONFIGDB="${CONFIGDB}${S}$N:27017"
    S=","
done

echo "Starting Mongo router..."
mongos --port 27017 --configdb $CONFIG_SERVER_NAME/$CONFIGDB --bind_ip_all

