# Debian Grow Station - Quick Reference

## Installation

```bash
sudo bash debian/deploy.sh
```

## Service Commands

| Command | Description |
|---------|-------------|
| `sudo systemctl status flask-api` | Check Flask API status |
| `sudo systemctl status ustreamer` | Check camera streamer status |
| `sudo systemctl status caddy` | Check web server status |
| `sudo systemctl restart <service>` | Restart a service |
| `sudo systemctl stop <service>` | Stop a service |
| `sudo systemctl start <service>` | Start a service |
| `bash debian/status.sh` | Check all services at once |

## Log Viewing

| Command | Description |
|---------|-------------|
| `sudo journalctl -u flask-api -f` | Follow Flask API logs |
| `sudo journalctl -u ustreamer -f` | Follow camera logs |
| `sudo journalctl -u caddy -f` | Follow Caddy logs |
| `sudo journalctl -u flask-api -n 50` | View last 50 Flask API log lines |

## URLs (replace `<IP>` with your server IP)

| URL | Purpose |
|-----|---------|
| `http://<IP>/` | Main dashboard |
| `http://<IP>/api/health` | API health check |
| `http://<IP>/api/sensor` | Current sensor data |
| `http://<IP>/video/stream/stream` | Live camera stream |

## File Locations

| Path | Description |
|------|-------------|
| `/opt/grow/api/` | Flask API application |
| `/var/www/html/` | Dashboard files |
| `/var/www/data/sensor.json` | Stored sensor data |
| `/var/log/grow/` | Flask API logs |
| `/var/log/ustreamer/` | Camera streamer logs |
| `/etc/systemd/system/flask-api.service` | Flask API service config |
| `/etc/systemd/system/ustreamer.service` | Camera service config |
| `/etc/caddy/Caddyfile` | Web server config |

## Troubleshooting

### Check camera devices
```bash
v4l2-ctl --list-devices
ls -l /dev/video*
```

### Check camera capabilities
```bash
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

### Check what's using port 80
```bash
sudo netstat -tulpn | grep :80
```

### Test Flask API manually
```bash
sudo -u grow /opt/grow/api/.venv/bin/python /opt/grow/api/app.py
```

### Check disk space
```bash
df -h
```

### Check system resources
```bash
htop
```

## ESP8266 Setup

1. Copy config template:
   ```bash
   cp esp8266/include/config.h.example esp8266/include/config.h
   ```

2. Edit `esp8266/include/config.h` with your values

3. Flash firmware:
   ```bash
   cd esp8266
   pio run --target upload
   ```

4. Monitor output:
   ```bash
   pio device monitor
   ```

## Camera Configuration

Edit `/etc/systemd/system/ustreamer.service` and change resolution/framerate/quality:

```ini
ExecStart=/usr/bin/ustreamer \
    --device=/dev/video0 \
    --host=127.0.0.1 \
    --port=8090 \
    --resolution=1920x1080 \
    --format=MJPEG \
    --desired-fps=30 \
    --encoder=HW \
    --quality=80 \
    --last-as-blank=5
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ustreamer
```

## Uninstall

```bash
sudo bash debian/uninstall.sh
```

## Get Server IP

```bash
hostname -I
```

Or:
```bash
ip addr show
```

## Automated install (preseed)

For a fully automated Debian 13 installation that deploys this project, use the preseed file at `debian/preseed.cfg`.

Quick usage:

1. Host `debian/preseed.cfg` via HTTP, or copy it to installer media.
2. Boot the Debian installer and append a kernel parameter, for example:
   - `preseed/url=http://<your-server>/preseed.cfg auto=true priority=critical`
   - or: `preseed/file=/cdrom/preseed.cfg auto=true priority=critical`
3. The preseed will:
   - Use DHCP, locale `en_US.UTF-8`, timezone `UTC`
   - Wipe `/dev/sda` with guided partitioning (atomic)
   - Create user `growadmin` with password `changeme` (change immediately!)
   - Install `openssh-server`, `sudo`, `git`, `curl`, `v4l-utils`
   - Clone this repo to `/opt/grow-station-source` and run `debian/deploy.sh`

Notes:
- WARNING: This will erase `/dev/sda`. Adjust disk settings in `preseed.cfg` for your environment.
WARNING: This will erase `/dev/sda`. Adjust disk settings in `preseed.cfg` for your environment.
