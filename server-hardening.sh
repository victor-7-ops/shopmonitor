#!/bin/bash
set -euo pipefail

# Script: server-hardening.sh
# Purpose: Harden a fresh Ubuntu 22.04 server — UFW, fail2ban, SSH lockdown
# Usage:   sudo ./server-hardening.sh <deploy_user> <ssh_public_key>
# Run once after initial server provisioning

LOG_DIR="/var/log/shopmonitor"
LOG_FILE="$LOG_DIR/hardening.log"

log() {
  local level="$1"; shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2; exit 1
fi

DEPLOY_USER="${1:-deployer}"
SSH_PUBKEY="${2:-}"

mkdir -p "$LOG_DIR"
log INFO "=== Starting server hardening ==="

# --- Create deploy user ---
if ! id "$DEPLOY_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
  usermod -aG sudo "$DEPLOY_USER"
  log INFO "Created user: $DEPLOY_USER"
fi

# --- Set up SSH key if provided ---
if [[ -n "$SSH_PUBKEY" ]]; then
  SSH_DIR="/home/$DEPLOY_USER/.ssh"
  mkdir -p "$SSH_DIR"
  echo "$SSH_PUBKEY" >> "$SSH_DIR/authorized_keys"
  chmod 700 "$SSH_DIR"
  chmod 600 "$SSH_DIR/authorized_keys"
  chown -R "$DEPLOY_USER:$DEPLOY_USER" "$SSH_DIR"
  log INFO "SSH public key installed for $DEPLOY_USER"
fi

# --- Harden SSH config ---
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%F)"

declare -A SSH_SETTINGS=(
  ["PasswordAuthentication"]="no"
  ["PermitRootLogin"]="no"
  ["PubkeyAuthentication"]="yes"
  ["X11Forwarding"]="no"
  ["MaxAuthTries"]="3"
  ["LoginGraceTime"]="20"
)

for key in "${!SSH_SETTINGS[@]}"; do
  val="${SSH_SETTINGS[$key]}"
  if grep -q "^$key" "$SSHD_CONFIG"; then
    sed -i "s/^$key.*/$key $val/" "$SSHD_CONFIG"
  else
    echo "$key $val" >> "$SSHD_CONFIG"
  fi
done

systemctl restart sshd
log INFO "SSH hardened: password auth disabled, root login disabled"

# --- UFW firewall ---
apt-get install -y ufw > /dev/null
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable
log INFO "UFW configured: 22, 80, 443 open"

# --- fail2ban ---
apt-get install -y fail2ban > /dev/null

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log INFO "fail2ban installed and configured"

# --- System updates ---
apt-get update -q && apt-get upgrade -y -q > /dev/null
log INFO "System packages updated"

log INFO "=== Hardening complete ==="
log INFO "IMPORTANT: Verify SSH key login works before closing this session"
echo ""
echo "Next steps:"
echo "  1. Test SSH login as $DEPLOY_USER from another terminal"
echo "  2. Confirm: ufw status verbose"
echo "  3. Confirm: systemctl status fail2ban"
