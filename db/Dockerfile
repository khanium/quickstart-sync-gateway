FROM couchbase:latest AS stage_base 
COPY config/init-cbserver.sh /opt/couchbase/init/
COPY config/sample-data.json /opt/couchbase/init/
COPY config/buckets.json /opt/couchbase/init/
COPY config/rbac-users.json /opt/couchbase/init/
WORKDIR /bin
RUN curl -L -o /usr/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux64
RUN chmod 755 /usr/bin/jq

