#!/bin/bash
# used to start couchbase server - can't get around this as docker compose only allows you to start one command - so we have to start couchbase like the standard couchbase Dockerfile would 
# https://github.com/couchbase/docker/blob/master/enterprise/couchbase-server/7.2.0/Dockerfile#L88

CB_HOST="127.0.0.1"
CB_USER=${COUCHBASE_ADMINISTRATOR_USERNAME:-"Administrator"}
CB_PASS=${COUCHBASE_ADMINISTRATOR_PASSWORD:-"password"}
CB_SERVICES_CONFIG=${CB_SERVICES:-"data,query,index"}
JSON_FILE="/opt/couchbase/init/buckets.json"
USERS_FILE="/opt/couchbase/init/rbac-users.json"

# track if setup is complete so we don't try to setup again
FILE=/opt/couchbase/init/setupComplete.txt

LOGFILE=/opt/couchbase/init/container-startup.log
exec 3>&1 1>>${LOGFILE} 2>&1

CONFIG_DONE_FILE=/opt/couchbase/init/container-configured

/entrypoint.sh couchbase-server & 

config_done() {
  touch ${CONFIG_DONE_FILE}
  echo "Couchbase Admin UI: http://localhost:8091 "  | tee /dev/fd/3
  echo "  |- Login credentials: $CB_USER / $CB_PASS" | tee /dev/fd/3
  echo "Stopping config-couchbase service"
  sv stop /etc/service/config-couchbase
}

wait_for_uri() {
  expected=$1
  shift
  uri=$1
  echo "Waiting for $uri to be available..."
  while true; do
    status=$(curl -s -w "%{http_code}" -o /dev/null $*)
    if [ "x$status" = "x$expected" ]; then
      break
    fi
    echo "$uri not up yet, waiting 2 seconds..."
    sleep 2
  done
  echo "$uri ready, continuing"
}


panic() {
  cat <<EOF 1>&3

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Error during initial configuration - aborting container
Here's the log of the configuration attempt:
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
EOF
  cat $LOGFILE 1>&3
  echo 1>&3
  kill -HUP 1
  exit
}

couchbase_cli_check() {
  couchbase-cli $* || {
    echo Previous couchbase-cli command returned error code $?
    panic
  }
}

curl_check() {
  status=$(curl -sS -w "%{http_code}" -o /tmp/curl.txt $*)
  cat /tmp/curl.txt
  rm /tmp/curl.txt
  if [ "$status" -lt 200 -o "$status" -ge 300 ]; then
    echo
    echo Previous curl command returned HTTP status $status
    panic
  fi
}

if [ -e ${CONFIG_DONE_FILE} ]; then
  echo "Container previously configured." | tee /dev/fd/3
  config_done
else
  echo "Configuring Couchbase Server.  Please wait (~60 sec)..." | tee /dev/fd/3
fi

if ! [ -f "$FILE" ]; then
  # used to automatically create the cluster based on environment variables
  # https://docs.couchbase.com/server/current/cli/cbcli/couchbase-cli-cluster-init.html

  echo $CB_USER ":"  $CB_PASS  
  
  export PATH=/opt/couchbase/bin:${PATH}

  wait_for_uri 200 http://127.0.0.1:8091/ui/index.html 
 
  echo "Setting up cluster:"
  couchbase_cli_check cluster-init -c $CB_HOST \
  --cluster-username $CB_USER \
  --cluster-password $CB_PASS \
  --services $CB_SERVICES_CONFIG \
  --cluster-ramsize $COUCHBASE_RAM_SIZE \
  --cluster-index-ramsize $COUCHBASE_INDEX_RAM_SIZE 
  # \
  # --index-storage-setting default

  echo "Checking credentials with curl:"
  curl_check http://127.0.0.1:8091/settings/web -d port=8091 -d username=$CB_USER -d password=$CB_PASS -u $CB_USER:$CB_PASS
  echo

# Create buckets
echo "Creating buckets..."

