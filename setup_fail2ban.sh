#!/bin/bash

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0"; exit 1; }

R='\033[0;31m'
G='\033[0;32m'
C='\033[0;36m'
M='\033[0;35m'
W='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'
TICK="${G}✔${NC}"
CROSS="${R}✘${NC}"

spinner() {
    local pid=$1 msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${C}${frames[$i]}${NC}  ${DIM}%s${NC}   " "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.08
    done
    tput cnorm 2>/dev/null
}

STEP=0; TOTAL=8

step() {
    STEP=$((STEP+1))
    local msg="$1" cmd="$2"
    printf "\n  ${BOLD}[%d/%d]${NC} %b\n" "$STEP" "$TOTAL" "$msg"
    eval "$cmd" > /tmp/f2b_log.txt 2>&1 &
    local pid=$!
    spinner $pid "Выполняю..."
    wait $pid; local code=$?
    if [[ $code -eq 0 ]]; then
        printf "\r  ${TICK}  ${G}Готово${NC}                              \n"
    else
        printf "\r  ${CROSS}  ${R}Ошибка!${NC}\n"
        cat /tmp/f2b_log.txt
        exit 1
    fi
}

progress_bar() {
    local pct=$1 label="$2" width=40 filled bar="" i
    filled=$(( width * pct / 100 ))
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<width; i++)); do bar+="░"; done
    printf "  ${C}[${NC}%s${C}]${NC} ${W}%3d%%${NC}  ${DIM}%s${NC}\n" "$bar" "$pct" "$label"
}

clear
printf "${M}"
cat << 'BANNER'

   ███████╗ █████╗ ██╗██╗     ██████╗ ██████╗  █████╗ ███╗   ██╗
   ██╔════╝██╔══██╗██║██║        ╚══███╔╝██╔══██╗██╔══██╗████╗  ██║
   █████╗  ███████║██║██║    ██████╔╝ ██████╔╝███████║██╔██╗ ██║
   ██╔══╝  ██╔══██║██║██║       ╚═══██╔╝ ██╔══██╗██╔══██║██║╚██╗██║
   ██║     ██║  ██║██║███████╗██████╔╝  ██████╔╝██║  ██║██║ ╚████║
   ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═════╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝
BANNER
printf "${NC}"
echo ""
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "  ${W}       Shield  HARDENED INSTALLER  --  Maximum Protection${NC}\n"
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""
sleep 0.4
printf "  ${C}Сканирую систему...${NC}\n\n"
sleep 0.2

SSH_PORT=$(ss -tlnp | grep sshd | grep -oP '(?<=:)\d+' | head -1)
SSH_PORT="${SSH_PORT:-22}"

HAS_NGINX=false; HAS_APACHE=false; HAS_POSTFIX=false; HAS_DOCKER=false
[[ -f /var/log/nginx/error.log || -d /var/log/nginx ]] && HAS_NGINX=true
[[ -d /var/log/apache2 || -d /var/log/httpd ]]          && HAS_APACHE=true
[[ -f /var/log/mail.log ]]                               && HAS_POSTFIX=true
command -v docker >/dev/null 2>&1                        && HAS_DOCKER=true

for svc in "SSH:true:порт $SSH_PORT" "Nginx:$HAS_NGINX:" "Apache:$HAS_APACHE:" "Postfix:$HAS_POSTFIX:" "Docker:$HAS_DOCKER:"; do
    name="${svc%%:*}"; rest="${svc#*:}"; found="${rest%%:*}"; hint="${rest#*:}"
    sleep 0.15
    if [[ "$found" == "true" ]]; then
        printf "  ${TICK}  ${W}%-12s${NC} ${G}обнаружен${NC}  ${DIM}%s${NC}\n" "$name" "$hint"
    else
        printf "  ${DIM}o  %-12s не найден${NC}\n" "$name"
    fi
done

