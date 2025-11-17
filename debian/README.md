# Debian 13 Grow Station - File Summary

## New Files Created for Debian

### Core Deployment
- **debian/deploy.sh** - Automated installation script (run as root)
- **debian/Caddyfile** - Caddy web server configuration

### Systemd Services
- **debian/systemd/flask-api.service** - Flask API service unit
- **debian/systemd/ustreamer.service** - Camera streamer service unit

### Management Scripts
- **debian/check.sh** - Pre-installation system check
- **debian/status.sh** - Quick status check for all services
- **debian/test.sh** - Comprehensive service testing
- **debian/backup.sh** - Backup and restore utility
- **debian/uninstall.sh** - Complete removal script

### Configuration
Note: ustreamer settings are configured directly in the systemd service file.

### Documentation
**README.md** - Main documentation
**debian/QUICKSTART.md** - Quick reference guide

### Other
- **esp8266/include/config.h.example** - ESP8266 configuration template

## Directory Structure

```
dankplant/
├── README.md
│
├── debian/
│   ├── deploy.sh              # Main deployment script
│   ├── check.sh               # Pre-installation check
│   ├── status.sh              # Status checker
│   ├── test.sh                # Test suite
│   ├── backup.sh              # Backup/restore
│   ├── uninstall.sh           # Cleanup script
│   ├── Caddyfile              # Web server config
│   ├── QUICKSTART.md          # Quick reference
│   └── systemd/
│       ├── flask-api.service
│       └── ustreamer.service
│
│
├── api/
│   ├── app.py
│   └── requirements.txt
│
├── dashboard/
│   ├── index.html
│   └── assets/
│
├── esp8266/
│   ├── platformio.ini
│   ├── include/
│   │   └── config.h.example
│   └── src/
        └── main.cpp
```

## Quick Start Commands

### Installation
```bash
sudo bash debian/deploy.sh
```

### Service Management
```bash
sudo systemctl status flask-api
sudo systemctl restart flask-api
sudo journalctl -u flask-api -f
```

### Utilities
```bash
bash debian/status.sh        # Check all services
bash debian/test.sh          # Run tests
sudo bash debian/backup.sh   # Backup data
```

## System Requirements

- **OS**: Debian 13 (headless)
- **RAM**: 512MB minimum, 1GB recommended
- **Disk**: 2GB free space
- **Network**: Ethernet or WiFi with static/DHCP IP
- **Optional**: USB webcam (UVC compatible)

## Service Architecture

```
Port 80 → Caddy
          ├─ / → /var/www/html (dashboard)
          ├─ /api/* → 127.0.0.1:5000 (Flask API)
          └─ /video/stream/* → 127.0.0.1:8090 (ustreamer)

User: grow (member of video group for camera access)
  ├─ /opt/grow/api (Flask app + venv)
  ├─ /var/www/data (sensor.json)
  ├─ /var/log/grow (logs)
  └─ /var/log/ustreamer (camera logs)
  └─ /dev/video0 (camera access via video group)
```

## Deployment Workflow

1. Run `debian/check.sh` - Verify system requirements
2. Run `debian/deploy.sh` - Install everything
3. Run `debian/test.sh` - Verify installation
4. Configure ESP8266 with server IP
5. Flash ESP8266 firmware
6. Monitor with `debian/status.sh`

## Support

All scripts include:
- Colored output for readability
- Error checking and validation
- Helpful error messages
- Safe defaults

Ready for production use on Debian 13!
