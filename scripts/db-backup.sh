#!/bin/bash
set -euo pipefail

# Script: db-backup.sh
# Purpose: Dump MySQL DB, compress it, rotate files older than 7 days
# Usage:   ./db-backup.sh [--db shopmonitor_db] [--retain 7]
# Cron:    0 2 * * * /opt/shopmonitor/scripts/db-backup.sh
# Requires: /etc/shopmonitor/.my.cnf with [client] user/password

DB_NAME="shopmonitor_db"
BACKUP_DIR="/var/backups/shopmonitor/mysql"
RETAIN_DAYS=7
MY_CNF="/etc/shopmonitor/.my.cnf"
LOG_DIR="/var/log/shopmonitor"
LOG_FILE="$LOG_DIR/db-backup.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)      DB_NAME="$2";      shift 2 ;;
    --retain)  RETAIN_DAYS="$2";  shift 2 ;;
    --help)
      echo "Usage: $0 [--db <name>] [--retain <days>]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log() {
  local level="$1"; shift
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
  mkdir -p "$LOG_DIR"
  echo "$msg" >> "$LOG_FILE"
  echo "$msg"
}

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

log INFO "=== DB backup starting: $DB_NAME ==="
mkdir -p "$BACKUP_DIR"

# --- Dump and compress ---
DEFAULTS_ARG=""
if [[ -f "$MY_CNF" ]]; then
  DEFAULTS_ARG="--defaults-extra-file=$MY_CNF"
  log INFO "Using credentials from $MY_CNF"
else
  log WARN ".my.cnf not found at $MY_CNF — relying on environment credentials"
fi

if mysqldump $DEFAULTS_ARG \
    --single-transaction \
    --routines \
    --triggers \
    "$DB_NAME" | gzip > "$BACKUP_FILE"; then
  FILESIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
  log INFO "Backup created: $BACKUP_FILE ($FILESIZE)"
else
  log ERROR "mysqldump FAILED for $DB_NAME"
  exit 1
fi

# --- Rotate old backups ---
DELETED=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"$RETAIN_DAYS" -print)
if [[ -n "$DELETED" ]]; then
  echo "$DELETED" | while read -r f; do
    rm -f "$f"
    log INFO "Deleted old backup: $f"
  done
else
  log INFO "No backups older than $RETAIN_DAYS days to remove"
fi

# --- Summary ---
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" | wc -l)
log INFO "Backup complete. Total backups retained: $BACKUP_COUNT"
log INFO "=== DB backup finished ==="
