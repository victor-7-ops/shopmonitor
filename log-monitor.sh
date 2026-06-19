#!/bin/bash
set -euo pipefail

# Script: log-monitor.sh
# Purpose: Parse nginx error.log and mail.log; print error summary
# Usage:   ./log-monitor.sh [--since "1 hour ago"] [--recipient email]
# Cron:    0 6 * * * /opt/shopmonitor/scripts/log-monitor.sh

SINCE="1 hour ago"
NGINX_ERROR_LOG="/var/log/nginx/error.log"
MAIL_LOG="/var/log/mail.log"
LOG_DIR="/var/log/shopmonitor"
LOG_FILE="$LOG_DIR/log-monitor.log"
RECIPIENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)     SINCE="$2";     shift 2 ;;
    --recipient) RECIPIENT="$2"; shift 2 ;;
    --help)
      echo "Usage: $0 [--since '1 hour ago'] [--recipient email@example.com]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log() {
  local level="$1"; shift
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
  mkdir -p "$LOG_DIR"
  echo "$msg" | tee -a "$LOG_FILE"
}

SINCE_TS=$(date -d "$SINCE" '+%s' 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$SINCE" '+%s')

log INFO "=== Log monitor report: since '$SINCE' ==="

# --- nginx error log ---
log INFO "--- nginx errors ---"
if [[ -f "$NGINX_ERROR_LOG" ]]; then
  NGINX_ERRORS=$(grep -i "\[error\]\|\[crit\]\|\[alert\]\|\[emerg\]" "$NGINX_ERROR_LOG" \
    | awk -v since="$SINCE_TS" '
      {
        match($0, /([0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/, ts)
        cmd = "date -d \"" ts[1] "\" +%s 2>/dev/null"
        cmd | getline ets; close(cmd)
        if (ets+0 >= since+0) print
      }' 2>/dev/null || grep -i "\[error\]\|\[crit\]" "$NGINX_ERROR_LOG" | tail -20)

  if [[ -n "$NGINX_ERRORS" ]]; then
    NGINX_COUNT=$(echo "$NGINX_ERRORS" | wc -l)
    log WARN "Found $NGINX_COUNT nginx errors:"
    echo "$NGINX_ERRORS" | while read -r line; do
      log WARN "  $line"
    done
  else
    log INFO "No nginx errors found since '$SINCE'"
  fi
else
  log WARN "nginx error log not found at $NGINX_ERROR_LOG"
fi

# --- Mail log ---
log INFO "--- mail.log analysis ---"
if [[ -f "$MAIL_LOG" ]]; then
  BOUNCED=$(grep "status=bounced" "$MAIL_LOG" | tail -20)
  DEFERRED=$(grep "status=deferred" "$MAIL_LOG" | tail -10)
  SENT=$(grep "status=sent" "$MAIL_LOG" | wc -l)

  log INFO "Emails sent (status=sent): $SENT"

  if [[ -n "$BOUNCED" ]]; then
    BOUNCE_COUNT=$(echo "$BOUNCED" | wc -l)
    log WARN "Bounced emails: $BOUNCE_COUNT"
    echo "$BOUNCED" | while read -r line; do
      log WARN "  BOUNCE: $line"
    done
  else
    log INFO "No bounced emails"
  fi

  if [[ -n "$DEFERRED" ]]; then
    DEFER_COUNT=$(echo "$DEFERRED" | wc -l)
    log WARN "Deferred emails: $DEFER_COUNT (will retry)"
    echo "$DEFERRED" | while read -r line; do
      log WARN "  DEFER: $line"
    done
  else
    log INFO "No deferred emails"
  fi
else
  log WARN "Mail log not found at $MAIL_LOG"
fi

log INFO "=== Log monitor complete ==="

# --- Optional: email the summary ---
if [[ -n "$RECIPIENT" ]] && command -v mail &>/dev/null; then
  tail -50 "$LOG_FILE" | mail -s "[ShopMonitor] Log report $(date +%F)" "$RECIPIENT"
  log INFO "Report emailed to $RECIPIENT"
fi
