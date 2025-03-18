#!/bin/bash

# Configuration
HOSTNAME="vault"
CHECK_INTERVAL=14400  # 4 hours in seconds
PING_DURATION=10      # Duration to ping in seconds
MAX_RETRIES=3         # Max retries per check
FAILURE_THRESHOLD=3   # Number of consecutive failures before marked down
BACKUP_SCRIPT="/etc/scripts/sq-db-backup.sh"

# Logging function
log() {
    local message="$1"
    local level="$2"
    
    # Default to INFO level if not specified
    if [ -z "$level" ]; then
        level="INFO"
    fi
    
    # Log to file and stdout
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> /var/log/vault-monitor.log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    
    # Send to syslog based on level
    case "$level" in
        "ERROR"|"ALERT"|"CRITICAL")
            logger -p daemon.err "vault-monitor: $message"
            ;;
        "WARNING")
            logger -p daemon.warning "vault-monitor: $message"
            ;;
        *)
            logger -p daemon.info "vault-monitor: $message"
            ;;
    esac
}

# Initialize counter
consecutive_failures=0

log "Starting vault server heartbeat monitor" "INFO"
log "Checking $HOSTNAME every $(($CHECK_INTERVAL/3600)) hours" "INFO"

while true; do
    log "Performing heartbeat check on $HOSTNAME"
    
    # Try up to MAX_RETRIES times
    is_up=false
    for ((retry=1; retry<=MAX_RETRIES; retry++)); do
        if ping -c $PING_DURATION $HOSTNAME > /dev/null 2>&1; then
            is_up=true
            log "Ping successful on attempt $retry" "INFO"
            break
        else
            log "Ping attempt $retry failed" "WARNING"
            # Small delay between retries
            sleep 5
        fi
    done
    
    if $is_up; then
        # Reset failure counter on success
        consecutive_failures=0
        log "Heartbeat check PASSED" "INFO"
    else
        # Increment failure counter
        consecutive_failures=$((consecutive_failures + 1))
        log "Heartbeat check FAILED ($consecutive_failures/$FAILURE_THRESHOLD consecutive failures)" "WARNING"
        
        # Check if we've reached the failure threshold
        if [ $consecutive_failures -ge $FAILURE_THRESHOLD ]; then
            log "ALERT: $HOSTNAME is DOWN after $FAILURE_THRESHOLD consecutive failed checks" "CRITICAL"
            log "Running backup script: $BACKUP_SCRIPT" "ALERT"
            
            # Execute the backup script
            if [ -x "$BACKUP_SCRIPT" ]; then
                $BACKUP_SCRIPT
                backup_result=$?
                
                if [ $backup_result -eq 0 ]; then
                    log "Backup script executed successfully" "INFO"
                else
                    log "ERROR: Backup script failed with exit code $backup_result" "ERROR"
                fi
            else
                log "ERROR: Backup script not found or not executable: $BACKUP_SCRIPT" "ERROR"
            fi
            
            # Reset counter after taking action
            consecutive_failures=0
        fi
    fi
    
    # Wait for the next check interval
    log "Next check in $(($CHECK_INTERVAL/3600)) hours" "INFO"
    sleep $CHECK_INTERVAL
done
