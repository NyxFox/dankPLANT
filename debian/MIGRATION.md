# Migration Guide: Alpine Linux to Debian 13

This guide helps you migrate an existing Alpine Linux Grow Station setup to Debian 13.

## Quick Migration Path

If you're starting fresh on a new Debian 13 system, simply run:

```bash
sudo bash debian/deploy.sh
```

Then reconfigure your ESP8266 with the new server IP.

## Key Differences

### Package Manager
- **Alpine**: `apk`
- **Debian**: `apt-get` / `apt`

### Init System
- **Alpine**: OpenRC
- **Debian**: systemd

### Service Files
- **Alpine**: `/etc/init.d/` scripts with `/etc/conf.d/` configs
- **Debian**: `/etc/systemd/system/*.service` units

### Service Management
| Task | Alpine (OpenRC) | Debian (systemd) |
|------|----------------|------------------|
| Start service | `rc-service flask-api start` | `systemctl start flask-api` |
| Stop service | `rc-service flask-api stop` | `systemctl stop flask-api` |
| Enable on boot | `rc-update add flask-api default` | `systemctl enable flask-api` |
| Check status | `rc-service flask-api status` | `systemctl status flask-api` |
| View logs | `/var/log/grow/flask-api.log` | `journalctl -u flask-api -f` |

### File Paths
Most paths remain the same:
- `/opt/grow/api/` - Flask API
- `/var/www/html/` - Dashboard
- `/var/www/data/` - Sensor data
- `/etc/caddy/Caddyfile` - Caddy config

### MJPG-Streamer Plugin Paths
- **Alpine**: `/usr/lib/mjpg-streamer/`
- **Debian**: `/usr/lib/x86_64-linux-gnu/mjpg-streamer/`

## Manual Migration Steps

### 1. Backup Your Data (on Alpine)

```bash
# On Alpine system
tar -czf /tmp/grow-backup.tar.gz \
  /var/www/data/sensor.json \
  /etc/caddy/Caddyfile \
  /opt/grow/api/
  
# Copy to new Debian system
scp /tmp/grow-backup.tar.gz user@debian-host:/tmp/
```

### 2. Deploy on Debian

```bash
# On Debian system
sudo bash debian/deploy.sh
```

### 3. Restore Your Data

```bash
# Extract backup
cd /tmp
tar -xzf grow-backup.tar.gz

# Restore sensor data (if needed)
sudo cp var/www/data/sensor.json /var/www/data/
sudo chown grow:grow /var/www/data/sensor.json

# Review and merge any custom changes to Caddyfile or app.py
# Don't blindly overwrite - check differences first
diff etc/caddy/Caddyfile /etc/caddy/Caddyfile
```

### 4. Update ESP8266

Update the server IP in your ESP8266 `config.h`:

```cpp
#define SERVER_IP "192.168.1.XXX"  // New Debian server IP
```

Reflash:
```bash
cd esp8266
pio run --target upload
```

## Service Conversion Reference

### Flask API

**Alpine OpenRC** (`/etc/init.d/flask-api`):
```bash
start_stop_daemon --start --background \
  --exec /usr/bin/gunicorn -- \
  -w 2 -b 127.0.0.1:5000 app:app
```

**Debian systemd** (`/etc/systemd/system/flask-api.service`):
```ini
[Service]
Type=notify
User=grow
ExecStart=/opt/grow/api/.venv/bin/gunicorn \
  --workers 2 \
  --bind 127.0.0.1:5000 \
  app:app
```

### MJPG-Streamer

**Alpine OpenRC** (`/etc/init.d/mjpg-streamer`):
```bash
mjpg_streamer \
  -i "/usr/lib/mjpg-streamer/input_uvc.so ..." \
  -o "/usr/lib/mjpg-streamer/output_http.so ..."
```

**Debian systemd** (`/etc/systemd/system/mjpg-streamer.service`):
```ini
[Service]
Type=simple
User=video
ExecStart=/usr/bin/mjpg_streamer \
  -i "/usr/lib/x86_64-linux-gnu/mjpg-streamer/input_uvc.so ..." \
  -o "/usr/lib/x86_64-linux-gnu/mjpg-streamer/output_http.so ..."
```

## Troubleshooting Migration Issues

### Services Won't Start

Check service status and logs:
```bash
sudo systemctl status flask-api
sudo journalctl -u flask-api -n 50
```

Common issues:
- Wrong plugin paths for mjpg-streamer
- Python virtual environment not activated
- Permission issues on `/var/www/data`

### Python Virtual Environment

Debian uses proper virtual environments:
```bash
cd /opt/grow/api
sudo -u grow python3 -m venv .venv
sudo -u grow .venv/bin/pip install -r requirements.txt
```

### Permissions

Ensure correct ownership:
```bash
sudo chown -R grow:grow /opt/grow/api
sudo chown -R grow:grow /var/www/data
sudo chown -R grow:grow /var/log/grow
```

## Testing After Migration

Run the test script:
```bash
sudo bash debian/test.sh
```

Check all endpoints:
- Dashboard: `http://<IP>/`
- API: `http://<IP>/api/health`
- Sensor: `http://<IP>/api/sensor`
- Stream: `http://<IP>/video/stream/?action=stream`

## Rollback Plan

If you need to go back to Alpine:
1. Keep your Alpine system backed up
2. The Alpine files are still in the `alpine/` directory
3. Your ESP8266 can be reconfigured with the old server IP

## Getting Help

After migration, use these tools:
- `bash debian/status.sh` - Check all services
- `bash debian/test.sh` - Run all tests
- `sudo journalctl -u <service> -f` - Watch logs

## Summary

The Debian version provides:
- ✅ Better systemd integration
- ✅ More comprehensive logging with journald
- ✅ Automated deployment script
- ✅ Better security hardening options
- ✅ More familiar environment for most users
- ✅ Easier troubleshooting tools

The core application (Flask API, Caddy, mjpg-streamer, ESP8266) remains identical - only the init system and package management changed.
