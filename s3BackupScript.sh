#!/bin/bash

# Backup script to AWS S3 with reporting

# Configuration variables
SOURCE_DIR="/home/sanjeev/Task"          # Directory to backup
S3_BUCKET="s3://my-backup-bucket-sanjeev-2025"  # S3 bucket URL
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_$TIMESTAMP.tar.gz"
TEMP_DIR="/tmp/backup_$TIMESTAMP"
LOG_FILE="/home/sanjeev/backup_report_$TIMESTAMP.log"  # Changed to user-writable directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to check AWS CLI installation
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_message "${RED}ERROR: AWS CLI not installed. Please install it first.${NC}"
        exit 1
    fi
}

# Start backup process
log_message "Starting backup process..."

# Check prerequisites
check_aws_cli

# Create temporary directory
if mkdir -p "$TEMP_DIR"; then
    log_message "Temporary directory created successfully: $TEMP_DIR"
else
    log_message "${RED}ERROR: Failed to create temporary directory${NC}"
    exit 1
fi

# Create tarball of source directory
log_message "Creating compressed backup of $SOURCE_DIR..."
tar -czf "$TEMP_DIR/$BACKUP_NAME" -C "$SOURCE_DIR" . 2>> "$LOG_FILE"
if [ $? -eq 0 ]; then
    log_message "${GREEN}Successfully created backup archive${NC}"
else
    log_message "${RED}ERROR: Failed to create backup archive${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Upload to S3
log_message "Uploading backup to S3 bucket: $S3_BUCKET..."
aws s3 cp "$TEMP_DIR/$BACKUP_NAME" "$S3_BUCKET/$BACKUP_NAME" 2>> "$LOG_FILE"
if [ $? -eq 0 ]; then
    log_message "${GREEN}Successfully uploaded backup to S3${NC}"
else
    log_message "${RED}ERROR: Failed to upload backup to S3${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Verify upload
log_message "Verifying backup in S3..."
aws s3 ls "$S3_BUCKET/$BACKUP_NAME" &> /dev/null
if [ $? -eq 0 ]; then
    log_message "${GREEN}Backup verification successful${NC}"
else
    log_message "${RED}ERROR: Backup verification failed${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup
log_message "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Complete
log_message "${GREEN}Backup process completed successfully${NC}"

exit 0
