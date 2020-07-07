#!/bin/bash

echo "Generating shard config"
echo ""

rm /init-shard.js
cat <<EOT >> /init-shard.js
rs.initiate(
   {
EOT

echo "_id: \"$SHARD_NAME\"," >> /init-shard.js

cat <<EOT >> /init-shard.js
      version: 1,
      members: [
EOT

IFS=',' read -r -a NODES <<< "$SHARD_NODES"
S=""
c=0
for N in "${NODES[@]}"; do
   echo "${S}{ _id: $c, host : \"$N:27017\"}" >> /init-shard.js
   S=","
   c=$((c+1))
done

cat <<EOT >> /init-shard.js
      ]
   }
)
EOT

echo "/init-shard.js"
cat /init-shard.js

echo "Waiting for local server to be available at 27017..."
while ! echo exit | nc 127.0.0.1 27017; do sleep 0.5; done
sleep 3

echo "Configuring shard..."
mongo < /init-shard.js

