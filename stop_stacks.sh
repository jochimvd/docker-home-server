#!/bin/bash
config_file="/opt/docker-stacks/stacks.conf"
if [ ! -f "$config_file" ]; then
  echo "Error: Configuration file '$config_file' not found."
  exit 1
fi

mapfile -t compose_directories < <(tac "$config_file")

# Iterate through the reversed list of compose directories
for compose_directory in "${compose_directories[@]}"; do
  full_compose_directory="/opt/docker-stacks/$compose_directory"
  if [ ! -d "$full_compose_directory" ]; then
    echo "Warning: Directory '$full_compose_directory' not found. Skipping."
    continue
  fi
  
  echo "Stopping stack from directory: $full_compose_directory"
  
  # Use pushd to temporarily change to the directory
  pushd "$full_compose_directory" > /dev/null || {
    echo "Error: Could not change to directory '$full_compose_directory'"
    continue
  }
  
  # Run docker compose stop
  docker compose stop
  
  # Return to the original directory
  popd > /dev/null
done

echo "All stacks stopped."