echo ""
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "  ${W}  Начинаю установку...${NC}\n"
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ── вспомогательные скрипты для шагов ────────────────────────────────────────
write_helper_scripts() {
    cat > /tmp/f2b_step_jail.sh << JAILEOF
#!/bin/bash
cat > /etc/fail2ban/jail.local << JAILCONTENT
[DEFAULT]
bantime  = 604800
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1
backend  = auto
banaction = iptables-multiport
banaction_allports = iptables-allports
protocol = tcp
mode     = aggressive

[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 604800
findtime = 300

[sshd-permanent]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 2
bantime  = -1
findtime = 86400
JAILCONTENT
JAILEOF
    chmod +x /tmp/f2b_step_jail.sh

    cat > /tmp/f2b_step_services.sh << SVCEOF
#!/bin/bash
HAS_NGINX=${HAS_NGINX}
HAS_APACHE=${HAS_APACHE}
HAS_POSTFIX=${HAS_POSTFIX}
HAS_DOCKER=${HAS_DOCKER}
if [[ "\$HAS_NGINX" == "true" ]]; then
    mkdir -p /var/log/nginx
    touch /var/log/nginx/error.log /var/log/nginx/access.log
    printf '\n[nginx-http-auth]\nenabled=true\nport=http,https\nfilter=nginx-http-auth\nlogpath=/var/log/nginx/error.log\nmaxretry=3\nbantime=86400\n' >> /etc/fail2ban/jail.local
    printf '\n[nginx-botsearch]\nenabled=true\nport=http,https\nfilter=nginx-botsearch\nlogpath=/var/log/nginx/access.log\nmaxretry=2\nbantime=604800\nfindtime=60\n' >> /etc/fail2ban/jail.local
    printf '\n[nginx-limit-req]\nenabled=true\nport=http,https\nfilter=nginx-limit-req\nlogpath=/var/log/nginx/error.log\nmaxretry=5\nbantime=86400\n' >> /etc/fail2ban/jail.local
fi
if [[ "\$HAS_APACHE" == "true" ]]; then
    ALOG="/var/log/apache2"; [[ -d /var/log/httpd ]] && ALOG="/var/log/httpd"
    printf "\n[apache-auth]\nenabled=true\nport=http,https\nfilter=apache-auth\nlogpath=\$ALOG/*error.log\nmaxretry=3\nbantime=86400\n" >> /etc/fail2ban/jail.local
fi
if [[ "\$HAS_POSTFIX" == "true" ]]; then
    printf '\n[postfix]\nenabled=true\nport=smtp,465,submission\nfilter=postfix\nlogpath=/var/log/mail.log\nmaxretry=3\nbantime=86400\n' >> /etc/fail2ban/jail.local
fi
if [[ "\$HAS_DOCKER" == "true" ]]; then
    printf '\n[docker-auth]\nenabled=true\nfilter=docker-auth\nport=2375,2376\nlogpath=/var/log/syslog\nmaxretry=2\nbantime=-1\n' >> /etc/fail2ban/jail.local
    printf '[Definition]\nfailregex = .*unauthorized.*<HOST>\nignoreregex =\n' > /etc/fail2ban/filter.d/docker-auth.conf
fi
SVCEOF
    chmod +x /tmp/f2b_step_services.sh

    cat > /tmp/f2b_step_portscan.sh << 'PSEOF'
#!/bin/bash
printf '[Definition]\nfailregex = PORTSCAN:.* SRC=<HOST>\nignoreregex =\n' > /etc/fail2ban/filter.d/port-scan.conf
printf '\n[port-scan]\nenabled=true\nfilter=port-scan\nlogpath=/var/log/syslog\nmaxretry=1\nbantime=-1\nfindtime=60\n' >> /etc/fail2ban/jail.local
for port in 23 3306 5432 6379 27017; do
    iptables -I INPUT -p tcp --dport $port -m limit --limit 3/min -j LOG --log-prefix "PORTSCAN: " --log-level 4 2>/dev/null || true
done
PSEOF
    chmod +x /tmp/f2b_step_portscan.sh
}

# ── встроенная панель управления ──────────────────────────────────────────────
write_panel_script() {
    cat > /usr/local/bin/fail << 'PANELEOF'
#!/bin/bash

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo fail"; exit 1; }

R='\033[0;31m'
G='\033[0;32m'
C='\033[0;36m'
M='\033[0;35m'
W='\033[1;37m'
Y='\033[0;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'
TICK="${G}✔${NC}"
CROSS="${R}✘${NC}"

header() {
    clear
    printf "${M}"
    cat << 'BANNER'

   ███████╗ █████╗ ██╗██╗      ██████╗  █████╗ ███╗   ██╗███████╗██╗
   ██╔════╝██╔══██╗██║██║      ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║
   █████╗  ███████║██║██║█████╗██████╔╝███████║██╔██╗ ██║█████╗  ██║
   ██╔══╝  ██╔══██║██║██║╚════╝██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║
   ██║     ██║  ██║██║███████╗ ██║     ██║  ██║██║ ╚████║███████╗███████╗
   ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
BANNER
    printf "${NC}"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "  ${W}         fail2ban  CONTROL PANEL  --  Shield Manager${NC}\n"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo ""
}

get_jails() {
    fail2ban-client status 2>/dev/null \
        | grep "Jail list" \
        | sed 's/.*Jail list:\s*//' \
        | tr ',' '\n' | tr -d ' ' | grep -v '^$'
}

main_menu() {
    header
    local status
    status=$(systemctl is-active fail2ban 2>/dev/null)
    if [[ "$status" == "active" ]]; then
        printf "  ${TICK}  ${G}${BOLD}fail2ban: активен${NC}\n"
    else
        printf "  ${CROSS}  ${R}${BOLD}fail2ban: не запущен${NC}\n"
    fi
    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo ""
    printf "  ${W}${BOLD}[1]${NC}  ${C}Статус — список джейлов и заблокированных IP${NC}\n"
    printf "  ${W}${BOLD}[2]${NC}  ${C}Логи${NC}\n"
    printf "  ${W}${BOLD}[3]${NC}  ${C}Заблокировать IP${NC}\n"
    printf "  ${W}${BOLD}[4]${NC}  ${C}Разблокировать IP${NC}\n"
    printf "  ${W}${BOLD}[5]${NC}  ${C}Перезапустить fail2ban${NC}\n"
    printf "  ${W}${BOLD}[0]${NC}  ${DIM}Выход${NC}\n"
    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo ""
    printf "  ${W}Выбор: ${NC}"
    read -r choice
    case "$choice" in
        1) show_status ;;
        2) show_logs   ;;
        3) ban_ip      ;;
        4) unban_ip    ;;
        5) restart_f2b ;;
        0) echo ""; exit 0 ;;
        *) main_menu   ;;
    esac
}

