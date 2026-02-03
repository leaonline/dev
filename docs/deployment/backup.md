# Backup

This guide shows how to setup a backup user (as example on Ubuntu Server) that regularly performs backups
and is used by the external backup server to fetch the backup files via SCP.

## Prerequisites

Make sure you successfully deployed a lea. app and it runs correctly.
You need SSH access to the server where the lea. app, that is to be backed up, is deployed.
This guide is intended for self-contained deployments, meaning there is a database running
on each app server separately.

## Create Backup User
First, you need to create a new user on the lea. app server that will represent the remote backup server.
It should be part of a dedicated group for backup users, e.g. `appbackup`:

```bash
adduser backupuser
groupadd appbackup
usermod -aG appbackup backupuser
```

Then, create a new folder for the backup destination. 
The backup user needs to have read access to the backup files:

```bash
mkdir /var/backups/lea
chown -R :appbackup /var/backups/lea/
chmod -R 750 /var/backups/lea/
```

Note, the owner should remain the user who will perform the actual backups.
This user should not be the backupuser, because this would require the backupuser to be part of the `docker`
group to read the database files.

> [warning]
> Make sure that the backupuser on the lea. app server has no shell access or only a restricted shell.
> You can restrict the shell access by setting the shell to `/usr/sbin/nologin` or using a restricted shell like `rbash`.

Test the backup user by switching to it:

```bash
su - backupuser
```
  

## Install the Backup Cron Job
Copy the backup script or upload it to the server and place it in `/usr/local/bin/backup_lea.sh`:

```bash
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
docker exec -it mongodb mongodump --archive=/root/mongodump.gz --gzip --quiet >> "$LOG_FILE" 2>&1

# then copy it to the host machine
log_message "Copying backup to host machine..."
docker cp mongodb:/root/mongodump.gz "$OUTPUT_PATH" >> "$LOG_FILE" 2>&1

# finally remove the temporary archive inside the container
log_message "Cleaning up temporary files inside the container..."
docker exec -it mongodb rm -f /root/mongodump.gz >> "$LOG_FILE" 2>&1

# update permissions on the file
log_message "Setting permissions on the backup file..."
chmod 640 "$OUTPUT_PATH"
chown :appbackup "$OUTPUT_PATH"

log_message "Backup created at $OUTPUT_PATH"
exit 0
```

Make the script executable for the owner:

```bash
chmod 700 /usr/local/bin/backup_lea.sh
```

Then, create a cron job for the user who is performing the backups (not the backupuser!).

```bash
crontab -e
```

Add the following line to run the backup script every day at 2am:

```bash
0 2 * * * /usr/local/bin/backup_lea.sh
```

Save and exit the crontab editor.

## Set up the pull strategy on the backupserver

If your backupserver has no SSH key pair yet, create one with:

```bash
ssh-keygen -t rsa -b 4096
```

and make sure to not set a passphrase, so that automated scripts can use the key without user interaction.

