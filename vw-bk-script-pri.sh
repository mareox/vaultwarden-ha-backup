#!/bin/bash

# Set error handling
set -e

# Define variables
CONTAINER_NAME="vaultwarden"
BACKUP_SCRIPT="/etc/scripts/sq-db-backup.sh"
LOG_FILE="/etc/scripts/sq-db-backup.sh.log"
MAX_RESTART_ATTEMPTS=3
RESTART_ATTEMPTS=0

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if container exists
if ! docker ps -a | grep -q $CONTAINER_NAME; then
    log "Error: Container $CONTAINER_NAME does not exist!"
    exit 1
fi

# Stop the vaultwarden container
log "Stopping $CONTAINER_NAME container..."
if ! docker stop $CONTAINER_NAME; then
    log "Error: Failed to stop $CONTAINER_NAME container!"
    exit 1
fi
log "$CONTAINER_NAME container stopped successfully."

# Run the backup script
log "Running backup script..."
if [ -x "$BACKUP_SCRIPT" ]; then
    if ! bash "$BACKUP_SCRIPT"; then
        log "Error: Backup script failed!"
        log "Attempting to restart $CONTAINER_NAME container anyway..."
    else
        log "Backup completed successfully."
    fi
else
    log "Error: Backup script not found or not executable!"
    log "Please check the path: $BACKUP_SCRIPT"
    log "Attempting to restart $CONTAINER_NAME container anyway..."
fi

# Restart the container with retry mechanism
while [ $RESTART_ATTEMPTS -lt $MAX_RESTART_ATTEMPTS ]; do
    log "Starting $CONTAINER_NAME container (attempt $((RESTART_ATTEMPTS+1))/$MAX_RESTART_ATTEMPTS)..."
    if docker start $CONTAINER_NAME; then
        # Verify container is running
        sleep 10
        if docker ps | grep -q $CONTAINER_NAME; then
            log "$CONTAINER_NAME container started successfully."
            exit 0
        else
            log "Error: $CONTAINER_NAME container started but stopped immediately."
        fi
    else
        log "Error: Failed to start $CONTAINER_NAME container!"
    fi
    
    RESTART_ATTEMPTS=$((RESTART_ATTEMPTS+1))
    
    if [ $RESTART_ATTEMPTS -lt $MAX_RESTART_ATTEMPTS ]; then
        log "Retrying in 5 seconds..."
        sleep 5
    fi
done

# If we reached here, all restart attempts failed
log "Error: Failed to restart $CONTAINER_NAME container after $MAX_RESTART_ATTEMPTS attempts."
log "System will reboot in 10 seconds..."
sleep 10
reboot
