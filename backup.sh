#!/bin/bash

# Configuration
SOURCE_DIR="/opt/docker-stacks/"
BACKUP_DIR="/mnt/docker_data/backups"
MAX_BACKUPS=10
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="docker_stacks_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.log"

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create backup directory $BACKUP_DIR"
        exit 1
    fi
    echo "Created backup directory: $BACKUP_DIR"
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Check if backup directory is accessible (network mount might be disconnected)
if ! touch "$BACKUP_DIR/test_write_access" 2>/dev/null; then
    echo "Error: Cannot write to backup directory $BACKUP_DIR. Is the network mount available?"
    exit 1
else
    rm "$BACKUP_DIR/test_write_access"
fi

# Create the backup
echo "Creating backup of $SOURCE_DIR..."
echo "This may show warnings about changed files due to running containers, which is normal."
echo "Full logs will be saved to $LOG_FILE"

# Use tar with options to handle live containers
tar --warning=no-file-changed --exclude="*.socket" --exclude="**/docker.sock" \
    --exclude="**/ipc-socket" --exclude="**/sockets" \
    -czf "$BACKUP_DIR/$BACKUP_FILE" \
    -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2> >(tee "$LOG_FILE" >&2)

# Check exit status but don't fail on non-zero if it's just warnings
# tar returns 1 for warnings, 2 for errors
TAR_STATUS=$?
if [ $TAR_STATUS -eq 0 ]; then
    echo "Backup created successfully without warnings: $BACKUP_DIR/$BACKUP_FILE"
elif [ $TAR_STATUS -eq 1 ]; then
    echo "Backup created with warnings: $BACKUP_DIR/$BACKUP_FILE"
    echo "Warnings are likely due to files changing during backup (normal for running containers)"
    echo "Check $LOG_FILE for details"
else
    echo "Error: Backup creation failed with errors"
    echo "Check $LOG_FILE for details"
    exit 1
fi

# Get file size of the backup
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    echo "Backup size: $BACKUP_SIZE"
else
    echo "Error: Backup file was not created"
    exit 1
fi

# Cleanup old backups if we have more than MAX_BACKUPS
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/docker_stacks_backup_*.tar.gz 2>/dev/null | wc -l)
echo "Current backup count: $BACKUP_COUNT"

if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    NUM_TO_DELETE=$((BACKUP_COUNT - MAX_BACKUPS))
    echo "Removing oldest $NUM_TO_DELETE backup(s)..."
    
    # Also remove associated log files when removing backups
    ls -1t "$BACKUP_DIR"/docker_stacks_backup_*.tar.gz | tail -n "$NUM_TO_DELETE" | while read file; do
        echo "Deleting old backup: $(basename "$file")"
        rm "$file"
        
        # Try to remove associated log file by extracting timestamp
        BACKUP_TIMESTAMP=$(basename "$file" | sed -E 's/docker_stacks_backup_([0-9]{8}_[0-9]{6}).tar.gz/\1/')
        if [ -n "$BACKUP_TIMESTAMP" ] && [ -f "$BACKUP_DIR/backup_${BACKUP_TIMESTAMP}.log" ]; then
            rm "$BACKUP_DIR/backup_${BACKUP_TIMESTAMP}.log"
        fi
    done
fi

echo "Backup process completed"