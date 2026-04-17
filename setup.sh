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
    echo -e "${CYAN}${BOLD}  ║          VPS Initial Setup               ║${NC}"
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

section "Шаг 1/5 — Обновление системы"
run_step "apt update и upgrade" bash -c "apt update -y && apt upgrade -y && apt autoremove -y"

section "Шаг 2/5 — Смена SSH порта"
SSHD_CONFIG="/etc/ssh/sshd_config"
if grep -qE "^Port\s" "$SSHD_CONFIG"; then
    sed -i "s/^Port\s.*/Port $SSH_PORT/" "$SSHD_CONFIG"
elif grep -qE "^#Port\s" "$SSHD_CONFIG"; then
    sed -i "s/^#Port\s.*/Port $SSH_PORT/" "$SSHD_CONFIG"
else
    echo "Port $SSH_PORT" >> "$SSHD_CONFIG"
fi
printf "  ${GREEN}✓${NC}  %-50s\n" "Порт SSH изменён на $SSH_PORT"

section "Шаг 3/5 — Установка UFW"
run_step "Установка и настройка файрвола" bash -c "
    apt install -y ufw
    ufw allow ${SSH_PORT}/tcp comment 'SSH custom port'
    ufw --force enable
    systemctl restart sshd
"

section "Шаг 4/5 — Установка Fail2Ban"
run_pipe_step "Установка Fail2Ban" \
    "bash <(curl -fsSL https://raw.githubusercontent.com/OMchik33/LightVPS/main/inst_fail2ban_ssh.sh)"

section "Шаг 5/5 — Установка TrafficGuard"
run_pipe_step "Установка TrafficGuard" \
    "curl -fsSL https://raw.githubusercontent.com/DonMatteoVPN/TrafficGuard-auto/refs/heads/main/install-trafficguard.sh | bash -s -- </dev/null"

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
echo
echo -e "  ${YELLOW}⚠  Переподключитесь: ${CYAN}ssh user@host -p ${SSH_PORT}${NC}"
echo

# ── Menu ───────────────────────────────────────────────────────────────────────

while true; do
    echo -e "  ${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}║              Меню управления             ║${NC}"
    echo -e "  ${BOLD}╠══════════════════════════════════════════╣${NC}"
    echo -e "  ${BOLD}║  ${CYAN}1${BOLD}  Статус UFW                           ║${NC}"
    echo -e "  ${BOLD}║  ${CYAN}2${BOLD}  Статус Fail2Ban                      ║${NC}"
    echo -e "  ${BOLD}║  ${CYAN}3${BOLD}  Показать лог установки               ║${NC}"
    echo -e "  ${BOLD}║  ${RED}0${BOLD}  Выход                                ║${NC}"
    echo -e "  ${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo
    printf "  Выберите пункт: "
    read -r choice

    case $choice in
        1)
            echo
            echo -e "  ${CYAN}${BOLD}— Статус UFW —${NC}"
            ufw status | sed 's/^/  /'
            echo
            ;;
        2)
            echo
            echo -e "  ${CYAN}${BOLD}— Статус Fail2Ban (sshd) —${NC}"
            fail2ban-client status sshd 2>/dev/null | sed 's/^/  /' || echo -e "  ${YELLOW}Fail2Ban не запущен${NC}"
            echo
            ;;
        3)
            echo
            echo -e "  ${CYAN}${BOLD}— Лог установки —${NC}"
            cat "$LOG_FILE" | sed 's/^/  /'
            echo
            ;;
        0)
            echo
            echo -e "  ${GREEN}До свидания!${NC}"
            echo
            exit 0
            ;;
        *)
            echo -e "\n  ${RED}Неверный выбор, попробуйте снова.${NC}\n"
            ;;
    esac
done
