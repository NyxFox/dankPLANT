# Deployment Checklist - Debian 13 Grow Station

## Pre-Deployment

- [ ] Fresh Debian 13 installation (headless)
- [ ] System is up to date (`sudo apt-get update && sudo apt-get upgrade`)
- [ ] Network connectivity confirmed
- [ ] Server has static IP or DHCP reservation
- [ ] Note server IP: ________________
- [ ] Root/sudo access confirmed
- [ ] USB webcam connected (optional, can add later)
- [ ] At least 2GB free disk space

## Installation Steps

### 1. Run Pre-Installation Check
```bash
sudo bash debian/check.sh
```
- [ ] All checks passed or warnings acceptable
- [ ] Ports 80, 5000, 8090 are available
- [ ] Camera detected (if connected)

### 2. Deploy Services
```bash
sudo bash debian/deploy.sh
```
- [ ] All packages installed successfully
- [ ] Services created and enabled
- [ ] No errors in deployment output

### 3. Verify Installation
```bash
bash debian/test.sh
```
- [ ] All services running
- [ ] Dashboard accessible
- [ ] API health check passes
- [ ] Video stream working (if camera connected)

### 4. Check Service Status
```bash
bash debian/status.sh
```
- [ ] flask-api: active (running)
- [ ] caddy: active (running)
- [ ] ustreamer: active (running) or acceptable failure

## Browser Testing

Replace `<IP>` with your server IP:

- [ ] Dashboard loads: `http://<IP>/`
- [ ] API responds: `http://<IP>/api/health`
- [ ] Sensor endpoint ready: `http://<IP>/api/sensor`
- [ ] Video stream works: `http://<IP>/video/stream/?action=stream`

## ESP8266 Configuration

### 1. Prepare Configuration
```bash
cd esp8266
cp include/config.h.example include/config.h
```

### 2. Edit config.h
- [ ] WiFi SSID: `<SSID>`
- [ ] WiFi Password: `<WIFI_PASSWORD>`
- [ ] Server IP: `<SERVER_IP>` (from above)
- [ ] DHT11 GPIO: `<GPIO_DHT>` (e.g., D4)
- [ ] OLED SDA GPIO: `<GPIO_OLED_SDA>` (e.g., D2)
- [ ] OLED SCL GPIO: `<GPIO_OLED_SCL>` (e.g., D1)

### 3. Flash Firmware
```bash
cd esp8266
pio run --target upload
```
- [ ] Firmware compiled successfully
- [ ] Upload completed
- [ ] No errors

### 4. Monitor ESP8266
```bash
pio device monitor
```
- [ ] ESP8266 connects to WiFi
- [ ] NTP time synchronized
- [ ] Sensor readings appear
- [ ] HTTP POST succeeds
- [ ] No connection errors

## Post-Deployment Verification

### 1. Wait for First Sensor Reading
- [ ] Wait ~30 seconds after ESP8266 boots
- [ ] Check: `http://<IP>/api/sensor`
- [ ] JSON data appears with temp/humidity

### 2. Monitor Logs
```bash
sudo journalctl -u flask-api -f
```
- [ ] POST requests from ESP8266 appear
- [ ] No errors in logs

### 3. Dashboard Update
- [ ] Refresh dashboard: `http://<IP>/`
- [ ] Temperature displays
- [ ] Humidity displays
- [ ] Last update timestamp current
- [ ] Video stream visible (if camera connected)

## Optional Configuration

### Adjust Camera Settings (if needed)
```bash
sudo nano /etc/systemd/system/ustreamer.service
```
- [ ] Resolution adjusted
- [ ] Framerate adjusted
- [ ] Quality adjusted
```bash
sudo systemctl daemon-reload
sudo systemctl restart ustreamer
```

### Create First Backup
```bash
sudo bash debian/backup.sh backup
```
- [ ] Backup created successfully

### Setup Firewall (if internet-exposed)
```bash
sudo apt-get install ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
```
- [ ] Firewall configured
- [ ] Can still access dashboard

## Production Readiness

### Security
- [ ] Change default passwords (if any)
- [ ] Configure firewall
- [ ] Consider HTTPS (Caddy + domain)
- [ ] Restrict CORS in app.py (if needed)
- [ ] Add authentication (if needed)

### Monitoring
- [ ] Test automatic service restart on failure
- [ ] Setup log rotation if needed
- [ ] Consider monitoring solution
- [ ] Document server IP for team

### Backup Strategy
- [ ] Schedule regular backups
- [ ] Test backup restore
- [ ] Document backup location

## Troubleshooting Reference

### Service won't start
```bash
sudo systemctl status <service-name>
sudo journalctl -u <service-name> -n 50
```

### Permission errors
```bash
sudo chown -R grow:grow /opt/grow/api
sudo chown -R grow:grow /var/www/data
```

### ESP8266 can't connect
- [ ] Check WiFi credentials
- [ ] Verify server IP is correct
- [ ] Check 2.4GHz WiFi (ESP8266 doesn't support 5GHz)
- [ ] Monitor serial output

### Camera issues
```bash
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

## Sign-Off

- [ ] All services operational
- [ ] ESP8266 sending data
- [ ] Dashboard displays correctly
- [ ] Camera stream working (if applicable)
- [ ] Documentation reviewed
- [ ] Team notified of server IP
- [ ] Backup created

**Deployed by:** ________________  
**Date:** ________________  
**Server IP:** ________________  
**Notes:** ________________________________________________

## Quick Commands Reference

```bash
# Status check
bash debian/status.sh

# View logs
sudo journalctl -u flask-api -f

# Restart service
sudo systemctl restart flask-api

# Run tests
bash debian/test.sh

# Backup
sudo bash debian/backup.sh backup

# Get server IP
hostname -I
```

---

**Deployment Status:** ☐ In Progress  ☐ Complete  ☐ Issues
