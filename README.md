# Начальная настройка VPS

Скрипт для защиты VPS на Debian/Ubuntu одной командой.

## Что делает скрипт

| Шаг | Действие |
|-----|----------|
| 1 | `apt update && apt upgrade && apt autoremove` |
| 2 | Смена порта SSH → **4893** |
| 3 | Установка UFW, разрешение порта 4893, включение файрвола |
| 4 | Установка и настройка [Fail2Ban для SSH](https://github.com/OMchik33/LightVPS/blob/main/inst_fail2ban_ssh.sh) |
| 5 | Установка [TrafficGuard](https://github.com/DonMatteoVPN/TrafficGuard-auto) |
| 6 | Установка [MOTD](https://github.com/distillium/motd) |

## Использование

```bash
git clone https://github.com/latham5656/vps-setup.git
cd vps-setup
sudo bash setup.sh
```

Или запустить напрямую без клонирования:

```bash
curl -fsSL https://raw.githubusercontent.com/latham5656/VPSstart/refs/heads/main/setup.sh | sudo bash
```

## После настройки

Переподключитесь по SSH на новый порт:

```bash
ssh user@your-server -p 4893
```

Проверьте статус файрвола и Fail2Ban:

```bash
ufw status
fail2ban-client status sshd
```

## Требования

- Debian 11+ или Ubuntu 20.04+
- Права root (`sudo`)
- Подключение к интернету
