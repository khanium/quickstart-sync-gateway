# Quickstart for Sync Gateway Developer Kit (Docker Compose Quickstart)
 Developer quick start kit for deploying in Docker Compose Sync Gateway +3.1.3 Couchbase +7.2.3 using Scope &amp; Collections

# Pre-requisites

* Docker Compose 

# Getting Starting (First Time you run it)

0. Build SGW docker image

```
docker compose build
```

![build](/docs/assets/00_build.png)

1. Setup Docker Compose Couchbase Server & Sync Gateway Instances

```
docker-compose up
```

![up](/docs/assets/01_composeUp.png)


2. Wait Until Buckets & Sync Gateway are ready 


![Sync Gateway listening in 4984](/docs/assets/02_containers_ready.png)


Wait until your Sync Gateway is available in the following link http://localhost:4984 


![Sync Gateway listening in 4984](docs/assets/02_sgw_ready.png)


Verify the Couchbase Server Admin Console with username: `Administrator` and password `password` on http://localhost:8091

![Couchbase Console UI](/docs/assets/02_server.png)


Check the Couchbase Server demo bucket and custom scope with the three collections: `typeA`, `typeB` & `typeC`.

![collections](/docs/assets/02_collections.png)

Check the Couchbase Server User `sync_gateway` with mobile sync gateway role on demo bucket. 


![security](/docs/assets/02_security.png)


Note: This Sync Gateway configuration does not include TLS connections. 


3. Configure Sync Gateway Database

From your host CMD/terminal configure the first time the database using one Scope and define their collection's sync functions: 

```
curl -X PUT "http://localhost:4985/db/" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"name\": \"db\", \"bucket\": \"demo\", \"scopes\": { \"custom\": { \"collections\": { \"typeA\": { \"sync\": \"function(doc, oldDoc, meta) { if(doc.channels) { channel(doc.channels); }else{ throw({forbidden: \\\"document'\\\"+doc._id+\\\"'doesn't contain channels field to sync\\\"}); } }\" }, \"typeB\": { \"sync\": \"function(doc, oldDoc, meta) { if(doc.channels) { channel(doc.channels); }else{ throw({forbidden: \\\"document'\\\"+doc._id+\\\"'doesn't contain channels field to sync\\\"}); } }\" } } } }, \"revs_limit\": 20, \"allow_conflicts\": false, \"num_index_replicas\": 0}"
```

In this example, we have setup a `custom` scope and collections `typeA` and `typeB`. Note: collection `typeC` is not synced with this Sync Gateway database. 

Note: This database configuration has defined `num_index_replicas: 0`. Please change this parameter to the default value 1 when your Couchbase Server cluster contains at least 2 indexes service nodes. 


4. Configure Sync Gateway Users

Let's configure now a Sync Gateway user `userdb1` with password `password` and access to the documents with channel `blue` in collections `typeA` or `typeB`. 

```
curl -u sync_gateway:password -X POST "http://localhost:4985/db/_user/" -H "accept: */*" -H "Content-Type: application/json" -d "{\"name\":\"userdb1\",\"password\":\"password\",\"collection_access\":{\"custom\":{\"typeA\":{\"admin_channels\":[\"blue\"]},\"typeB\":{\"admin_channels\":[\"blue\"]}}},\"email\":\"userdb1@company.com\"}"
```


5. Run your own Couchbase Mobile App

```
replication sgw url: ws://127.0.0.1:4984/db
replication scope: custom
replication collections: typeA,typeB
authenticator: 
	username: userdb1
    password: password 
```


# Start / Stop Docker Compose


1. Start docker compose

```
docker-compose up
```

2. Stop docker compose

`ctrl-c` & then 

```
docker-compose down
```

3. Clean up logs & data from Couchbase Server mapped into localhost volume

```
./cleanup-data.sh
```