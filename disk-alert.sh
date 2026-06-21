#!/bin/bash
set -euo pipefail

# Script: disk-alert.sh
# Purpose: Check disk usage on / and log a warning if it exceeds threshold
# Usage:   ./disk-alert.sh [--threshold 80]
# Cron:    0 * * * * /opt/shopmonitor/scripts/disk-alert.sh

THRESHOLD=80
LOG_DIR="/var/log/shopmonitor"
LOG_FILE="$LOG_DIR/disk.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --help)
      echo "Usage: $0 [--threshold <percent>]"
      echo "  --threshold  Alert threshold (default: 80)"
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

USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

log INFO "Disk check: / is at ${USAGE}% (threshold: ${THRESHOLD}%)"

if [[ "$USAGE" -gt "$THRESHOLD" ]]; then
  log WARN "ALERT: Disk usage on / is ${USAGE}% — exceeds threshold of ${THRESHOLD}%"
  log WARN "Top 10 largest directories in /var:"
  du -sh /var/* 2>/dev/null | sort -rh | head -10 | while read -r line; do
    log WARN "  $line"
  done
  exit 1
fi

exit 0
