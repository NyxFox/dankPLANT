#!/bin/bash
# Quick status check script for Grow Station services
# Usage: bash debian/status.sh

echo "=== Grow Station Service Status ==="
echo ""

echo "--- Flask API ---"
systemctl status flask-api.service --no-pager -l | head -10
echo ""

echo "--- MJPG Streamer ---"
systemctl status mjpg-streamer.service --no-pager -l | head -10
echo ""

echo "--- Caddy Web Server ---"
systemctl status caddy.service --no-pager -l | head -10
echo ""

echo "=== Recent Logs ==="
echo ""
echo "--- Flask API (last 5 lines) ---"
journalctl -u flask-api.service -n 5 --no-pager
echo ""

echo "--- MJPG Streamer (last 5 lines) ---"
journalctl -u mjpg-streamer.service -n 5 --no-pager
echo ""

echo "--- Caddy (last 5 lines) ---"
journalctl -u caddy.service -n 5 --no-pager
echo ""

# Get server IP
HOSTNAME=$(hostname -I | awk '{print $1}')
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="<SERVER_IP>"
fi

echo "=== Service URLs ==="
echo "Dashboard:      http://${HOSTNAME}/"
echo "API Health:     http://${HOSTNAME}/api/health"
echo "Sensor Data:    http://${HOSTNAME}/api/sensor"
echo "Video Stream:   http://${HOSTNAME}/video/stream/?action=stream"
