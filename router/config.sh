#!/bin/bash

echo "Generating router config"
echo ""
rm /init-router.js
for i in {1..100}; do 
    SHARD_NAME="${SHARD_NAME_PREFIX}$i"
    var="SHARD_${i}_NODES"
    SNODES="${!var}"

    if [ "$SNODES" == "" ]; then
        continue
    fi
    IFS=',' read -r -a NODES <<< "$SNODES"
    S=""
    echo "Shard ${SHARD_NAME} nodes:"
    for N in "${NODES[@]}"; do
        echo "    - $N"
        echo "sh.addShard(\"$SHARD_NAME/$N:27017\")" >> /init-router.js
        CONFIGDB="${CONFIGDB}${S}$N:27017"
        S=","
    done
done
echo ""

echo "/init-router.js"
cat /init-router.js

echo "Waiting for local server to be available at 27017..."
while ! echo exit | nc 127.0.0.1 27017; do sleep 0.5; done
sleep 3

echo "Configuring router..."
mongo < /init-router.js

