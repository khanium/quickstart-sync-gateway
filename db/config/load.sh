#!/bin/bash

# Read the JSON file
json_file="buckets.json"
if [ ! -f "$json_file" ]; then
    echo "Error: $json_file not found."
    exit 1
fi

# Extract names from JSON file
bucket_names=($(jq -r '.[].name' "$json_file"))

# Iterate over bucket names
for bucket_name in "${bucket_names[@]}"; do
    folder_path="./$bucket_name"

    # Check if the folder exists
    if [ -d "$folder_path" ]; then
        echo "Checking $folder_path..."

        # Find JSON files in the folder (excluding collections.json)
        json_files=($(find "$folder_path" -type f -name '*.json' ! -name 'collections.json'))

        # Print the filenames
        if [ ${#json_files[@]} -gt 0 ]; then
            echo "Files in $folder_path that do not match collections.json:"
            printf "%s\n" "${json_files[@]}"
            for json_file in "${json_files[@]}"; do
              printf "loading '%s' in '%s' bucket... \n" "${json_file}" "${bucket_name}"
              cbimport json --format list -c 'localhost' -u Administrator -p "password" -d "file://$json_file" -b "$bucket_name" --scope-collection-exp "_default._default" -g "%type%:%id%"
            done
        else
            echo "No matching JSON files found in $folder_path. The folder is empty, please add the dataset json array file to be loaded"
            echo
        fi
    fi
done

# /Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/bin/cbimport json --format list -c '127.0.0.1' -u Administrator -p "Password" -d "file://$1.json" -b 'demo' --scope-collection-exp "_default._default" -g "$2:%id%"