#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

[ "$EUID" -ne 0 ] && echo -e "${RED}[✗] Запустите от root: sudo bash setup.sh${NC}" && exit 1

SSH_PORT=4893
LOG_FILE="/tmp/vps-setup.log"
> "$LOG_FILE"

# ── Helpers ────────────────────────────────────────────────────────────────────

spinner() {
    local pid=$1 msg=$2
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${frames[$i]}${NC}  %s" "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.1
    done
    tput cnorm
    printf "\r  ${GREEN}✓${NC}  %-50s\n" "$msg"
}

run_step() {
    local msg=$1; shift
    ("$@" >> "$LOG_FILE" 2>&1) &
    spinner $! "$msg"
}

run_pipe_step() {
    local msg=$1 cmd=$2
    (eval "$cmd" </dev/null >> "$LOG_FILE" 2>&1; true) &
    local bg_pid=$!
    spinner $bg_pid "$msg"
    wait $bg_pid 2>/dev/null || true
}

print_header() {
    clear
    echo
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}  ║          Настройка VPS                   ║${NC}"
    echo -e "${CYAN}${BOLD}  ║        SSH порт: ${SSH_PORT}                    ║${NC}"
    echo -e "${CYAN}${BOLD}  ╚══════════════════════════════════════════╝${NC}"
    echo
}

section() {
    echo
    echo -e "  ${BLUE}${BOLD}▸ $1${NC}"
}

# ── Installation ───────────────────────────────────────────────────────────────

print_header
echo -e "  ${YELLOW}Установка началась, подождите...${NC}"
echo

section "Шаг 1/6 — Обновление системы"
BOOT_DISK=$(lsblk -ndo pkname "$(findmnt -n -o SOURCE /)" 2>/dev/null | head -1)
[ -z "$BOOT_DISK" ] && BOOT_DISK=$(lsblk -ndo name,TYPE 2>/dev/null | awk '$2=="disk"{print $1; exit}')
if [ -n "$BOOT_DISK" ]; then
    echo "grub-pc grub-pc/install_devices multiselect /dev/${BOOT_DISK}" | debconf-set-selections
    echo "grub-pc grub-pc/install_devices_empty boolean false" | debconf-set-selections
fi
run_step "Обновляю систему" bash -c "DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none apt update -y && DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none apt upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' && DEBIAN_FRONTEND=noninteractive apt autoremove -y"

section "Шаг 2/6 — Смена SSH порта"
SSHD_CONFIG="/etc/ssh/sshd_config"
if grep -qE "^Port\s" "$SSHD_CONFIG"; then
    sed -i "s/^Port\s.*/Port $SSH_PORT/" "$SSHD_CONFIG"
elif grep -qE "^#Port\s" "$SSHD_CONFIG"; then
    sed -i "s/^#Port\s.*/Port $SSH_PORT/" "$SSHD_CONFIG"
else
    echo "Port $SSH_PORT" >> "$SSHD_CONFIG"
fi
printf "  ${GREEN}✓${NC}  %-50s\n" "Порт SSH изменён на $SSH_PORT"

section "Шаг 3/6 — Установка UFW"
run_step "Установка и настройка файрвола" bash -c "
    apt install -y ufw
    ufw allow ${SSH_PORT}/tcp comment 'SSH custom port'
    ufw --force enable
    systemctl restart sshd
"

section "Шаг 4/6 — Установка Fail2Ban"
run_pipe_step "Установка Fail2Ban" \
    "DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none bash <(curl -fsSL https://raw.githubusercontent.com/OMchik33/LightVPS/main/inst_fail2ban_ssh.sh)"

section "Шаг 5/6 — Установка TrafficGuard"
apt-get install -y expect >> "$LOG_FILE" 2>&1
printf "  ${CYAN}⠋${NC}  Установка TrafficGuard (может занять время)...\n"
expect >> "$LOG_FILE" 2>&1 << 'EXPECT_EOF'
set timeout 300
spawn bash -c {curl -fsSL https://raw.githubusercontent.com/DonMatteoVPN/TrafficGuard-auto/refs/heads/main/install-trafficguard.sh | bash}
expect "Ваш выбор:" { send "0\r" }
expect eof
EXPECT_EOF
printf "  ${GREEN}✓${NC}  %-50s\n" "TrafficGuard установлен"

section "Шаг 6/6 — Установка MOTD"
run_pipe_step "Установка MOTD" \
    "curl -fsSL https://raw.githubusercontent.com/distillium/motd/refs/heads/main/install-motd.sh -o /tmp/install-motd.sh && sed -i '/^[[:space:]]*select_language$/d' /tmp/install-motd.sh && bash /tmp/install-motd.sh"

# ── Done ───────────────────────────────────────────────────────────────────────

clear
print_header
echo -e "  ${GREEN}${BOLD}Установка завершена успешно!${NC}"
echo
echo -e "  ${BOLD}Статус системы:${NC}"
echo -e "  ${GREEN}✓${NC}  Система обновлена"
echo -e "  ${GREEN}✓${NC}  SSH порт изменён → ${CYAN}${BOLD}${SSH_PORT}${NC}"
echo -e "  ${GREEN}✓${NC}  UFW файрвол активен"
echo -e "  ${GREEN}✓${NC}  Fail2Ban установлен и настроен"
echo -e "  ${GREEN}✓${NC}  TrafficGuard установлен"
echo -e "  ${GREEN}✓${NC}  MOTD установлен"
echo
echo -e "  ${YELLOW}⚠  Переподключитесь: ${CYAN}ssh user@host -p ${SSH_PORT}${NC}"
echo
