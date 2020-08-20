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

* Although this example starts with two-replica shards, it is recommended to use three replicas minimum to ensure automatic failover in case one of the nodes comes down. See more at https://docs.mongodb.com/manual/core/replica-set-architecture-three-members/

* Create docker-compose.yml

```yml
version: '3.5'

services:

  mongo-express:
    image: mongo-express:0.54.0
    ports:
      - 8081:8081
    environment:
      - ME_CONFIG_MONGODB_SERVER=router
    #   - ME_CONFIG_BASICAUTH_USERNAME=
    #   - ME_CONFIG_BASICAUTH_PASSWORD=
    restart: always

  router:
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
docker-compose exec router mongo --port 27017
sh.status()
```

* Enable sharding of a collection in a database

```sh
docker-compose exec router mongo --port 27017
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

### Volumes

* mongo-cluster-configsrv volume is at "/data"

  * Mount volumes as "myvolume:/data"

* mongo-cluster-shard volume is at "/data"

  * Mount volumes as "myvolume:/data"

* The original mongo image has volumes at /data/db and /data/configdb but they are not used by this image because those paths are used differently depending if it is a shard or configsrv instance, so we simplyfied to be just "/data" on both type of instances to avoid catastrofic errors (once I mapped just /data and Swarm created individual instance volume for /data/db and I lost my data - lucky it was a test cluster!). Swarm will still create those volumes per instance (because they are declared at parent Dockerfile) but you can ignore them.

### Add a new shard

* Add the new services to docker-compose.yml

```yml
...
  router:
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

* Add shards to cluster

```sh
docker-compose up router
```

* Some data from shard1 and shard2 will be migrated to shard3 now. This may take a while.
* Check if all is OK with "rs.status()" on router

### (Swarm) Move a replica node from one Swarm Node VM to another when storage is fixed in VM

* This is the case when you mount the Block Storage directly to the VM you run the node by using a "placement" to force that container to run only on that host and want to move it to another node (probably to expand the cluster size). If using NFS or another distributed volume manager, you don't need to worry about this.

* Deactivate mongo nodes: `docker service scale mongo_shard1c=0`

* Remove Block Storage from current VM and mount it to the new VM
  * If using local storage, just copy the volume contents to the new VM using SCP
  * Verify the commands you are meant to perform on the VM according to your cloud provider in order to mount the volume in filesystem

* Change the container placement in docker-compose.yml to point to the new host. Ex:

```yml
  shard1c:
    image: stutzlab/mongo-cluster-shard:4.4.0.8
    environment:
      - SHARD_REPLICA_SET=shard1
    deploy:
      placement:
        constraints: [node.hostname == server13]
    networks:
      - mongo
    volumes:
      - /mnt/mongo1_shard1c:/data
```

* Update service definitions
  * `docker stack deploy --compose-file docker-compose.yml mongo`

* Check if scale for moved services is '1'

* Check if node went online successfuly
  * Enter newly instantiated container and execute:

```sh
mongo
rs.status()
```

* Verify if current node is OK

### Add a new shard to the cluster

* Create the new shard replicas services in docker-compose.yml

```yml
...
  shard3a:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_REPLICA_SET=shard3
      - INIT_SHARD_NODES=shard3a,shard3b
    volumes:
      - shard3a:/data

  shard3b:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_REPLICA_SET=shard3
    volumes:
      - shard3b:/data
...
```

* Create new volumes and mount to the host that will execute the shard (if using Swarm, don't forget to add a placement constraint if needed)

* Change router service and add the new SHARD config environment variables

```yml
  router:
    image: stutzlab/mongo-cluster-router:4.4.0.8
    environment:
      - CONFIG_REPLICA_SET=configsrv
      - CONFIG_SERVER_NODES=configsrv1,configsrv2,configsrv3
      - ADD_SHARD_REPLICA_SET_PREFIX=shard
      - ADD_SHARD_1_NODES=shard1a,shard1b,shard1c
      - ADD_SHARD_2_NODES=shard2a,shard2b,shard2c
      - ADD_SHARD_3_NODES=shard3a,shard3b
```

* Instantiate new replica nodes and add shard to cluster

```sh
docker-compose up

#check replicaset status
docker-compose exec shard3a mongo --eval "rs.status()"

#check shard status
docker-compose exec router mongo --eval "sh.status()"
```

* This should end adding the new shard and replicas automatically

* (OPTIONAL) If you want to perform the above operations step by step do

```sh
#create replicaset instances for shard3
docker-compose up shard3a shard3b
#check new replicaset status
docker-compose exec shard3a mongo --eval "rs.status()"
#change router to add the new shard to configsrv
docker-compose up router
#check if new shard was added successfuly
docker-compose exec router mongo --eval "sh.status()"
```

### Add a new node to an existing shard (add a new replica to a replicaset)

* Add the new service do docker-compose.yml

```yml
...
  shard1c:
    image: stutzlab/mongo-cluster-shard
    environment:
      - SHARD_REPLICA_SET=shard1
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

* When a shard has only two replicas and one goes down, no primary will be elected and the database will be freezed until you take action to force the usage of its state in despite of the other copy (no consensus takes place and you may lose data if the remaining node was behind the node that went down).

* Create a new shard replica node service in docker-compose, and "up" it

* Enter the mongo cli in the last shard node (probably not the primary one) and then reconfigure the entire replica set with the nodes you want to be present now, adding the new shard node and use "force:true".

```yml
docker-compose exec shard1d mongo --eval "rs.reconfig( { \"_id\": \"shard1\", members: [ { \"_id\": 0, host: \"shard1a\" }, { \"_id\": 4, host: \"shard1d\"} ]}, {force:true} )"
```

## Application notes

* Pay attention to the level of isolation during Write and Read operations so that you achieve the most optimal performance vs data integrity for your application. Take a look at
  * https://docs.mongodb.com/manual/reference/read-concern/
  * https://docs.mongodb.com/manual/reference/write-concern/

* Knowledge about the [CAP Theorem](https://en.wikipedia.org/wiki/CAP_theorem) is useful to help you decide on this.

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

## Crisis experiences

### Nodes got exhausted in resources and cluster won't come back by itself

* We had a situation where all resources exausted and containers got restarting by OOM

* Some locks on volume where kept so that some containers wouldn't start OK because of locks (this is a expected behavior)

* Docker daemon was strange (Swarm was not keeping the number of service instances), so we restarted the VMs

* scale=0 the services that are not restarting

* delete `/mongod.lock` from each mongo cluster volume

* scale=1 the services again

* Another option is to stop all docker services and restart again (not needed but we solved this way because things were too ugly and it worked!)
  * `docker stack rm mongo` - be SURE all volumes are mounted OUTSIDE instances
  * remove locks
  * reboot VMs
  * `docker stack deploy --compose-file docker-compose-mongo.yml mongo`
  * this is the same procedure as restoring a backup (!)

## More resources

* https://github.com/minhhungit/mongodb-cluster-docker-compose

* https://medium.com/@gustavo.leitao/criando-um-cluster-mongodb-com-replicaset-e-sharding-com-docker-9cb19d456b56

