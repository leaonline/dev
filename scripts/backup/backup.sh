#!/bin/bash

set -e

OUTPUT_PATH="/var/backups/lea/mongodump_$(date +%Y-%m-%d_%H-%M).gz"
LOG_FILE="/var/backups/lea/backup.log"

# Function to log messages with timestamps
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}


log_message "Creating MongoDB backup at $OUTPUT_PATH"

# first create the mongodump inside the docker container
# make sure to mit -it flags to avoid tty errors when running via cron
docker exec mongodb mongodump --archive=/root/mongodump.gz --gzip --quiet >> "$LOG_FILE" 2>&1

# then copy it to the host machine
log_message "Copying backup to host machine..."
docker cp mongodb:/root/mongodump.gz "$OUTPUT_PATH" >> "$LOG_FILE" 2>&1

# finally remove the temporary archive inside the container
log_message "Cleaning up temporary files inside the container..."
docker exec mongodb rm -f /root/mongodump.gz >> "$LOG_FILE" 2>&1

# update permissions on the file
log_message "Setting permissions on the backup file..."
chmod 640 "$OUTPUT_PATH"
chown :appbackup "$OUTPUT_PATH"

log_message "Backup created at $OUTPUT_PATH"
exit 0
