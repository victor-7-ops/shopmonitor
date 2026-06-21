#!/bin/bash
set -euo pipefail

# Script: nginx-check.sh
# Purpose: Check if nginx is running; restart it if not; log every event
# Usage:   ./nginx-check.sh
# Cron:    */5 * * * * /opt/shopmonitor/scripts/nginx-check.sh

LOG_DIR="/var/log/shopmonitor"
LOG_FILE="$LOG_DIR/nginx-check.log"

log() {
  local level="$1"; shift
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
  mkdir -p "$LOG_DIR"
  echo "$msg" >> "$LOG_FILE"
  echo "$msg"
}

check_nginx() {
  systemctl is-active --quiet nginx
}

restart_nginx() {
  log WARN "nginx is DOWN — attempting restart"
  if systemctl restart nginx; then
    log INFO "nginx restarted successfully"
    return 0
  else
    log ERROR "nginx restart FAILED — manual intervention required"
    return 1
  fi
}

verify_http() {
  if curl -sf --max-time 5 http://localhost/health > /dev/null 2>&1; then
    log INFO "HTTP health check passed (localhost/health returned 200)"
    return 0
  else
    log WARN "HTTP health check failed — nginx may be running but app is down"
    return 1
  fi
}

log INFO "=== nginx health check starting ==="

if check_nginx; then
  log INFO "nginx is running (PID: $(systemctl show nginx --property=MainPID --value))"
  verify_http || true
else
  restart_nginx
  sleep 3
  if check_nginx; then
    log INFO "nginx is now running after restart"
    verify_http || true
  else
    log ERROR "nginx is still down after restart attempt"
    exit 1
  fi
fi

log INFO "=== nginx health check complete ==="
