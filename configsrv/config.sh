#!/bin/bash

echo "Generating configsrv config"
echo ""

rm /init-configserver.js
cat <<EOT >> /init-configserver.js
rs.initiate(
   {
EOT

echo "_id: \"$CONFIG_SERVER_NAME\"," >> /init-configserver.js

cat <<EOT >> /init-configserver.js
      configsvr: true,
      version: 1,
      members: [
EOT

IFS=',' read -r -a NODES <<< "$CONFIG_SERVER_NODES"
S=""
c=0
for N in "${NODES[@]}"; do
    echo "${S}{ _id: $c, host : \"$N:27017\" }" >> /init-configserver.js
    S=","
    c=$((c+1))
done

cat <<EOT >> /init-configserver.js
      ]
   }
)
EOT

echo "/init-configserver.js"
cat /init-configserver.js

echo "Waiting for local server to be available at 27017..."
while ! nc -z 127.0.0.1 27017; do sleep 0.5; echo "."; done
sleep 3

echo ">>> CONFIGURING CLUSTER CONFIG SERVER..."
mongo < /init-configserver.js
echo "CONFIGURATION OK"