jq -c '.[]' $JSON_FILE | while read bucket; do
  NAME=$(echo $bucket | jq -r '.name')
  RAM=$(echo $bucket | jq -r '.ramQuotaMB')
  TYPE=$(echo $bucket | jq -r '.bucketType')
  EVICTION=$(echo $bucket | jq -r '.evictionPolicy')
  REPLICAS=$(echo $bucket | jq -r '.replicaNumber')
  FLUSH=$(echo $bucket | jq -r '.flushEnabled')

  couchbase_cli_check bucket-create -c $CB_HOST -u $CB_USER -p $CB_PASS \
    --bucket=$NAME --bucket-type=$TYPE --bucket-ramsize=$RAM \
    --bucket-eviction-policy=$EVICTION --bucket-replica=$REPLICAS \
    --enable-flush=$FLUSH

  echo "Created bucket: $NAME"


  # Create scopes and collections
  if echo $bucket | jq -e 'has("scopes")' > /dev/null; then
    echo "Adding scopes and collections for bucket: $NAME"
    echo $bucket | jq -c '.scopes | to_entries[]' | while read scopeEntry; do
      SCOPE_NAME=$(echo $scopeEntry | jq -r '.key')
      if [[ "$SCOPE_NAME" != "_default" ]]; then 
        echo "Creating scope: $SCOPE_NAME in bucket: $NAME"
        #cbq -u $CB_USER -p $CB_PASS -s "CREATE SCOPE \`$NAME\`.\`$SCOPE_NAME\`;"
        couchbase_cli_check collection-manage -c 127.0.0.1 \
                -u "$CB_USER" -p "$CB_PASS" --bucket "$NAME" \
                --create-scope "$SCOPE_NAME"
      fi


      echo $scopeEntry | jq -c '.value.collections[]' | while read collection; do
        echo "@@@@@@@@@ DEBUG MODE ---------------"
        echo "found collection: $collection"
        echo "@@@@@@@@@---------------"
        COLLECTION_NAME=$(echo "$collection" | jq -r '.')
        # COLLECTION_NAME="$collection"
        echo "COLLECTION_NAME: $COLLECTION_NAME"
        echo "Creating collection: $COLLECTION_NAME in scope: $SCOPE_NAME"
        # cbq -u $CB_USER -p $CB_PASS -s "CREATE COLLECTION \`$NAME\`.\`$SCOPE_NAME\`.\`$COLLECTION_NAME\`;"
        couchbase_cli_check collection-manage -c 127.0.0.1 -u "$CB_USER" -p "$CB_PASS" --bucket "$NAME" --create-collection $SCOPE_NAME.$COLLECTION_NAME

        # Get all JSON files
        FOLDER="/opt/couchbase/init/$NAME/$SCOPE_NAME/$COLLECTION_NAME"
        # $FOLDER/*.json Non-recursive: maxdepth 1
        mapfile -t JSON_FILES < <(find "$FOLDER" -maxdepth 1 -type f -name '*.json')

        # Check if any JSON files were found
        if [[ ${#JSON_FILES[@]} -gt 0 ]]; then
           # sleep 2s
           echo "found dataset files for the \`$COLLECTION_NAME\` collection..."
           COUNT="${#JSON_FILES[@]}"
           echo " - Found $COUNT json files inside of the collection folder '$FOLDER'."
           # Print each JSON file
           for file in "${JSON_FILES[@]}"; do
             echo "=============================="
             echo "Loading: $file into \`$SCOPE_NAME\`.\`$COLLECTION_NAME\`"
             echo "------------------------------"
             cbimport json --format lines \
               -c http://localhost:8091 \
               -u $COUCHBASE_ADMINISTRATOR_USERNAME \
               -p $COUCHBASE_ADMINISTRATOR_PASSWORD \
               -d "file://$file" \
               -b $NAME \
               --scope-collection-exp "$SCOPE_NAME.$COLLECTION_NAME" \
               -g %id%
             echo -e "\n"
           done
        fi


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

  couchbase_cli_check user-manage -c $CB_HOST -u $CB_USER -p $CB_PASS \
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

  # echo "Couchbase installed & configured in your local: https://locahost:8091"
  # docker compose will stop the container from running unless we do this
  # known issue and workaround
  # tail -f /dev/null
echo "Configuration completed!" | tee /dev/fd/3
config_done

  # docker compose will stop the container from running unless we do this
  # known issue and workaround
tail -f /dev/null
