#!/bin/bash
# used to start couchbase server - can't get around this as docker compose only allows you to start one command - so we have to start couchbase like the standard couchbase Dockerfile would 
# https://github.com/couchbase/docker/blob/master/enterprise/couchbase-server/7.2.0/Dockerfile#L88

/entrypoint.sh couchbase-server & 



CB_HOST="127.0.0.1"
CB_USER=${COUCHBASE_ADMINISTRATOR_USERNAME:-"Administrator"}
CB_PASS=${COUCHBASE_ADMINISTRATOR_PASSWORD:-"password"}
CB_SERVICES_CONFIG=${CB_SERVICES:-"data,query,index"}
JSON_FILE="/opt/couchbase/init/buckets.json"
USERS_FILE="/opt/couchbase/init/rbac-users.json"

# track if setup is complete so we don't try to setup again
FILE=/opt/couchbase/init/setupComplete.txt

if ! [ -f "$FILE" ]; then
  # used to automatically create the cluster based on environment variables
  # https://docs.couchbase.com/server/current/cli/cbcli/couchbase-cli-cluster-init.html

  echo $CB_USER ":"  $CB_PASS  

  sleep 10s 
  /opt/couchbase/bin/couchbase-cli cluster-init -c $CB_HOST \
  --cluster-name $CLUSTER_NAME \
  --cluster-username $CB_USER \
  --cluster-password $CB_PASS \
  --services $CB_SERVICES_CONFIG \
  --cluster-ramsize $COUCHBASE_RAM_SIZE \
  --cluster-index-ramsize $COUCHBASE_INDEX_RAM_SIZE 
  # \
  # --index-storage-setting default

  sleep 2s 

  # used to auto create the bucket based on environment variables
  # https://docs.couchbase.com/server/current/cli/cbcli/couchbase-cli-bucket-create.html

#  /opt/couchbase/bin/couchbase-cli bucket-create -c localhost:8091 \
#  --username $COUCHBASE_ADMINISTRATOR_USERNAME \
#  --password $COUCHBASE_ADMINISTRATOR_PASSWORD \
#  --bucket $COUCHBASE_BUCKET \
#  --bucket-ramsize $COUCHBASE_BUCKET_RAMSIZE \
#  --bucket-type couchbase 


# Initialize the cluster
#echo "Initializing Couchbase cluster..."
#couchbase-cli cluster-init -c $CB_HOST --cluster-username=$CB_USER --cluster-password=$CB_PASS \
#  --cluster-name "$CLUSTER_NAME" --cluster-ramsize=$COUCHBASE_RAM_SIZE --cluster-index-ramsize=$COUCHBASE_INDEX_RAM_SIZE \
#  --services=$ --eventing-ramsize=$COUCHBASE_EVENTING_RAM_SIZE

# Create RBAC user
#echo "Creating RBAC user..."
#couchbase-cli user-manage -c $CB_HOST -u $CB_USER -p $CB_PASS \
#  --set --rbac-username "$COUCHBASE_RBAC_USERNAME" --rbac-password "$COUCHBASE_RBAC_PASSWORD" \
#  --roles "$COUCHBASE_RBAC_NAME" --auth-domain local

# Create buckets
echo "Creating buckets..."

