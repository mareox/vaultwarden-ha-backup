# Function to download scripts for remote installation
download_scripts() {
    local base_url="https://raw.githubusercontent.com/mareox/vaultwarden-ha-backup/refs/heads/main"
    local temp_dir="$HOME/vaultwarden-temp"
    
    log "Remote installation mode detected" "INFO"
    log "Creating temporary directory: $temp_dir" "INFO"
    
    # Create temp directory
    mkdir -p "$temp_dir" || { log "Failed to create temporary directory" "ERROR"; return 1; }
    
    # Download required scripts
    log "Downloading scripts from GitHub..." "INFO"
    
    curl -s "$base_url/vw-bk-script-primary.sh" -o "$temp_dir/vw-bk-script-primary.sh" || { log "Failed to download primary script" "ERROR"; return 1; }
    curl -s "$base_url/sq-db-backup.sh" -o "$temp_dir/sq-db-backup.sh" || { log "Failed to download backup script" "ERROR"; return 1; }
    curl -s "$base_url/vault-pri-monitor.sh" -o "$temp_dir/vault-pri-monitor.sh" || { log "Failed to download monitor script" "ERROR"; return 1; }
    curl -s "$base_url/keepalived-setup.sh" -o "$temp_dir/keepalived-setup.sh" || { log "Failed to download keepalived setup script" "WARNING"; }
    
    # Set script directory to the temporary directory
    SCRIPT_DIR="$temp_dir"
    
    log "Scripts downloaded successfully to $temp_dir" "SUCCESS"
    return 0
}#!/bin/bash
#
# vaultwarden-setup.sh - Interactive setup script for Vaultwarden management system
#

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define script paths
SCRIPTS_DIR="/etc/scripts"
PRIMARY_SCRIPT="${SCRIPTS_DIR}/vw-bk-script-primary.sh"
BACKUP_SCRIPT="${SCRIPTS_DIR}/sq-db-backup.sh"
MONITOR_SCRIPT="${SCRIPTS_DIR}/vault-pri-monitor.sh"
SYSTEMD_SERVICE="/etc/systemd/system/vault-monitor.service"

# Log file
LOG_FILE="$HOME/vaultwarden-setup.log"

# Remote installation mode flag
REMOTE_INSTALL=false

# Function for logging
log() {
    local message="$1"
    local level="$2"
    local color="${NC}"
    
    # Set color based on level
    case "$level" in
        "ERROR")
            color="${RED}"
            ;;
        "SUCCESS")
            color="${GREEN}"
            ;;
        "WARNING")
            color="${YELLOW}"
            ;;
        "INFO")
            color="${BLUE}"
            ;;
    esac
    
    # Print to console with color
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
    
    # Log to file without color codes
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "This script must be run as root" "ERROR"
        exit 1
    fi
}

# Function to create directory if it doesn't exist
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log "Creating directory: $dir" "INFO"
        mkdir -p "$dir" || { log "Failed to create directory: $dir" "ERROR"; return 1; }
    else
        log "Directory already exists: $dir" "INFO"
    fi
    return 0
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log "Docker is not installed. Please install Docker first." "ERROR"
        return 1
    fi
    
    # Check if docker is running
    if ! docker info &> /dev/null; then
        log "Docker daemon is not running. Please start Docker service." "ERROR"
        return 1
    fi
    
    log "Docker is installed and running" "SUCCESS"
    return 0
}

# Function to check if vaultwarden container exists
check_vaultwarden() {
    if ! docker ps -a | grep -q "vaultwarden"; then
        log "Vaultwarden container not found. Please ensure the container is named 'vaultwarden'." "WARNING"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        log "Vaultwarden container found" "SUCCESS"
    fi
    return 0
}

