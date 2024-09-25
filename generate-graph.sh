#!/bin/bash

# Check if at least one username is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 username1 [username2 ...]"
    exit 1
fi

# Ensure required commands are available
for cmd in curl jq dot; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' command not found. Please install it and try again."
        exit 1
    fi
done

# Build the JSON payload
usernames_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)

# Fetch the network data
response=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"usernames\": $usernames_json}" \
    "https://server.farviz.xyz/api/network-data")

# Check if the curl command was successful
if [ $? -ne 0 ]; then
    echo "Error fetching network data"
    exit 1
fi

# Check if the response contains an error
error=$(echo "$response" | jq -r '.error // empty')
if [ -n "$error" ]; then
    echo "API error: $error"
    exit 1
fi

# Start the dot file
echo "digraph G {" > graph.dot

# Add nodes to the dot file
echo "$response" | jq -r '.userData[] | "\(.fid) [label=\"\(.username)\"];"' >> graph.dot

# Add edges to the dot file
echo "$response" | jq -r '
    .followData | to_entries[] |
    .key as $source |
    .value[] | "\($source) -> \(.targetFid);"
' >> graph.dot

# Finish the dot file
echo "}" >> graph.dot

# Generate SVG using dot
dot -Tsvg graph.dot -o graph.svg

echo "Graph generated: graph.svg"
