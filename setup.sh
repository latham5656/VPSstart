#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓] $1${NC}"; }
info() { echo -e "${CYAN}[*] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
err()  { echo -e "${RED}[✗] $1${NC}"; exit 1; }

[ "$EUID" -ne 0 ] && err "Run as root: sudo bash setup.sh"

SSH_PORT=4893

echo -e "${CYAN}"
echo "╔══════════════════════════════════════╗"
echo "║         VPS Initial Setup            ║"
echo "║     SSH port: $SSH_PORT               ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: System update ──────────────────────────────────────────────────────
info "Step 1/5 — Updating system..."
apt update -y && apt upgrade -y && apt autoremove -y
log "System updated"

# ── Step 2: Change SSH port ────────────────────────────────────────────────────
info "Step 2/5 — Changing SSH port to $SSH_PORT..."
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -qE "^Port\s" "$SSHD_CONFIG"; then
    sed -i "s/^Port\s.*/Port $SSH_PORT/" "$SSHD_CONFIG"
elif grep -qE "^#Port\s" "$SSHD_CONFIG"; then
    sed -i "s/^#Port\s.*/Port $SSH_PORT/" "$SSHD_CONFIG"
else
    echo "Port $SSH_PORT" >> "$SSHD_CONFIG"
fi

warn "SSH port changed to $SSH_PORT — your current session will stay active."
warn "Reconnect using: ssh user@host -p $SSH_PORT"

# ── Step 3: UFW ────────────────────────────────────────────────────────────────
info "Step 3/5 — Installing UFW and opening port $SSH_PORT..."
apt install -y ufw

ufw allow "$SSH_PORT/tcp" comment "SSH custom port"
ufw --force enable
log "UFW enabled, port $SSH_PORT allowed"

# Restart SSH only after UFW is up
systemctl restart sshd
log "SSH restarted on port $SSH_PORT"

# ── Step 4: Fail2Ban ───────────────────────────────────────────────────────────
info "Step 4/5 — Installing Fail2Ban..."
bash <(curl -fsSL https://raw.githubusercontent.com/OMchik33/LightVPS/main/inst_fail2ban_ssh.sh)

# Patch jail to use the actual SSH port instead of the default 'ssh' alias
if [ -f /etc/fail2ban/jail.d/sshd.local ]; then
    sed -i "s/^port\s*=\s*ssh/port    = $SSH_PORT/" /etc/fail2ban/jail.d/sshd.local
    systemctl restart fail2ban
    log "Fail2Ban reconfigured for port $SSH_PORT"
fi

# ── Step 5: TrafficGuard ───────────────────────────────────────────────────────
info "Step 5/5 — Installing TrafficGuard..."
curl -fsSL https://raw.githubusercontent.com/DonMatteoVPN/TrafficGuard-auto/refs/heads/main/install-trafficguard.sh | bash
log "TrafficGuard installed"

# ── Done ───────────────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}╔══════════════════════════════════════╗"
echo -e "║          Setup complete!             ║"
echo -e "╚══════════════════════════════════════╝${NC}"
echo
echo -e "  SSH port  : ${CYAN}$SSH_PORT${NC}"
echo -e "  Firewall  : ${CYAN}ufw status${NC}"
echo -e "  Fail2Ban  : ${CYAN}fail2ban-client status sshd${NC}"
echo
warn "Don't forget to reconnect on port $SSH_PORT"
