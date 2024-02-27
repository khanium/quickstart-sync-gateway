#!/bin/bash
echo "create database in sync gateway..."
curl -X PUT "http://localhost:4985/db/" -H "accept: */*" -H "Content-Type: application/json" -d @./database.json