jq -c '.[]' $JSON_FILE | while read bucket; do
  NAME=$(echo $bucket | jq -r '.name')
  RAM=$(echo $bucket | jq -r '.ramQuotaMB')
  TYPE=$(echo $bucket | jq -r '.bucketType')
  EVICTION=$(echo $bucket | jq -r '.evictionPolicy')
  REPLICAS=$(echo $bucket | jq -r '.replicaNumber')
  FLUSH=$(echo $bucket | jq -r '.flushEnabled')

  couchbase-cli bucket-create -c $CB_HOST -u $CB_USER -p $CB_PASS \
    --bucket=$NAME --bucket-type=$TYPE --bucket-ramsize=$RAM \
    --bucket-eviction-policy=$EVICTION --bucket-replica=$REPLICAS \
    --enable-flush=$FLUSH

  echo "Created bucket: $NAME"

  sleep 10s

  # Create scopes and collections
  if echo $bucket | jq -e 'has("scopes")' > /dev/null; then
    echo "Adding scopes and collections for bucket: $NAME"
    echo $bucket | jq -c '.scopes | to_entries[]' | while read scopeEntry; do
      SCOPE_NAME=$(echo $scopeEntry | jq -r '.key')
      echo "Creating scope: $SCOPE_NAME in bucket: $NAME"
      cbq -u $CB_USER -p $CB_PASS -s "CREATE SCOPE \`$NAME\`.\`$SCOPE_NAME\`;"

      echo $scopeEntry | jq -c '.value.collections[]' | while read collection; do
        COLLECTION_NAME=$(echo $collection | jq -r '.')
        echo "Creating collection: $COLLECTION_NAME in scope: $SCOPE_NAME"
        cbq -u $CB_USER -p $CB_PASS -s "CREATE COLLECTION \`$NAME\`.\`$SCOPE_NAME\`.\`$COLLECTION_NAME\`;"
      done
    done
  fi
done

echo "Couchbase setup complete."


sleep 5s 

  # used to auto create the sync gateway user based on environment variables  
  # https://docs.couchbase.com/server/current/cli/cbcli/couchbase-cli-user-manage.html#examples

echo "creating users list..."

# Create Couchbase users
echo "Creating Couchbase users..."
jq -c '.[]' "$USERS_FILE" | while IFS= read -r user; do
  RBAC_NAME=$(echo "$user" | jq -r '.rbacName')
  RBAC_USERNAME=$(echo "$user" | jq -r '.rbacUsername')
  RBAC_PASSWORD=$(echo "$user" | jq -r '.rbacPassword')
  ROLES=$(echo "$user" | jq -r '.roles | join(",")')

  couchbase-cli user-manage -c $CB_HOST -u $CB_USER -p $CB_PASS \
    --set --rbac-username "$RBAC_USERNAME" --rbac-password "$RBAC_PASSWORD" \
    --roles "$ROLES" --auth-domain local

  echo "Created user: $RBAC_NAME ($RBAC_USERNAME)"
done


#  /opt/couchbase/bin/couchbase-cli user-manage \
#  --cluster http://127.0.0.1 \
#  --username $CB_USER \
#  --password $CB_PASS \
#  --set \
#  --rbac-username $COUCHBASE_RBAC_USERNAME \
#  --rbac-password $COUCHBASE_RBAC_PASSWORD \
#  --roles mobile_sync_gateway[*] \
#  --auth-domain local

#  sleep 2s 

# create indexes using the QUERY REST API  
#  /opt/couchbase/bin/curl -v http://127.0.0.1:8093/query/service \
#  -u $CB_USER:$CB_PASS \
#  -d 'statement=CREATE INDEX idx_projects_team on projects(team)'
      
#  sleep 2s

#  /opt/couchbase/bin/curl -v http://127.0.0.1:8093/query/service \
#  -u $COUCHBASE_ADMINISTRATOR_USERNAME:$COUCHBASE_ADMINISTRATOR_PASSWORD \
#  -d 'statement=CREATE INDEX idx_projects_type ON projects(documentType)'
      
#  sleep 2s

#  /opt/couchbase/bin/curl -v http://127.0.0.1:8093/query/service \
#  -u $COUCHBASE_ADMINISTRATOR_USERNAME:$COUCHBASE_ADMINISTRATOR_PASSWORD \
#  -d 'statement=CREATE INDEX idx_projects_projectId on projects(projectId)'

  sleep 2s

  # import sample data into the bucket
  # https://docs.couchbase.com/server/current/tools/cbimport-json.html

#  /opt/couchbase/bin/cbimport json --format list \
#  -c http://localhost:8091 \
#  -u $COUCHBASE_ADMINISTRATOR_USERNAME \
#  -p $COUCHBASE_ADMINISTRATOR_PASSWORD \
#  -d "file:///opt/couchbase/init/sample-data.json" -b 'projects' -g %projectId%

  # create file so we know that the cluster is setup and don't run the setup again 
  touch $FILE
fi 
  # docker compose will stop the container from running unless we do this
  # known issue and workaround
  tail -f /dev/null