show_status() {
    header
    printf "  ${W}${BOLD}Статус джейлов и заблокированные IP:${NC}\n\n"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    local jails total_banned=0
    jails=$(get_jails)

    if [[ -z "$jails" ]]; then
        printf "\n  ${R}Нет активных джейлов или fail2ban не запущен${NC}\n"
    else
        while IFS= read -r jail; do
            local info banned_count ip_list
            info=$(fail2ban-client status "$jail" 2>/dev/null)
            banned_count=$(echo "$info" | grep "Currently banned" | grep -oP '\d+')
            ip_list=$(echo "$info"      | grep "Banned IP list"   | sed 's/.*Banned IP list:\s*//')
            total_banned=$(( total_banned + ${banned_count:-0} ))

            printf "\n  ${C}${BOLD}%-20s${NC}  ${DIM}заблокировано: ${NC}${R}${BOLD}%s${NC}\n" "[$jail]" "${banned_count:-0}"
            if [[ -n "$ip_list" && "$ip_list" =~ [0-9] ]]; then
                for ip in $ip_list; do
                    printf "      ${CROSS}  ${W}%s${NC}\n" "$ip"
                done
            else
                printf "      ${DIM}нет заблокированных IP${NC}\n"
            fi
        done <<< "$jails"
    fi

    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "  ${DIM}Итого заблокировано: ${NC}${R}${BOLD}%s${NC}\n" "$total_banned"
    printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "
    read -r
    main_menu
}

