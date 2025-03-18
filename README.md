## High Availability Setup

The Keepalived setup provides high availability for your Vaultwarden instance through the following mechanism:

1. Two servers are configured: one as MASTER (priority 100) and one as BACKUP (priority 150).
2. Both servers run the Vaultwarden container independently.
3. A virtual IP address is shared between them, which automatically moves to the active server.
4. If the MASTER server fails, the BACKUP server takes over the virtual IP address.
5. Clients connect to the virtual IP address, so the failover is transparent to them.

### Prerequisites for High Availability

1. Two servers with Vaultwarden installed.
2. Network infrastructure that allows for a shared virtual IP.
3. Both servers must be able to communicate with each other.

### Keepalived Configuration

The `keepalived-setup.sh` script automates the configuration of Keepalived with:

- Health check script to monitor the local system
- Notification script for state transitions
- Virtual IP configuration
- Authentication between nodes

### Testing Failover

To test that high availability is working properly:

1. Verify that the virtual IP is active on the MASTER node:
   ```bash
   ip addr show
   ```

2. Simulate a failure by stopping Keepalived on the MASTER node:
   ```bash
   sudo systemctl stop keepalived
   ```

3. Verify that the virtual IP has moved to the BACKUP node:
   ```bash
   # On the BACKUP node
   ip addr show
   ```

4. Restart Keepalived on the MASTER node:
   ```bash
   sudo systemctl start keepalived
   ```

5. Verify that the virtual IP moves back to the MASTER node (after a brief delay).## System Architecture

The Vaultwarden Management System can be deployed in different configurations:

### Single Server Deployment
- A single server running Vaultwarden with backup and monitoring capabilities.

### High Availability Deployment
- **PRIMARY Server**: Runs Vaultwarden with scheduled backups and monitoring.
- **BACKUP Server**: Standby server that takes over if the PRIMARY fails.
- **Virtual IP**: Floating IP address that automatically follows the active server.

With the high availability setup, if the PRIMARY server fails, the BACKUP server automatically takes over the Virtual IP and continues to serve the Vaultwarden application with minimal downtime.# Vaultwarden Management System

This system provides automated backup, monitoring, and high availability functionality for a Vaultwarden Docker container and its SQLite database.

## Components

The system consists of the following scripts:

1. **vw-bk-script-primary.sh**: Main backup controller script that:
   - Stops the Vaultwarden Docker container
   - Executes the database backup script
   - Restarts the container
   - Handles errors and container restart failures
   - Reboots the host system if container restart fails repeatedly

2. **sq-db-backup.sh**: Database backup script that:
   - Creates backups of the SQLite database
   - Maintains a rotating set of backups (keeping the most recent 30)
   - Cleans up older backups automatically

3. **vault-pri-monitor.sh**: Heartbeat monitoring script that:
   - Periodically checks if the vault server is responding
   - Logs the status of the checks
   - Triggers the backup script after consecutive failures
   - Provides syslog integration for alerting

4. **keepalived-setup.sh**: High availability setup script that:
   - Configures Keepalived for automatic failover between PRIMARY and BACKUP servers
   - Sets up virtual IP functionality
   - Creates health check and notification scripts
   - Provides a simple way to create a highly available Vaultwarden deployment

## Installation

### Automated Setup (Recommended)

The easiest way to install the system is to use the provided setup script:

1. Download all the scripts to a temporary location:
   ```bash
   git clone https://github.com/mareox/vaultwarden-ha-backup.git
   cd vaultwarden-ha-backup
   ```

2. Run the setup script as root:
   ```bash
   sudo ./setup.sh
   ```

3. Follow the interactive prompts to choose between:
   - **PRIMARY server**: Configured with scheduled backups at 3:00 AM and 5:00 PM daily.
   - **SECONDARY server**: No scheduled backups, only monitor-triggered backups.

4. The script will also ask if you want to configure Keepalived for high availability:
   - If you select yes, it will run the Keepalived setup script
   - You'll be prompted to choose MASTER or BACKUP role
   - You'll need to provide the local IP, peer IP, virtual IP, and authentication password

The setup script will:
- Verify Docker and the Vaultwarden container are installed
- Install all scripts to `/etc/scripts/`
- Set appropriate permissions
- Configure cron jobs (for PRIMARY servers)
- Set up and start the monitor service
- Create required directories
- Optionally set up Keepalived for high availability
- Provide a summary of the installation

### Manual Installation

If you prefer to install manually, follow these steps:

1. Place all scripts in the `/etc/scripts/` directory:
   ```bash
   sudo cp vw-bk-script-primary.sh /etc/scripts/
   sudo cp sq-db-backup.sh /etc/scripts/
   sudo cp vault-pri-monitor.sh /etc/scripts/
   sudo cp keepalived-setup.sh /etc/scripts/  # Optional for high availability
   ```

2. Set proper permissions:
   ```bash
   sudo chmod 700 /etc/scripts/vw-bk-script-primary.sh
   sudo chmod 700 /etc/scripts/sq-db-backup.sh
   sudo chmod 700 /etc/scripts/vault-pri-monitor.sh
   sudo chmod 700 /etc/scripts/keepalived-setup.sh  # Optional for high availability
   ```

