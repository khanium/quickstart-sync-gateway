#!/bin/bash

# Specify the path to your JSON array file
json_file="users.json"

# Check if the file exists
if [ ! -f "$json_file" ]; then
    echo "Error: JSON file not found!"
    exit 1
fi

# Read the JSON array from the file and extract each item
json_array=$(cat "$json_file" | jq -c '.[]')

username="-u sync_gateway:password"
api_url="http://sync-gateway:4985"
database="db"

# Loop through each JSON item and perform a curl POST request
while IFS= read -r json_item; do
    # Replace the following placeholder URL with your actual API endpoint
    name=$(echo "$json_item" | jq -r '.name')
   
    # Perform the curl POST request with the current JSON item as payload
    echo "Creating SGW user: ${name}... $api_url/$database/_user/"
    curl -u sync_gateway:password -X POST -H "accept: */*" -H "Content-Type: application/json" -d "$json_item" "$api_url/$database/_user/"
    
    # Add a sleep if needed to avoid rate limiting or excessive requests
    sleep 1
done <<< "$json_array"


