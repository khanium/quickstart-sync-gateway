#!/bin/bash
echo "create database in sync gateway..."
curl -u sync_gateway:password -X PUT "http://sync-gateway:4985/db/" -H "accept: */*" -H "Content-Type: application/json" -d @./database.json
