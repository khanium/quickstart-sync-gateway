FROM couchbase:latest AS stage_base 
COPY config/ /opt/couchbase/init/
WORKDIR /bin
RUN curl -L -o /usr/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux64
RUN chmod 755 /usr/bin/jq

