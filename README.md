# VPS Initial Setup

One-command VPS hardening script for Debian/Ubuntu.

## What it does

| Step | Action |
|------|--------|
| 1 | `apt update && apt upgrade && apt autoremove` |
| 2 | Change SSH port → **4893** |
| 3 | Install UFW, allow port 4893, enable firewall |
| 4 | Install & configure [Fail2Ban for SSH](https://github.com/OMchik33/LightVPS/blob/main/inst_fail2ban_ssh.sh) |
| 5 | Install [TrafficGuard](https://github.com/DonMatteoVPN/TrafficGuard-auto) |

## Usage

```bash
git clone https://github.com/YOUR_USERNAME/vps-setup.git
cd vps-setup
sudo bash setup.sh
```

Or run directly without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/vps-setup/main/setup.sh | sudo bash
```

## After setup

Reconnect via SSH on the new port:

```bash
ssh user@your-server -p 4893
```

Check firewall and Fail2Ban status:

```bash
ufw status
fail2ban-client status sshd
```

## Requirements

- Debian 11+ or Ubuntu 20.04+
- Root access (`sudo`)
- Internet connection
