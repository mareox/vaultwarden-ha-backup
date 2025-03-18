# Vaultwarden Backup System

This system provides automated backup functionality for a Vaultwarden Docker container and its SQLite database.

## Components

The backup system consists of two main scripts:

1. **vw-bk-script-primary.sh**: Main controller script that:
   - Stops the Vaultwarden Docker container
   - Executes the database backup script
   - Restarts the container
   - Handles errors and container restart failures
   - Reboots the host system if container restart fails repeatedly

2. **sq-db-backup.sh**: Database backup script that:
   - Creates backups of the SQLite database
   - Maintains a rotating set of backups (keeping the most recent 30)
   - Cleans up older backups automatically

## Installation

1. Place both scripts in the `/etc/scripts/` directory:
   ```bash
   sudo cp vw-bk-script-primary.sh /etc/scripts/
   sudo cp sq-db-backup.sh /etc/scripts/
   ```

2. Set proper permissions:
   ```bash
   sudo chmod 700 /etc/scripts/vw-bk-script-primary.sh
   sudo chmod 700 /etc/scripts/sq-db-backup.sh
   ```

## Execution

The script can be run manually:
```bash
sudo /etc/scripts/vw-bk-script-primary.sh
```

For scheduled execution, add it to root's crontab:
```bash
sudo crontab -e
```

Add a line like this to run it daily at 2 AM:
```
0 2 * * * /etc/scripts/vw-bk-script-primary.sh
```

## Logs

Logs are saved to:
```
/etc/scripts/sq-db-backup.sh.log
```

Review this file to check for backup successes or failures.

## Sudoers Configuration (Optional)

To allow a specific user to run the script with sudo without a password prompt:

1. Edit the sudoers file:
   ```bash
   sudo visudo -f /etc/sudoers.d/vw-backup
   ```

2. Add the following line (replace "username" with your actual username):
   ```
   username ALL=(ALL) NOPASSWD: /etc/scripts/vw-bk-script-primary.sh
   ```

## Backup Storage

Backups are stored in:
```
/mx-server/backups/BK_vaultwarden/
```

The system maintains the most recent 30 backups and automatically removes older ones.

## Warning

This script includes functionality to reboot the host system if the Vaultwarden container fails to restart after multiple attempts. Use with caution in production environments.

# Vault-pri-monitor.sh

## Overview
The Vault Server Heartbeat Monitor is a robust bash script designed to monitor the availability of a critical server named "vault" through periodic ping checks. If the server becomes unresponsive, the script automatically triggers a backup procedure to ensure data safety.

## Features
- **Periodic Monitoring**: Checks server availability every 4 hours
- **Thorough Validation**: Performs 10-second ping tests with up to 3 retry attempts per check
- **Failure Tolerance**: Requires 3 consecutive failed checks (over 12 hours) before declaring the server down
- **Automatic Recovery**: Executes a predefined backup script when downtime is detected
- **Comprehensive Logging**: Maintains detailed logs with timestamps and severity levels
- **Syslog Integration**: Sends alerts to system logs with appropriate priority levels based on severity

## Configuration Parameters
The script includes several configurable parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `HOSTNAME` | "vault" | The hostname to monitor |
| `CHECK_INTERVAL` | 14400 (4 hours) | Time between checks in seconds |
| `PING_DURATION` | 10 | Duration of each ping test in seconds |
| `MAX_RETRIES` | 3 | Maximum retry attempts per check |
| `FAILURE_THRESHOLD` | 3 | Number of consecutive failures before running backup |
| `BACKUP_SCRIPT` | "/etc/scripts/sq-db-backup.sh" | Path to the backup script |

## Installation

1. Save the script to a file (e.g., `/etc/scripts/vault-monitor.sh`)
2. Make it executable:
   ```
   chmod +x /etc/scripts/vault-monitor.sh
   ```
3. Set up as a service or add to startup scripts:
   ```
   # Example using systemd
   sudo cp vault-monitor.service /etc/systemd/system/
   sudo systemctl enable vault-monitor.service
   sudo systemctl start vault-monitor.service
   ```

## Logging
The script creates detailed logs in two locations:
- **Custom Log File**: `/var/log/vault-monitor.log`
- **System Logs**: Events are sent to syslog with appropriate severity levels

Log levels include:
- `INFO`: Normal operational messages
- `WARNING`: Potential issues like failed ping attempts
- `ERROR`: Script execution errors
- `CRITICAL`/`ALERT`: Server down notifications

## Example Log Output
```
[2025-03-17 10:00:00] [INFO] Starting vault server heartbeat monitor
[2025-03-17 10:00:00] [INFO] Checking vault every 4 hours
[2025-03-17 10:00:05] [INFO] Performing heartbeat check on vault
[2025-03-17 10:00:15] [INFO] Ping successful on attempt 1
[2025-03-17 10:00:15] [INFO] Heartbeat check PASSED
[2025-03-17 10:00:15] [INFO] Next check in 4 hours
```

## Customization
You can easily customize the monitoring parameters by editing the variables at the top of the script to match your specific requirements.

## Troubleshooting
If you encounter issues:
1. Verify the script has execute permissions
2. Check if the backup script path is correct and executable
3. Review logs in `/var/log/vault-monitor.log` for details
4. Ensure the monitored hostname is correctly configured

## Requirements
- Bash shell
- Standard Linux utilities (`ping`, `logger`)
- Appropriate permissions to write to log files and execute the backup script
