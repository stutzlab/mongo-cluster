#!/bin/bash

set -e
# set -x

/config.sh &

echo "Starting Mongo shard node..."
mongod --port 27017 --shardsvr --replSet $SHARD_NAME --bind_ip_all
