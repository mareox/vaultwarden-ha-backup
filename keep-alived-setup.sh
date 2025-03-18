#!/bin/bash
#
# keepalived-setup.sh - Interactive script for setting up Keepalived
#

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Keepalived configuration file path
KEEPALIVED_CONF="/etc/keepalived/keepalived.conf"
KEEPALIVED_CHECK_SCRIPT="/etc/keepalived/keepalived_check.sh"
KEEPALIVED_NOTIFY_SCRIPT="/etc/keepalived/keepalived_notify.sh"

# Log file
LOG_FILE="/tmp/keepalived-setup.log"

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

# Function to install keepalived if not already installed
install_keepalived() {
    log "Checking if keepalived is installed..." "INFO"
    
    if ! command -v keepalived &> /dev/null; then
        log "Keepalived not found. Installing..." "INFO"
        
        apt update || { log "Failed to update apt repositories" "ERROR"; return 1; }
        apt install -y keepalived libipset13 || { log "Failed to install keepalived" "ERROR"; return 1; }
        
        log "Keepalived installed successfully" "SUCCESS"
    else
        log "Keepalived is already installed" "INFO"
    fi
    
    return 0
}

# Function to detect the primary network interface
detect_interface() {
    # Try to detect the primary interface
    INTERFACES=($(ip -o -4 route show to default | awk '{print $5}'))
    
    if [ ${#INTERFACES[@]} -eq 0 ]; then
        log "No network interfaces with default route found. Please specify manually." "WARNING"
        read -p "Enter network interface name (e.g., eth0): " INTERFACE
    elif [ ${#INTERFACES[@]} -eq 1 ]; then
        INTERFACE="${INTERFACES[0]}"
        log "Detected network interface: $INTERFACE" "INFO"
        read -p "Use detected interface '$INTERFACE'? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter network interface name: " INTERFACE
        fi
    else
        log "Multiple interfaces detected, please select one:" "INFO"
        select INTERFACE in "${INTERFACES[@]}"; do
            if [ -n "$INTERFACE" ]; then
                break
            fi
        done
    fi
    
    # Validate the interface exists
    if ! ip link show "$INTERFACE" &> /dev/null; then
        log "Interface $INTERFACE does not exist" "ERROR"
        return 1
    fi
    
    log "Using network interface: $INTERFACE" "SUCCESS"
    return 0
}

# Function to create the check script
create_check_script() {
    log "Creating health check script" "INFO"
    
    mkdir -p "$(dirname "$KEEPALIVED_CHECK_SCRIPT")" || { log "Failed to create script directory" "ERROR"; return 1; }
    
    cat > "$KEEPALIVED_CHECK_SCRIPT" << 'EOF'
#!/bin/bash
# keepalived_check.sh - Health check script for keepalived

# Add your health check conditions here
# Example: Check if a critical service is running
# if ! systemctl is-active --quiet your-service; then
#     exit 1
# fi

# Return success by default
exit 0
EOF
    
    # Make it executable
    chmod +x "$KEEPALIVED_CHECK_SCRIPT" || { log "Failed to make script executable" "ERROR"; return 1; }
    
    log "Health check script created: $KEEPALIVED_CHECK_SCRIPT" "SUCCESS"
    return 0
}

# Function to create the notify script
create_notify_script() {
    log "Creating notify script" "INFO"
    
    mkdir -p "$(dirname "$KEEPALIVED_NOTIFY_SCRIPT")" || { log "Failed to create script directory" "ERROR"; return 1; }
    
    cat > "$KEEPALIVED_NOTIFY_SCRIPT" << 'EOF'
#!/bin/bash
# keepalived_notify.sh - Notification script for state changes

# Log to syslog
logger -t keepalived "Transition to state $1 for instance $2"

# Parameters passed to this script:
# $1 = "GROUP"|"INSTANCE"
# $2 = name of group or instance
# $3 = state of transition ("MASTER"|"BACKUP"|"FAULT")

# Example: Take action based on the new state
case $3 in
    "MASTER")
        logger -t keepalived "Node is now MASTER"
        # Add commands to execute when becoming master
        ;;
    "BACKUP")
        logger -t keepalived "Node is now BACKUP"
        # Add commands to execute when becoming backup
        ;;
    "FAULT")
        logger -t keepalived "Node is now in FAULT state"
        # Add commands to execute when entering fault state
        ;;
esac

exit 0
EOF
    
    # Make it executable
    chmod +x "$KEEPALIVED_NOTIFY_SCRIPT" || { log "Failed to make script executable" "ERROR"; return 1; }
    
    log "Notify script created: $KEEPALIVED_NOTIFY_SCRIPT" "SUCCESS"
    return 0
}

# Function to generate keepalived configuration
generate_config() {
    local state="$1"
    local interface="$2"
    local virtual_ip="$3"
    local local_ip="$4"
    local peer_ip="$5"
    local auth_pass="$6"
    local priority="$7"
    
    log "Generating keepalived configuration" "INFO"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$KEEPALIVED_CONF")" || { log "Failed to create config directory" "ERROR"; return 1; }
    
    # Create configuration file
    cat > "$KEEPALIVED_CONF" << EOF
vrrp_script keepalived_check {
      script "$KEEPALIVED_CHECK_SCRIPT"
      interval 5
      timeout 10
      rise 3
      fall 3
}

vrrp_instance VI_1 {
  state $state
  interface $interface
  virtual_router_id 55
  priority $priority
  advert_int 1
  unicast_src_ip $local_ip
  unicast_peer {
    $peer_ip
  }
  authentication {
    auth_type PASS
    auth_pass $auth_pass
  }
  virtual_ipaddress {
    $virtual_ip
  }
  track_script {
    keepalived_check
  }
  notify "$KEEPALIVED_NOTIFY_SCRIPT"
}
EOF
    
    if [ $? -ne 0 ]; then
        log "Failed to write configuration file" "ERROR"
        return 1
    fi
    
    log "Configuration generated successfully" "SUCCESS"
    return 0
}

# Function to restart keepalived service
restart_keepalived() {
    log "Restarting keepalived service" "INFO"
    
    systemctl restart keepalived || { log "Failed to restart keepalived" "ERROR"; return 1; }
    systemctl enable keepalived || { log "Failed to enable keepalived" "ERROR"; return 1; }
    
    # Check if service is running
    if systemctl is-active --quiet keepalived; then
        log "Keepalived service is running" "SUCCESS"
    else
        log "Keepalived service failed to start" "ERROR"
        return 1
    fi
    
    return 0
}

# Function to display summary
show_summary() {
    local state="$1"
    local interface="$2"
    local virtual_ip="$3"
    local local_ip="$4"
    local peer_ip="$5"
    local priority="$6"
    
    echo
    log "=== KEEPALIVED CONFIGURATION SUMMARY ===" "INFO"
    log "State: $state" "INFO"
    log "Priority: $priority" "INFO"
    log "Interface: $interface" "INFO"
    log "Virtual IP: $virtual_ip" "INFO"
    log "Local IP: $local_ip" "INFO"
    log "Peer IP: $peer_ip" "INFO"
    log "Configuration file: $KEEPALIVED_CONF" "INFO"
    log "Check script: $KEEPALIVED_CHECK_SCRIPT" "INFO"
    log "Notify script: $KEEPALIVED_NOTIFY_SCRIPT" "INFO"
    
    echo
    log "Keepalived service status: $(systemctl is-active keepalived)" "INFO"
    
    echo
    log "To check keepalived status: sudo systemctl status keepalived" "INFO"
    log "To view logs: sudo journalctl -u keepalived" "INFO"
    echo
}

# Main function
main() {
    # Clear log file
    > "$LOG_FILE"
    
    echo "===================================================="
    echo "           Keepalived Setup Script                  "
    echo "===================================================="
    echo
    log "Starting Keepalived setup script" "INFO"
    
    # Check if running as root
    check_root
    
    # Install keepalived if needed
    install_keepalived || exit 1
    
    # Detect network interface
    detect_interface || exit 1
    
    # Prompt for state
    echo
    echo "Please select the Keepalived state for this node:"
    echo "1) MASTER (priority 100)"
    echo "2) BACKUP (priority 150)"
    echo
    
    read -p "Enter your choice (1 or 2): " state_choice
    echo
    
    # Set state and priority based on choice
    if [ "$state_choice" = "1" ]; then
        STATE="MASTER"
        PRIORITY="100"
    elif [ "$state_choice" = "2" ]; then
        STATE="BACKUP"
        PRIORITY="150"
    else
        log "Invalid choice. Please select 1 or 2." "ERROR"
        exit 1
    fi
    
    log "Selected state: $STATE with priority $PRIORITY" "INFO"
    
    # Prompt for IP addresses
    read -p "Enter the virtual IP address (with CIDR, e.g., 192.168.1.100/24): " VIRTUAL_IP
    read -p "Enter this node's IP address: " LOCAL_IP
    read -p "Enter the peer node's IP address: " PEER_IP
    
    # Validate IP addresses (basic validation)
    if [[ ! $VIRTUAL_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        log "Invalid virtual IP address format" "ERROR"
        exit 1
    fi
    
    if [[ ! $LOCAL_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Invalid local IP address format" "ERROR"
        exit 1
    fi
    
    if [[ ! $PEER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Invalid peer IP address format" "ERROR"
        exit 1
    fi
    
    # Prompt for authentication password
    read -p "Enter authentication password (min 8 characters recommended): " AUTH_PASS
    
    if [ ${#AUTH_PASS} -lt 8 ]; then
        log "Warning: Short authentication passwords are not recommended" "WARNING"
        read -p "Use this password anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Setup aborted" "ERROR"
            exit 1
        fi
    fi
    
    # Create the check script
    create_check_script || exit 1
    
    # Create the notify script
    create_notify_script || exit 1
    
    # Generate keepalived configuration
    generate_config "$STATE" "$INTERFACE" "$VIRTUAL_IP" "$LOCAL_IP" "$PEER_IP" "$AUTH_PASS" "$PRIORITY" || exit 1
    
    # Restart keepalived service
    restart_keepalived || exit 1
    
    # Show summary
    show_summary "$STATE" "$INTERFACE" "$VIRTUAL_IP" "$LOCAL_IP" "$PEER_IP" "$PRIORITY"
    
    log "Keepalived setup completed successfully!" "SUCCESS"
}

# Run the main function
main
