#!/bin/bash

# Requires: jq

config_file="/opt/docker-stacks/stacks.conf"

wait_for_stack() {
  local stack_name="$1"
  local timeout="$2"
  local start_time=$(date +%s)

  while true; do
    status=$(docker compose ps --format json)

    if [ -z "$status" ]; then
      echo "Stack not started yet..."
      sleep 5
      continue
    fi

    all_running=true
    for service in $(echo "$status" | jq -s -r '.[] | .Name'); do
      state=$(echo "$status" | jq -s -r --arg service "$service" '.[] | select(.Name == $service) | .State')
      health=$(echo "$status" | jq -s -r --arg service "$service" '.[] | select(.Name == $service) | .Health')

      if [ -z "$state" ]; then
        all_running=false
        break
      fi

      if [ ! -z "$health" ] && [ "$health" != "healthy" ]; then
        all_running=false
        break
      fi
    done

    if [ "$all_running" = true ]; then
      echo "Stack '$stack_name' is healthy."
      return 0
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [ "$elapsed_time" -ge "$timeout" ]; then
      echo "Timeout waiting for stack '$stack_name' to be healthy."
      return 1
    fi

    echo "Waiting for stack '$stack_name' to become healthy..."
    sleep 5
  done
}

if [ ! -f "$config_file" ]; then
  echo "Error: Configuration file '$config_file' not found."
  exit 1
fi

# Read the compose file paths from the config file
while IFS= read -r compose_directory; do
  full_compose_directory="/opt/docker-stacks/$compose_directory"
  if [ ! -d "$full_compose_directory" ]; then
    echo "Warning: Directory '$full_compose_directory' not found. Skipping."
    continue
  fi
  echo "Starting stack from directory: $full_compose_directory"

  # Use pushd to temporarily change to the directory
  pushd "$full_compose_directory" > /dev/null || {
    echo "Error: Could not change to directory '$full_compose_directory'"
    continue
  }

  docker compose up -d

  # Check if wait_for_stack was successful
  if ! wait_for_stack "$compose_directory" 60; then
    echo "Error: Stack at '$full_compose_directory' failed to start or become healthy."
    popd > /dev/null
    exit 1
  fi

  echo "Stack from '$full_compose_directory' started and is healthy."

  # Return to the original directory
  popd > /dev/null
  
done < <(awk '1' "$config_file")

echo "All stacks started."