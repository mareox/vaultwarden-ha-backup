# Vaultwarden Management System

This system provides automated backup and monitoring functionality for a Vaultwarden Docker container and its SQLite database.

## Components

The system consists of three main scripts:

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

## Installation

### Automated Setup (Recommended)

The easiest way to install the system is to use the provided setup script:

1. Download all the scripts to a temporary location:
   ```bash
   git clone https://github.com/mareox/vaultwarden-tools.git
   cd vaultwarden-tools
   ```

2. Run the setup script as root:
   ```bash
   sudo ./vaultwarden-setup.sh
   ```

3. Follow the interactive prompts to choose between:
   - **PRIMARY server**: Configured with scheduled backups at 3:00 AM and 5:00 PM daily.
   - **SECONDARY server**: No scheduled backups, only monitor-triggered backups.

The setup script will:
- Verify Docker and the Vaultwarden container are installed
- Install all scripts to `/etc/scripts/`
- Set appropriate permissions
- Configure cron jobs (for PRIMARY servers)
- Set up and start the monitor service
- Create required directories
- Provide a summary of the installation

### Manual Installation

If you prefer to install manually, follow these steps:

1. Place all scripts in the `/etc/scripts/` directory:
   ```bash
   sudo cp vw-bk-script-primary.sh /etc/scripts/
   sudo cp sq-db-backup.sh /etc/scripts/
   sudo cp vault-pri-monitor.sh /etc/scripts/
   ```

2. Set proper permissions:
   ```bash
   sudo chmod 700 /etc/scripts/vw-bk-script-primary.sh
   sudo chmod 700 /etc/scripts/sq-db-backup.sh
   sudo chmod 700 /etc/scripts/vault-pri-monitor.sh
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

Review these files to check for backup successes or failures and monitor status.

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

1. **Scheduled Backups**: The `vw-bk-script-primary.sh` performs regular scheduled backups via cron.

2. **Automated Monitoring**: The `vault-pri-monitor.sh` continuously monitors the vault server's availability.

3. **Failure Response**: If the monitor detects that the vault server is down after several consecutive checks, it automatically runs the backup script to preserve data.

4. **Database Backup Logic**: Both scripts utilize the core `sq-db-backup.sh` to perform the actual SQLite database backup operations.

This integrated approach provides both proactive scheduled backups and reactive backups in response to detected failures.

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
