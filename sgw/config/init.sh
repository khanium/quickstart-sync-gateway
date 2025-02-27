#!/bin/bash
sleep 10s
echo '-- --------------------------------- --'
echo '   step 1 - create database '
echo '-- --------------------------------- ---'
./01_create-database.sh
sleep 10s
echo '-- ---------------------------------- --'
echo '   step 2 - create Database Users '
echo '-- --------------------------------- --'
./02_create-users.sh
echo 'Completed Sync Gateway setup!'
