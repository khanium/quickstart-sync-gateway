#!/bin/bash
echo -n " - deleting couchbase data...                "
rm -Rf db/couchbase/*
# Check if folder is empty and print result on the same line
if [ -z "$(ls db/couchbase)" ]; then
  echo "✅"
else
  echo "⚠️  Not empty"
fi

echo -n " - deleting sync gateway logs...             "
rm -Rf sgw/logs/*
if [ -z "$(ls sgw/logs)" ]; then
  echo "✅"
else
  echo "⚠️️ ️️  Not empty"
fi

echo -n " - deleting promtail log...                  "
rm -Rf promtail/log/*
if [ -z "$(ls promtail/log)" ]; then
  echo "✅"
else
  echo "⚠️️ ️️  Not empty"
fi

echo -n " - deleting prometheus data...               "
rm -Rf prometheus/data/*
if [ -z "$(ls prometheus/data)" ]; then
  echo "✅"
else
  echo "⚠️️ ️️  Not empty"
fi

echo -n " - deleting alertmanager data...             "
rm -Rf alertmanager/data/*
if [ -z "$(ls alertmanager/data)" ]; then
  echo "✅"
else
  echo "⚠️️ ️️  Not empty"
fi

echo -n " - deleting grafana db data...               "
rm -Rf grafana/data/*
if [ -z "$(ls grafana/data)" ]; then
  echo "✅"
else
  echo "⚠️️ ️️  Not empty"
fi

echo " -- ------------------------------------------- -- "
echo " --  clean up completed ✅  successfully"

