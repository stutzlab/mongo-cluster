#!/bin/bash

set -e
# set -x

/config.sh &

echo "Starting Mongo configsrv..."
mongod --port 27017 --configsvr --replSet $CONFIG_SERVER_NAME --bind_ip_all
