# Vaultwarden Backup System (vw-bk-script.sh)

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

# Vaultwarden SQLite Database Backup Tool

A bash script for automating backups of Vaultwarden SQLite databases.

## Overview

`sq-db-backup.sh` is a utility script designed to create and manage automated backups of a Vaultwarden (self-hosted Bitwarden) SQLite database. This script handles backup rotation, compression, and can be easily integrated with cron for scheduled execution.

## Features

- Creates timestamped SQLite database backups
- Compresses backups to save storage space
- Implements backup rotation to manage storage usage
- Supports optional encryption of backups
- Includes logging for monitoring backup operations
- Configurable retention policies

## Prerequisites

- Bash shell environment
- SQLite3 command-line tools
- A running Vaultwarden instance with SQLite database
- (Optional) GPG for backup encryption

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mareox/vaultwarden-tools.git
   cd vaultwarden-tools
   ```

2. Make the script executable:
   ```bash
   chmod +x sq-db-backup.sh
   ```

## Configuration

Before using the script, edit the configuration variables at the top of the file:

```bash
# Database path
DB_PATH="/path/to/vaultwarden/db.sqlite3"

# Backup directory
BACKUP_DIR="/path/to/backup/directory"

# Number of backups to retain
BACKUP_RETENTION=7

# Logging options
LOG_FILE="/path/to/backup.log"
ENABLE_LOGGING=true
```

## Usage

### Manual Execution

Run the script manually:

```bash
./sq-db-backup.sh
```

### Scheduled Backups with Cron

Set up a daily backup schedule using cron:

1. Edit your crontab:
   ```bash
   crontab -e
   ```

2. Add a line to run the backup script daily (e.g., at 2:00 AM):
   ```
   0 2 * * * /path/to/sq-db-backup.sh
   ```

## Backup Files

Backups are created with the following naming convention:

```
vaultwarden-backup-YYYY-MM-DD-HHMMSS.sqlite3.gz
```

## Restore Procedure

To restore from a backup:

1. Decompress the backup file:
   ```bash
   gunzip vaultwarden-backup-YYYY-MM-DD-HHMMSS.sqlite3.gz
   ```

2. Stop the Vaultwarden service:
   ```bash
   systemctl stop vaultwarden
   ```

3. Replace the existing database with the backup:
   ```bash
   cp vaultwarden-backup-YYYY-MM-DD-HHMMSS.sqlite3 /path/to/vaultwarden/db.sqlite3
   ```

4. Set proper permissions:
   ```bash
   chown vaultwarden:vaultwarden /path/to/vaultwarden/db.sqlite3
   ```

5. Restart Vaultwarden:
   ```bash
   systemctl start vaultwarden
   ```

## Troubleshooting

- Check the log file for error messages
- Ensure the script has permission to access the database file
- Verify the backup directory exists and is writable

## Security Considerations

- Store backups in a secure location
- Consider enabling backup encryption if sensitive data is stored
- Regularly test the restore procedure

## License

This project is licensed under the MIT License - see the repository for details.

## Acknowledgments

- Vaultwarden project: https://github.com/dani-garcia/vaultwarden
- Contributors to the vaultwarden-tools repository

## Support

For issues, questions, or contributions, please open an issue on the [GitHub repository](https://github.com/mareox/vaultwarden-tools).
