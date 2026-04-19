<div align="center">

# 🛡️ VPSstart

**Автоматическая защита VPS одной командой**

![Debian](https://img.shields.io/badge/Debian-11%2B-A81D33?style=flat-square&logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

</div>

---

## 📋 Что делает скрипт

Скрипт выполняет полную начальную защиту свежего VPS на Debian/Ubuntu за один запуск:

| # | Шаг | Описание |
|:-:|-----|----------|
| 1️⃣ | **Обновление системы** | `apt update && apt upgrade && apt autoremove` |
| 2️⃣ | **Смена порта SSH** | Переключает SSH на порт **4893** |
| 3️⃣ | **Файрвол UFW** | Устанавливает UFW, разрешает порт 4893, включает защиту |
| 4️⃣ | **Fail2Ban** | Устанавливает и настраивает [Fail2Ban для SSH](https://github.com/OMchik33/LightVPS/blob/main/inst_fail2ban_ssh.sh) |
| 5️⃣ | **TrafficGuard** | Устанавливает [TrafficGuard](https://github.com/DonMatteoVPN/TrafficGuard-auto) для защиты трафика |
| 6️⃣ | **MOTD** | Устанавливает красивый [MOTD](https://github.com/distillium/motd) при входе |
| 7️⃣ | **UFW Manager** | Устанавливает [UFW Manager](https://github.com/latham5656/ufw-manager) — удобное управление правилами файрвола |

---

## ⚡ Быстрый запуск

### Вариант 1 — Без клонирования (рекомендуется)

```bash
curl -fsSL https://raw.githubusercontent.com/latham5656/VPSstart/refs/heads/main/setup.sh | sudo bash
```

### Вариант 2 — Клонировать и запустить

```bash
git clone https://github.com/latham5656/VPSstart.git
cd VPSstart
sudo bash setup.sh
```

---

## 🔌 После установки

Переподключитесь по SSH на новый порт:

```bash
ssh user@your-server -p 4893
```

Проверьте статус файрвола и Fail2Ban:

```bash
ufw status
fail2ban-client status sshd
```

Для управления правилами UFW запустите UFW Manager:

```bash
ufw-manager
```

---

## 📦 Требования

- 🐧 Debian 11+ или Ubuntu 20.04+
- 🔑 Права root (`sudo`)
- 🌐 Подключение к интернету

---

<div align="center">

Сделано с ❤️ для быстрого старта безопасного VPS

</div>