# Function to install the scripts
install_scripts() {
    log "Installing scripts to $SCRIPTS_DIR" "INFO"
    
    # Create scripts directory
    create_directory "$SCRIPTS_DIR" || return 1
    
    # Copy scripts to the directory
    for SCRIPT_FILE in $(find "$SCRIPT_DIR" -name "*.sh" -type f); do
        SCRIPT_NAME=$(basename "$SCRIPT_FILE")
        
        # Determine the target name based on the script type
        if [[ "$SCRIPT_NAME" == *"bk"*"script"* || "$SCRIPT_NAME" == *"backup"* ]] && [[ "$SCRIPT_NAME" != *"db"* && "$SCRIPT_NAME" != *"sq"* ]]; then
            # This is likely the primary backup script
            cp "$SCRIPT_FILE" "$PRIMARY_SCRIPT" || { log "Failed to copy primary script" "ERROR"; return 1; }
            log "Installed primary script: $SCRIPT_NAME → $(basename "$PRIMARY_SCRIPT")" "INFO"
        elif [[ "$SCRIPT_NAME" == *"db"* || "$SCRIPT_NAME" == *"sqlite"* ]]; then
            # This is likely the database backup script
            cp "$SCRIPT_FILE" "$BACKUP_SCRIPT" || { log "Failed to copy backup script" "ERROR"; return 1; }
            log "Installed database script: $SCRIPT_NAME → $(basename "$BACKUP_SCRIPT")" "INFO"
        elif [[ "$SCRIPT_NAME" == *"monitor"* ]]; then
            # This is likely the monitor script
            cp "$SCRIPT_FILE" "$MONITOR_SCRIPT" || { log "Failed to copy monitor script" "ERROR"; return 1; }
            log "Installed monitor script: $SCRIPT_NAME → $(basename "$MONITOR_SCRIPT")" "INFO"
        elif [[ "$SCRIPT_NAME" == *"keepalived"* ]]; then
            # This is likely the keepalived setup script
            cp "$SCRIPT_FILE" "$SCRIPTS_DIR/keepalived-setup.sh" || { log "Failed to copy keepalived setup script" "WARNING"; }
            log "Installed keepalived script: $SCRIPT_NAME → keepalived-setup.sh" "INFO"
        fi
    done
    
    # Set executable permissions on all scripts in the scripts directory
    chmod 700 "$SCRIPTS_DIR"/*.sh || { log "Failed to set permissions on scripts" "ERROR"; return 1; }
    
    log "Scripts installed successfully" "SUCCESS"
    return 0
}

# Function to create backup directory
setup_backup_dir() {
    local backup_dir="/mx-server/backups/BK_vaultwarden"
    create_directory "$backup_dir" || return 1
    log "Backup directory created/verified: $backup_dir" "SUCCESS"
    return 0
}

# Function to set up primary server configuration
setup_primary() {
    log "Setting up PRIMARY server configuration" "INFO"
    
    # Create cron jobs for scheduled backups
    log "Setting up cron jobs for 3:00 AM and 5:00 PM" "INFO"
    (crontab -l 2>/dev/null | grep -v "$PRIMARY_SCRIPT"; echo "0 3 * * * $PRIMARY_SCRIPT") | crontab -
    (crontab -l 2>/dev/null | grep -v "$PRIMARY_SCRIPT"; echo "0 17 * * * $PRIMARY_SCRIPT") | crontab -
    
    if [ $? -ne 0 ]; then
        log "Failed to set up cron jobs" "ERROR"
        return 1
    fi
    
    log "Cron jobs set up successfully" "SUCCESS"
    
    # Set up monitor service
    setup_monitor_service || return 1
    
    log "PRIMARY server setup completed successfully" "SUCCESS"
    return 0
}

# Function to set up secondary server configuration
setup_secondary() {
    log "Setting up SECONDARY server configuration" "INFO"
    
    # Set up monitor service only (no scheduled backups)
    setup_monitor_service || return 1
    
    log "SECONDARY server setup completed successfully" "SUCCESS"
    return 0
}

# Function to set up the monitor service
setup_monitor_service() {
    log "Setting up monitor service" "INFO"
    
    # Create systemd service file
    cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=Vaultwarden Server Monitor
After=network.target

[Service]
Type=simple
ExecStart=$MONITOR_SCRIPT
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    if [ $? -ne 0 ]; then
        log "Failed to create systemd service file" "ERROR"
        return 1
    fi
    
    # Reload systemd, enable and start the service
    systemctl daemon-reload || { log "Failed to reload systemd" "ERROR"; return 1; }
    systemctl enable vault-monitor || { log "Failed to enable vault-monitor service" "ERROR"; return 1; }
    systemctl start vault-monitor || { log "Failed to start vault-monitor service" "ERROR"; return 1; }
    
    # Check if service is running
    if systemctl is-active --quiet vault-monitor; then
        log "Monitor service is running" "SUCCESS"
    else
        log "Monitor service failed to start" "ERROR"
        return 1
    fi
    
    return 0
}

# Function to check if keepalived is installed
check_keepalived() {
    if command -v keepalived &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to setup keepalived
setup_keepalived() {
    log "Setting up Keepalived" "INFO"
    
    # Check if keepalived-setup.sh exists in the scripts directory
    if [ -f "$SCRIPTS_DIR/keepalived-setup.sh" ]; then
        # Make it executable (just to be sure)
        chmod +x "$SCRIPTS_DIR/keepalived-setup.sh"
        
        # Run the script
        "$SCRIPTS_DIR/keepalived-setup.sh"
        
        if [ $? -eq 0 ]; then
            log "Keepalived setup completed successfully" "SUCCESS"
            return 0
        else
            log "Keepalived setup failed" "ERROR"
            return 1
        fi
    else
        log "Keepalived setup script not found in $SCRIPTS_DIR" "ERROR"
        log "Please download it from: https://github.com/mareox/vaultwarden-ha-backup" "INFO"
        return 1
    fi
}

# Function to display summary
show_summary() {
    local server_type="$1"
    local keepalived_installed="$2"
    
    echo
    log "=== INSTALLATION SUMMARY ===" "INFO"
    log "Server type: $server_type" "INFO"
    log "Scripts installed in: $SCRIPTS_DIR" "INFO"
    log "Log file: $LOG_FILE" "INFO"
    
    if [ "$server_type" = "PRIMARY" ]; then
        log "Scheduled backups: 3:00 AM and 5:00 PM daily" "INFO"
    else
        log "No scheduled backups (triggered by monitor only)" "INFO"
    fi
    
    log "Monitor service: Enabled and running" "INFO"
    log "Monitor service status: $(systemctl is-active vault-monitor)" "INFO"
    
    if [ "$keepalived_installed" = "true" ]; then
        log "Keepalived: Installed and configured" "INFO"
        log "Keepalived service status: $(systemctl is-active keepalived)" "INFO"
    else
        log "Keepalived: Not installed" "INFO"
    fi
    
    echo
    log "To check monitor logs: sudo journalctl -u vault-monitor" "INFO"
    log "To check backup logs: cat /etc/scripts/sq-db-backup.sh.log" "INFO"
    if [ "$keepalived_installed" = "true" ]; then
        log "To check keepalived logs: sudo journalctl -u keepalived" "INFO"
    fi
    echo
}

# Function to check for required script files
check_script_files() {
    log "Checking for required script files..." "INFO"
    
    if [ "$REMOTE_INSTALL" = true ]; then
        download_scripts || return 1
    else
        SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
        log "Script directory is: $SCRIPT_DIR" "INFO"
    fi
    
    # List all script files
    SCRIPT_FILES=$(find "$SCRIPT_DIR" -name "*.sh" -type f 2>/dev/null | sort)
    if [ -z "$SCRIPT_FILES" ]; then
        log "No script files found in $SCRIPT_DIR" "ERROR"
        log "Please make sure you are running this script from the directory containing all the required scripts" "ERROR"
        return 1
    fi
    
    log "Found the following script files:" "INFO"
    for file in $SCRIPT_FILES; do
        log "- $(basename "$file")" "INFO"
    done
    
    # Check for each required script type
    if ! find "$SCRIPT_DIR" -name "*bk*script*.sh" -o -name "*backup*.sh" -type f 2>/dev/null | grep -q .; then
        log "Missing backup script file" "ERROR"
        return 1
    fi
    
    if ! find "$SCRIPT_DIR" -name "*db*.sh" -o -name "*sqlite*.sh" -type f 2>/dev/null | grep -q .; then
        log "Missing database script file" "ERROR"
        return 1
    fi
    
    if ! find "$SCRIPT_DIR" -name "*monitor*.sh" -type f 2>/dev/null | grep -q .; then
        log "Missing monitor script file" "ERROR"
        return 1
    fi
    
    log "All required script types found" "SUCCESS"
    return 0
}

# Main function
main() {
    # Clear log file
    > "$LOG_FILE"
    
    echo "===================================================="
    echo "    Vaultwarden Management System Setup Script      "
    echo "===================================================="
    echo
    log "Starting setup script" "INFO"
    
    # Check if running as root
    check_root
    
    # Check for required script files
    check_script_files || {
        log "Setup aborted: Required script files are missing" "ERROR"
        echo
        echo "Please ensure all required script files are in the same directory as this setup script."
        echo "Required files should include:"
        echo "- Backup script (e.g., vw-bk-script-primary.sh or similar)"
        echo "- Database script (e.g., sq-db-backup.sh or similar)"
        echo "- Monitor script (e.g., vault-pri-monitor.sh or similar)"
        echo "- Keepalived setup script (e.g., keepalived-setup.sh) (optional)"
        echo
        exit 1
    }
    
    # Check prerequisites
    check_docker || exit 1
    check_vaultwarden || exit 1
    
    # Prompt for server type
    echo
    echo "Please select the server type to configure:"
    echo "1) PRIMARY server (scheduled backups at 3:00 AM and 5:00 PM)"
    echo "2) SECONDARY server (backups triggered by monitor only)"
    echo
    
    read -p "Enter your choice (1 or 2): " server_choice
    echo
    
    # Validate choice
    if [ "$server_choice" != "1" ] && [ "$server_choice" != "2" ]; then
        log "Invalid choice. Please select 1 or 2." "ERROR"
        exit 1
    fi
    
    # Install scripts
    install_scripts || exit 1
    
    # Set up backup directory
    setup_backup_dir || exit 1
    
    # Configure based on choice
    if [ "$server_choice" = "1" ]; then
        setup_primary || exit 1
        SELECTED_SERVER_TYPE="PRIMARY"
    else
        setup_secondary || exit 1
        SELECTED_SERVER_TYPE="SECONDARY"
    fi
    
    # Check if keepalived is already installed
    KEEPALIVED_INSTALLED="false"
    if check_keepalived; then
        log "Keepalived is already installed on this system" "INFO"
        read -p "Would you like to reconfigure Keepalived? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_keepalived
            if [ $? -eq 0 ]; then
                KEEPALIVED_INSTALLED="true"
            fi
        else
            KEEPALIVED_INSTALLED="true"
        fi
    else
        # Ask if user wants to install keepalived
        read -p "Would you like to install and configure Keepalived for high availability? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_keepalived
            if [ $? -eq 0 ]; then
                KEEPALIVED_INSTALLED="true"
            fi
        fi
    fi
    
    # Show installation summary
    show_summary "$SELECTED_SERVER_TYPE" "$KEEPALIVED_INSTALLED"
    
    log "Setup completed successfully!" "SUCCESS"
    echo
    echo "For more information, refer to the README.md file."
    echo "If you encounter any issues, please check the log file: $LOG_FILE"
    echo
}

# Run the main function
main
