# mongodb-cluster

This is a set of Mongo containers for creating clusters using Docker

Check specific images used in this example at

* http://github.com/stutzlab/mongo-cluster-router
* http://github.com/stutzlab/mongo-cluster-configsrv
* http://github.com/stutzlab/mongo-cluster-shard

For a more complete example, check [docker-compose.yml](docker-compose.yml)

## Usage

### Initial cluster creation

* In this example we will create a cluster with:
  * 2 routers
  * 3 config servers
  * 2 shards, each with 2 replicas

* We had some issues running the shards in Docker for Mac. Some shards would be freezed and Docker had to be restarted. Use a VirtualBox VM if needed.

* Create docker-compose.yml

```yml
version: '3.5'

services:

  mongo-express:
    image: mongo-express:0.54.0
    ports:
      - 8081:8081
    environment:
      - ME_CONFIG_MONGODB_SERVER=router1
    #   - ME_CONFIG_BASICAUTH_USERNAME=
    #   - ME_CONFIG_BASICAUTH_PASSWORD=
    restart: always

  router1:
    image: stutzlab/mongo-cluster-router
    environment:
      - CONFIG_REPLICA_SET=configsrv
      - CONFIG_SERVER_NODES=configsrv1
      - ADD_SHARD_NAME_PREFIX=shard
      - ADD_SHARD_1_NODES=shard1a
      - ADD_SHARD_2_NODES=shard2a


  configsrv1:
    image: stutzlab/mongo-cluster-configsrv
    environment:
      - CONFIG_REPLICA_SET=configsrv
      - INIT_CONFIG_NODES=configsrv1

  shard1a:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_REPLICA_SET=shard1
      - INIT_SHARD_NODES=shard1a

  shard2a:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_REPLICA_SET=shard2
      - INIT_SHARD_NODES=shard2a
```

```sh
docker-compose up
```

* This may take a while. Check when logs stop going crazy!

* Connect to mongo-express and see some internal collections
  * open browser at http://localhost:8081

* Show cluster status

```sh
docker-compose exec router1 mongo --port 27017
sh.status()
```

* Enable sharding of a collection in a database

```sh
docker-compose exec router1 mongo --port 27017
>
```

```js
//create database 'sampledb'
use sampledb

//enable sharding for database
sh.enableSharding("sampledb")

//enable sharding for collection 'sample-collection'
db.adminCommand( { shardCollection: "sampledb.collection1", key: { mykey: "hashed" } } )
db.adminCommand( { shardCollection: "sampledb.collection2", key: { _id: "hashed" } } )

//add some data
for(i=0;i<1000;i++) {
  db.collection2.insert({"name": _rand(), "nbr": i})
}

//show details about qtty of records per shard
db.collection2.find().explain(true)

//inspect shard status
sh.status()

```

* Explore shard structure

```sh
docker-compose exec shard1a mongo --port 27017
>
```

```js
//verify shard replication nodes/configuration
rs.conf()
```

### Add a new shard

* Add the new services do docker-compose.yml

```yml
...
  router1:
    image: stutzlab/mongo-cluster-router
    environment:
      - CONFIG_SERVER_NAME=configsrv
      - CONFIG_SERVER_NODES=configsrv1
      - ADD_SHARD_NAME_PREFIX=shard
      - ADD_SHARD_1_NODES=shard1a
      - ADD_SHARD_2_NODES=shard2a
      - ADD_SHARD_3_NODES=shard3a,shard3b

  shard3a:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_NAME=shard3
      - INIT_SHARD_NODES=shard3a,shard3b
      
  shard3b:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_NAME=shard3
...
```

* Start new shard

```sh
docker-compose up shard3a shard3b
```

* Add new shard to cluster

```sh
docker-compose up router1
```

  * Some data from shard1 and shard2 will be migrated to shard3 now. This may take a while.
  * Check if all is OK with "rs.status()" on router

### Add a new node to an existing shard

* Add the new service do docker-compose.yml

```yml
...
  shard1c:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_NAME=shard1
    volumes:
      - shard1c:/data
...

```sh
docker-compose up shard1c
```

* Add the new node to an existing shard (new replica node)

  * Discover which node is currently the master by

```sh
docker-compose exec shard1a mongo --eval "rs.isMaster()"
#look in response for "ismaster: true"
docker-compose exec shard1b mongo --eval "rs.isMaster()"
#look in response for "ismaster: true"
```

  * Execute the "add" command on the master node. If shard1b is the master:

```sh
docker-compose exec shard1b mongo --eval "rs.add( { host: \"shard1c\", priority: 0, votes: 0 } )"
```

### Recover shard with only one replica

* When a shard has only one replica, no primary will be elected and the database will be freezed

* Create a new shard node service in docker-compose, and "up" it

* Enter the mongo cli in the last shard node (probably not the primary one) and then reconfigure the entire replica set of the shard, adding the new shard node and use "force:true"

```yml
docker-compose exec shard1d mongo --eval "rs.reconfig( { \"_id\": \"shard1\", members: [ { \"_id\": 6, host: \"shard1e\" }, { \"_id\": 3, host: \"shard1d\"} ]}, {force:true} )"
```

## Monitoring commands

* Login in container shell
* Execute

```sh
mongo

db.printCollectionStats()
db.printReplicationInfo()
db.printShardingStatus()
db.printSlaveReplicationInfo()
```

## Free monitoring

Enter console on primary container of

* configsrv
* shard1
* shard2
  
On each node, configure free monitoring

```sh
mongo
> db.enableFreeMonitoring()

Get provided URL in log and load in browser
```

## More resources

* https://github.com/minhhungit/mongodb-cluster-docker-compose

* https://medium.com/@gustavo.leitao/criando-um-cluster-mongodb-com-replicaset-e-sharding-com-docker-9cb19d456b56