Then, make sure the remote backup server has SSH access to the lea. app server via the backupuser user.
You can do this either by using [ssh-copy-id](https://unix.stackexchange.com/questions/29386/how-do-you-copy-the-public-key-to-a-ssh-server)
or, if you already disabled ssh password authentication by manually adding the public key to the `/home/backupuser/.ssh/authorized_keys` file.

Do not forget to adjust permissions:

```shell
chown -R backupuser:backupuser /home/backupuser/.ssh/
chmod 700 /home/backupuser/.ssh/
chmod 600 /home/backupuser/.ssh/authorized_keys
```

> [warning]
> Test, if you can connect to the lea. app server from the backup server without being prompted for a password:
> ```bash
> ssh -i /path/to/private_key backupuser@lea-app-server-ip
> ```

Now you can create a script on the backup server that fetches the backup files via SCP.

## Create the Fetch Script on the Backup Server
Since your backup server will likely handle multiple lea apps and the backup
routine is basically the same, you can create a generic script that takes parameters
to pull from the different lea. app servers:

<details>
<summary>
Click here to show the full pull.sh script</summary>

```bash
#!/bin/bash

################################################################################
# lea. Backup Pull Script
#
# This script is run ON THE BACKUP SERVER to pull backups FROM the application
# server via SCP. This provides better security than pushing backups, as the
# application server does not need credentials to access the backup server.
#
# The application server should have backups available locally (created by
# backup.sh), and this script connects to it to fetch those backups.
#
# Configuration can be provided via:
# 1. A pull.config file in the same directory
# 2. Environment variables
# 3. Command-line arguments
#
# Usage: ./pull.sh [options]
# Options:
#   -c, --config FILE    Path to configuration file
#   -d, --dir DIR        Local destination directory for pulled backups
#   -l, --list           List available backups on application server
#   -n, --name NAME      Specific backup name to pull
#   --latest             Pull the latest backup
#   --all                Pull all backups from application server
#   -h, --help           Show this help message
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/lea}"
LOG_FILE="${LOG_FILE:-$BACKUP_DIR/pull.log}"

# Application server configuration (source of backups)
APP_SERVER_HOST="${APP_SERVER_HOST:-}"
APP_SERVER_USER="${APP_SERVER_USER:-}"
APP_SERVER_BACKUP_PATH="${APP_SERVER_BACKUP_PATH:-/var/backups/lea}"
APP_SERVER_PORT="${APP_SERVER_PORT:-22}"
APP_SERVER_KEY="${APP_SERVER_KEY:-}"

# Operation mode
LIST_MODE=false
PULL_LATEST=false
PULL_ALL=false
BACKUP_NAME=""

# Parse command-line arguments
CONFIG_FILE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -l|--list)
            LIST_MODE=true
            shift
            ;;
        -n|--name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        --latest)
            PULL_LATEST=true
            shift
            ;;
        --all)
            PULL_ALL=true
            shift
            ;;
        -h|--help)
            echo "lea Backup Pull Script"
            echo ""
            echo "Run this script ON THE BACKUP SERVER to pull backups FROM the application server."
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -c, --config FILE    Path to configuration file"
            echo "  -d, --dir DIR        Local destination directory for pulled backups"
            echo "  -l, --list           List available backups on application server"
            echo "  -n, --name NAME      Specific backup name to pull"
            echo "  --latest             Pull the latest backup"
            echo "  --all                Pull all backups from application server"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Configuration can also be provided via environment variables or a pull.config file"
            echo "in the same directory as this script."
            echo ""
            echo "Required configuration:"
            echo "  APP_SERVER_HOST         - Application server hostname or IP"
            echo "  APP_SERVER_USER         - SSH username for application server"
            echo "  APP_SERVER_BACKUP_PATH  - Path to backups on application server"
            echo ""
            echo "Optional configuration:"
            echo "  APP_SERVER_PORT         - SSH port (default: 22)"
            echo "  APP_SERVER_KEY          - Path to SSH private key"
            echo "  BACKUP_DIR              - Local destination directory (default: /var/backups/lea)"
            echo ""
            echo "Examples:"
            echo "  $0 --list                              # List available backups"
            echo "  $0 --latest                            # Pull the latest backup"
            echo "  $0 --name  mongodump_2026-01-08_00-00.gz"
            echo "  $0 --all                               # Pull all backups"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load configuration file if it exists
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from: $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
elif [ -f "$SCRIPT_DIR/pull.config" ]; then
    echo "Loading configuration from: $SCRIPT_DIR/pull.config"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/pull.config"
fi

# Function to log messages
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to handle errors
error_exit() {
    local message="$1"
    log_message "ERROR: $message"
    exit 1
}

# Validate application server configuration
if [ -z "$APP_SERVER_HOST" ] || [ -z "$APP_SERVER_USER" ] || [ -z "$APP_SERVER_BACKUP_PATH" ]; then
    error_exit "Application server configuration incomplete. Required: APP_SERVER_HOST, APP_SERVER_USER, APP_SERVER_BACKUP_PATH"
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory: $BACKUP_DIR"

# Build SSH/SCP command arrays
SSH_CMD="ssh -p $APP_SERVER_PORT"
SCP_CMD="scp -P $APP_SERVER_PORT"

# Add SSH key if specified
if [ -n "$APP_SERVER_KEY" ]; then
    SSH_CMD="$SSH_CMD -i $APP_SERVER_KEY"
    SCP_CMD="$SCP_CMD -i $APP_SERVER_KEY"
fi

# Function to list remote backups
list_remote_backups() {
    log_message "Listing backups on application server: $SSH_CMD $APP_SERVER_USER@$APP_SERVER_HOST:$APP_SERVER_BACKUP_PATH"

    # List backup files on application server
    if $SSH_CMD "$APP_SERVER_USER@$APP_SERVER_HOST" "ls -lh '$APP_SERVER_BACKUP_PATH'/mongodump*.gz 2>/dev/null" 2>> "$LOG_FILE"; then
        echo ""
        log_message "Available backups listed above"
    else
        log_message "WARNING: No backups found or unable to access application server directory"
        return 1
    fi
}

# Function to get latest backup name
get_latest_backup() {
    local latest=""
    latest=$($SSH_CMD "$APP_SERVER_USER@$APP_SERVER_HOST" "ls -t '$APP_SERVER_BACKUP_PATH'/mongodump*.gz 2>/dev/null | head -n 1" 2>> "$LOG_FILE")

    if [ -z "$latest" ]; then
        error_exit "No backups found on application server"
    fi

    # Extract just the filename
    basename "$latest"
}

# Function to pull a specific backup
# Returns: 0 = success (downloaded), 2 = skipped (already exists), 1 = failed
pull_backup() {
    local backup_file="$1"
    local remote_file="$APP_SERVER_BACKUP_PATH/$backup_file"
    local local_file="$BACKUP_DIR/$backup_file"

    log_message "Pulling backup: $backup_file"
    log_message "From: $APP_SERVER_USER@$APP_SERVER_HOST:$remote_file"
    log_message "To: $local_file"

    # Check if file already exists locally
    if [ -f "$local_file" ]; then
        log_message "WARNING: Backup already exists locally: $local_file"
        log_message "Skipping download (file already present)"
        return 2
    fi

    # Pull the backup
    log_message "$SCP_CMD $APP_SERVER_USER@$APP_SERVER_HOST:$remote_file"
    if $SCP_CMD "$APP_SERVER_USER@$APP_SERVER_HOST:$remote_file" "$local_file" 2>> "$LOG_FILE"; then
        # Calculate backup size
        BACKUP_SIZE=$(du -h "$local_file" | cut -f1)
        log_message "Successfully pulled backup: $backup_file ($BACKUP_SIZE)"
        return 0
    else
        log_message "ERROR: Failed to pull backup: $backup_file"
        return 1
    fi
}

# Function to pull all backups
pull_all_backups() {
    log_message "Pulling all backups from application server..."

    # Get list of all backup files
    local backup_list=""
    backup_list=$($SSH_CMD "$APP_SERVER_USER@$APP_SERVER_HOST" "ls '$APP_SERVER_BACKUP_PATH'/mongodump*.gz 2>/dev/null" 2>> "$LOG_FILE")

    if [ -z "$backup_list" ]; then
        error_exit "No backups found on application server"
    fi

    local success_count=0
    local skip_count=0
    local fail_count=0

    while IFS= read -r remote_file; do
        local backup_file
        backup_file=$(basename "$remote_file")

        pull_backup "$backup_file"
        local result=$?

        if [ $result -eq 0 ]; then
            success_count=$((success_count + 1))
        elif [ $result -eq 2 ]; then
            skip_count=$((skip_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done <<< "$backup_list"

    log_message "========================================"
    log_message "Pull all backups completed"
    log_message "Successfully pulled: $success_count"
    log_message "Skipped (already present): $skip_count"
    log_message "Failed: $fail_count"
    log_message "========================================"
}

# Main execution logic
log_message "========================================"
log_message "lea. Backup Pull Script Started"
log_message "========================================"

if [ "$LIST_MODE" = true ]; then
    # List mode
    list_remote_backups
    exit 0
elif [ "$PULL_ALL" = true ]; then
    # Pull all backups
    pull_all_backups
    exit 0
elif [ "$PULL_LATEST" = true ]; then
    # Pull latest backup
    log_message "Fetching latest backup from remote server..."
    BACKUP_NAME=$(get_latest_backup)
    log_message "Latest backup: $BACKUP_NAME"
    pull_backup "$BACKUP_NAME"
    result=$?
    if [ $result -eq 0 ]; then
        log_message "========================================"
        log_message "Latest backup pulled successfully"
        log_message "Location: $BACKUP_DIR/$BACKUP_NAME"
        log_message "========================================"
        exit 0
    elif [ $result -eq 2 ]; then
        log_message "========================================"
        log_message "Latest backup already exists locally"
        log_message "Location: $BACKUP_DIR/$BACKUP_NAME"
        log_message "========================================"
        exit 0
    else
        error_exit "Failed to pull latest backup"
    fi
elif [ -n "$BACKUP_NAME" ]; then
    # Pull specific backup
    pull_backup "$BACKUP_NAME"
    result=$?
    if [ $result -eq 0 ]; then
        log_message "========================================"
        log_message "Backup pulled successfully"
        log_message "Location: $BACKUP_DIR/$BACKUP_NAME"
        log_message "========================================"
        exit 0
    elif [ $result -eq 2 ]; then
        log_message "========================================"
        log_message "Backup already exists locally"
        log_message "Location: $BACKUP_DIR/$BACKUP_NAME"
        log_message "========================================"
        exit 0
    else
        error_exit "Failed to pull backup: $BACKUP_NAME"
    fi
else
    # No operation specified
    echo "Error: No operation specified"
    echo "Use --list, --latest, --all, or --name to specify what to pull"
    echo "Use --help for usage information"
    exit 1
fi
```

</details>

then create a pull.config file with the parameters for each lea. app server:

```
# lea Backup Pull Configuration
#
# This file contains configuration for the pull script.
# Copy this file to pull.config and adjust the values as needed.
#
# The pull script is run ON THE BACKUP SERVER to pull backups FROM the
# application server. This provides better security than pushing backups,
# as the application server does not need credentials to access the backup server.
#
# All settings can also be provided as environment variables or command-line arguments.

# Local backup directory (on the backup server)
BACKUP_DIR="/var/backups/lea"

# Application server configuration (where backups are created)
# This is the server running a lea app with backups created by backup.sh
APP_SERVER_HOST="app.example.com"
APP_SERVER_USER="backupuser"
APP_SERVER_BACKUP_PATH="/var/backups/lea"
APP_SERVER_PORT="22"

# Optional: SSH key path (if not using default)
# APP_SERVER_KEY="/path/to/ssh/key"

# Log file location
LOG_FILE="/var/backups/openqda/pull.log"
```

Test the script via `./pull.sh --list` to see the available backups on the lea. app server and download
them via `./pull.sh --latest` or `./pull.sh --all`.

If this succeeded then you can setup a cron job on the backup server to regularly pull the backups:

```bash
crontab -e
```

Add the following line to run the pull script every day at 3am:

```bash
0 3 * * * /path/to/pull.sh --latest
```
Save and exit the crontab editor.

## Conclusion

You have successfully setup a backup user on the lea. app server and configured a backup routine
that creates backups regularly. You also setup a pull strategy on the backup server
that fetches the backups via SCP.
