#!/bin/bash
echo "deleting couchbase data..."
rm -Rf db/couchbase/*
echo "deleting sync gateway logs..."
rm -Rf sgw/logs/*
echo "deleting promtail log..."
rm -Rf promtail/log/*
echo "deleting prometheus data..."
rm -Rf prometheus/data/*
echo "deleting alertmanager data..."
rm -Rf alertmanager/data/*
echo "deleting grafana db data..."
rm -Rf grafana/data/*
echo "clean up completed successfully"

