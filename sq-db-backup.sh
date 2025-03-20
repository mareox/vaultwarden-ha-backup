#!/bin/bash

# Define variables
BACKUP_DIR="/mx-server/backups/BK_vaultwarden"
BACKUP_NAME="db-$(date '+%Y%m%d-%H%M').sqlite3"
DB_FILE="/vw-data/db.sqlite3"
MAX_BACKUPS=30

# Create the backup directory if it doesn't exist - test123
mkdir -p "$BACKUP_DIR"

# Run the backup command
sqlite3 "$DB_FILE" ".backup '$BACKUP_DIR/$BACKUP_NAME'"

# Delete old backups if there are more than the maximum allowed
cd "$BACKUP_DIR"
BACKUPS_COUNT=$(ls -1 | grep "^db-[0-9]\{8\}-[0-9]\{4\}.sqlite3$" | wc -l)
if [ $BACKUPS_COUNT -gt $MAX_BACKUPS ]; then
  ls -1t | grep "^db-[0-9]\{8\}-[0-9]\{4\}.sqlite3$" | tail -$((BACKUPS_COUNT - MAX_BACKUPS)) | xargs -d '\n' rm
fi