show_logs() {
    header
    printf "  ${W}${BOLD}Последние события fail2ban (50 строк):${NC}\n\n"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

    local source logfile="/var/log/fail2ban.log"
    if [[ -f "$logfile" ]]; then
        source=$(tail -50 "$logfile")
    else
        source=$(journalctl -u fail2ban --no-pager -n 50 2>/dev/null)
    fi

    while IFS= read -r line; do
        if echo "$line" | grep -q " Ban ";     then printf "  ${R}%s${NC}\n" "$line"
        elif echo "$line" | grep -q " Unban "; then printf "  ${G}%s${NC}\n" "$line"
        elif echo "$line" | grep -q "WARNING\|ERROR"; then printf "  ${Y}%s${NC}\n" "$line"
        else printf "  ${DIM}%s${NC}\n" "$line"
        fi
    done <<< "$source"

    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "
    read -r
    main_menu
}

ban_ip() {
    header
    printf "  ${W}${BOLD}Заблокировать IP:${NC}\n\n"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

    local jails jail_arr=()
    jails=$(get_jails)

    if [[ -z "$jails" ]]; then
        printf "  ${R}Нет активных джейлов${NC}\n\n"
        printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "; read -r; main_menu; return
    fi

    printf "  ${C}Доступные джейлы:${NC}\n"
    local i=1
    while IFS= read -r jail; do
        jail_arr+=("$jail")
        printf "  ${W}${BOLD}[%d]${NC}  %s\n" "$i" "$jail"
        ((i++))
    done <<< "$jails"

    echo ""
    printf "  ${W}Выберите джейл [1-%d]: ${NC}" "${#jail_arr[@]}"
    read -r jidx

    if ! [[ "$jidx" =~ ^[0-9]+$ ]] || (( jidx < 1 || jidx > ${#jail_arr[@]} )); then
        printf "\n  ${R}Неверный выбор${NC}\n"; sleep 1; main_menu; return
    fi
    local selected_jail="${jail_arr[$((jidx-1))]}"

    echo ""
    printf "  ${W}Введите IP для блокировки: ${NC}"
    read -r ip
    [[ -z "$ip" ]] && { main_menu; return; }

    if ! echo "$ip" | grep -qP '^(\d{1,3}\.){3}\d{1,3}(/\d+)?$'; then
        printf "\n  ${R}Неверный формат IP${NC}\n"; sleep 1; main_menu; return
    fi

    echo ""
    if fail2ban-client set "$selected_jail" banip "$ip" > /dev/null 2>&1; then
        printf "  ${TICK}  ${G}${BOLD}IP ${W}%s${G} заблокирован в джейле ${W}%s${NC}\n" "$ip" "$selected_jail"
    else
        printf "  ${CROSS}  ${R}Ошибка при блокировке IP %s${NC}\n" "$ip"
    fi

    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "; read -r; main_menu
}

unban_ip() {
    header
    printf "  ${W}${BOLD}Разблокировать IP:${NC}\n\n"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

    local jails
    jails=$(get_jails)

    declare -A entry_map
    local entries=()

    while IFS= read -r jail; do
        [[ -z "$jail" ]] && continue
        local ip_list
        ip_list=$(fail2ban-client status "$jail" 2>/dev/null \
            | grep "Banned IP list" | sed 's/.*Banned IP list:\s*//')
        for ip in $ip_list; do
            [[ -z "$ip" ]] && continue
            local key="$ip  (${jail})"
            entries+=("$key")
            entry_map["$key"]="$jail|$ip"
        done
    done <<< "$jails"

    if [[ ${#entries[@]} -eq 0 ]]; then
        printf "  ${G}Нет заблокированных IP${NC}\n\n"
        printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "; read -r; main_menu; return
    fi

    printf "  ${C}Заблокированные IP:${NC}\n"
    local i=1
    for entry in "${entries[@]}"; do
        printf "  ${W}${BOLD}[%d]${NC}  ${R}%s${NC}\n" "$i" "$entry"
        ((i++))
    done

    echo ""
    printf "  ${W}${BOLD}[0]${NC}  ${DIM}Ввести IP вручную${NC}\n"
    echo ""
    printf "  ${W}Выберите [0-%d]: ${NC}" "${#entries[@]}"
    read -r choice

    local target_jail target_ip

    if [[ "$choice" == "0" ]]; then
        printf "  ${W}IP для разблокировки: ${NC}";          read -r target_ip
        printf "  ${W}Джейл (пусто = все джейлы): ${NC}";   read -r target_jail
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#entries[@]} )); then
        local pair="${entry_map[${entries[$((choice-1))]}]}"
        target_jail="${pair%%|*}"
        target_ip="${pair##*|}"
    else
        printf "\n  ${R}Неверный выбор${NC}\n"; sleep 1; main_menu; return
    fi

    [[ -z "$target_ip" ]] && { main_menu; return; }

    echo ""
    if [[ -n "$target_jail" ]]; then
        if fail2ban-client set "$target_jail" unbanip "$target_ip" > /dev/null 2>&1; then
            printf "  ${TICK}  ${G}${BOLD}IP ${W}%s${G} разблокирован из ${W}%s${NC}\n" "$target_ip" "$target_jail"
        else
            printf "  ${CROSS}  ${R}Ошибка при разблокировке ${W}%s${NC}\n" "$target_ip"
        fi
    else
        local ok=0
        while IFS= read -r jail; do
            [[ -z "$jail" ]] && continue
            fail2ban-client set "$jail" unbanip "$target_ip" > /dev/null 2>&1 && ((ok++))
        done <<< "$jails"
        printf "  ${TICK}  ${G}${BOLD}IP ${W}%s${G} разблокирован (из %d джейлов)${NC}\n" "$target_ip" "$ok"
    fi

    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "; read -r; main_menu
}

restart_f2b() {
    header
    printf "  ${W}${BOLD}Перезапуск fail2ban...${NC}\n\n"
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

    systemctl restart fail2ban
    sleep 2
    if [[ "$(systemctl is-active fail2ban 2>/dev/null)" == "active" ]]; then
        printf "  ${TICK}  ${G}${BOLD}fail2ban успешно перезапущен${NC}\n"
    else
        printf "  ${CROSS}  ${R}Ошибка при перезапуске — проверь journalctl -xe${NC}\n"
    fi

    echo ""
    printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n  ${DIM}Нажмите Enter для возврата...${NC} "; read -r; main_menu
}

main_menu
PANELEOF
    chmod +x /usr/local/bin/fail
}

# ── шаги установки ────────────────────────────────────────────────────────────
write_helper_scripts

step "${W}Обновление пакетов${NC}"                              "apt-get update -qq"
step "${W}Установка fail2ban${NC}"                              "apt-get install -y fail2ban"
step "${W}Создание базовых правил (SSH)${NC}"                   "bash /tmp/f2b_step_jail.sh"
step "${W}Настройка защиты сервисов${NC}"                       "bash /tmp/f2b_step_services.sh"
step "${W}Защита от сканирования портов${NC}"                   "bash /tmp/f2b_step_portscan.sh"
step "${W}Проверка конфигурации${NC}"                           "bash -c 'OUT=\$(fail2ban-client -t 2>&1); echo \"\$OUT\"; ! echo \"\$OUT\" | grep -q ERROR'"
step "${W}Запуск службы${NC}"                                   "bash -c 'systemctl enable fail2ban && systemctl restart fail2ban && sleep 2'"
step "${W}Установка панели управления (команда: fail)${NC}"     "write_panel_script"

# ── финал ─────────────────────────────────────────────────────────────────────
echo ""
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "  ${W}  Результат${NC}\n"
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

for pct in 10 25 40 55 70 82 91 100; do
    [[ $pct -gt 10 ]] && printf "\033[1A\033[K"
    label="Активирую защиту..."
    [[ $pct -eq 100 ]] && label="Сервер защищён!"
    progress_bar $pct "$label"
    sleep 0.12
done

echo ""
STATUS=$(systemctl is-active fail2ban 2>/dev/null)
[[ "$STATUS" == "active" ]] && \
    printf "  ${TICK}  ${G}${BOLD}fail2ban запущен и работает${NC}\n" || \
    printf "  ${CROSS}  ${R}Проблема с запуском: journalctl -xe${NC}\n"
printf "  ${TICK}  ${G}${BOLD}Панель управления установлена: команда 'fail'${NC}\n"
echo ""
printf "  ${M}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""
printf "  ${G}${BOLD}  Готово! Запусти панель командой: fail${NC}\n"
echo ""