3. Create the backup directory:
   ```bash
   sudo mkdir -p /mx-server/backups/BK_vaultwarden
   ```

4. Set up cron jobs (PRIMARY server only):
   ```bash
   (crontab -l 2>/dev/null; echo "0 3 * * * /etc/scripts/vw-bk-script-primary.sh") | crontab -
   (crontab -l 2>/dev/null; echo "0 17 * * * /etc/scripts/vw-bk-script-primary.sh") | crontab -
   ```

5. Create and configure the monitor service:
   ```bash
   sudo nano /etc/systemd/system/vault-monitor.service
   # Add the service configuration as shown in the Execution section
   sudo systemctl daemon-reload
   sudo systemctl enable vault-monitor
   sudo systemctl start vault-monitor
   ```

6. (Optional) Set up Keepalived for high availability:
   ```bash
   sudo /etc/scripts/keepalived-setup.sh
   # Follow the prompts to configure Keepalived
   ```

## Execution

### Backup Script

The backup script can be run manually:
```bash
sudo /etc/scripts/vw-bk-script-primary.sh
```

For PRIMARY servers, backups are scheduled at 3:00 AM and 5:00 PM daily via cron.

### Monitor Script

The monitoring script runs as a systemd service, which is configured automatically by the setup script.

To manually manage the service:

```bash
# Check status
sudo systemctl status vault-monitor

# Stop service
sudo systemctl stop vault-monitor

# Start service
sudo systemctl start vault-monitor

# Restart service
sudo systemctl restart vault-monitor

# View logs
sudo journalctl -u vault-monitor
```

### Keepalived (High Availability)

If you've set up Keepalived for high availability, you can manage it with:

```bash
# Check status
sudo systemctl status keepalived

# Stop service
sudo systemctl stop keepalived

# Start service
sudo systemctl start keepalived

# Restart service
sudo systemctl restart keepalived

# View logs
sudo journalctl -u keepalived
```

To check which node is currently the MASTER (active node):
```bash
ip addr show
```
Look for the virtual IP address in the output.

## Logs

### Backup Logs
Backup logs are saved to:
```
/etc/scripts/sq-db-backup.sh.log
```

### Monitor Logs
Monitor logs are saved to:
```
/var/log/vault-monitor.log
```

Additionally, the monitoring script sends log messages to syslog with different priority levels based on the severity of events.

### Keepalived Logs
Keepalived logs are sent to the system journal:
```
sudo journalctl -u keepalived
```

Review these files to check for backup successes or failures, monitor status, and Keepalived state changes.

## Sudoers Configuration (Optional)

To allow a specific user to run the scripts with sudo without a password prompt:

1. Edit the sudoers file:
   ```bash
   sudo visudo -f /etc/sudoers.d/vw-backup
   ```

2. Add the following lines (replace "username" with your actual username):
   ```
   username ALL=(ALL) NOPASSWD: /etc/scripts/vw-bk-script-primary.sh
   username ALL=(ALL) NOPASSWD: /etc/scripts/vault-pri-monitor.sh
   ```

## Backup Storage

Backups are stored in:
```
/mx-server/backups/BK_vaultwarden/
```

The system maintains the most recent 30 backups and automatically removes older ones.

## System Integration

This is how the different scripts work together:

1. **Scheduled Backups**: The `vw-bk-script-primary.sh` performs regular scheduled backups via cron on the PRIMARY server.

2. **Automated Monitoring**: The `vault-pri-monitor.sh` continuously monitors the vault server's availability on both PRIMARY and SECONDARY servers.

3. **Failure Response**: If the monitor detects that the vault server is down after several consecutive checks, it automatically runs the backup script to preserve data.

4. **Database Backup Logic**: Both scripts utilize the core `sq-db-backup.sh` to perform the actual SQLite database backup operations.

5. **High Availability**: The `keepalived` service manages the virtual IP address, automatically moving it to the healthy server if the active one fails.

This integrated approach provides:
- Proactive scheduled backups
- Reactive backups in response to detected failures
- Automatic failover between servers
- Minimized downtime for end users

## Configuration

### Monitor Script Configuration

The monitor script has several configurable parameters at the top of the file:

```bash
# Configuration
HOSTNAME="vault"             # Hostname to monitor
CHECK_INTERVAL=14400         # 4 hours in seconds
PING_DURATION=10             # Duration to ping in seconds
MAX_RETRIES=3                # Max retries per check
FAILURE_THRESHOLD=3          # Number of consecutive failures before marked down
BACKUP_SCRIPT="/etc/scripts/sq-db-backup.sh"  # Path to backup script
```

You may adjust these values to match your specific needs, such as changing the check interval or failure threshold.

## Warnings

- **Reboot Function**: The backup script includes functionality to reboot the host system if the Vaultwarden container fails to restart after multiple attempts. Use with caution in production environments.

- **Resource Usage**: The monitor script runs continuously and performs periodic ping checks. While the resource usage is minimal, be aware that it's constantly running on your system.
