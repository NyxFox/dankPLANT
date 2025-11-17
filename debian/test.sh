#!/bin/bash
# Test script for Grow Station services
# Run after deployment to verify everything works

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"

HOSTNAME=$(hostname -I | awk '{print $1}')
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="127.0.0.1"
fi

echo "=== Grow Station - Service Tests ==="
echo "Testing server: $HOSTNAME"
echo ""

# Test 1: Check if services are running
echo "Test 1: Service Status"
echo "-----------------------"

echo -n "  Flask API service... "
if systemctl is-active --quiet flask-api; then
    echo -e "${PASS} Running"
else
    echo -e "${FAIL} Not running"
fi

echo -n "  uStreamer service... "
if systemctl is-active --quiet ustreamer; then
    echo -e "${PASS} Running"
else
    echo -e "${WARN} Not running (camera may not be connected)"
fi

echo -n "  Caddy service... "
if systemctl is-active --quiet caddy; then
    echo -e "${PASS} Running"
else
    echo -e "${FAIL} Not running"
fi

echo ""

# Test 2: Check if ports are listening
echo "Test 2: Port Listening"
echo "----------------------"

echo -n "  Port 80 (Caddy)... "
if netstat -tuln | grep -q ":80 "; then
    echo -e "${PASS} Listening"
else
    echo -e "${FAIL} Not listening"
fi

echo -n "  Port 5000 (Flask API)... "
if netstat -tuln | grep -q ":5000 "; then
    echo -e "${PASS} Listening"
else
    echo -e "${FAIL} Not listening"
fi

echo -n "  Port 8090 (uStreamer)... "
if netstat -tuln | grep -q ":8090 "; then
    echo -e "${PASS} Listening"
else
    echo -e "${WARN} Not listening"
fi

echo ""

# Test 3: HTTP endpoint tests
echo "Test 3: HTTP Endpoints"
echo "----------------------"

echo -n "  Dashboard (/)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOSTNAME/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${PASS} HTTP $HTTP_CODE"
else
    echo -e "${FAIL} HTTP $HTTP_CODE"
fi

echo -n "  API Health (/api/health)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOSTNAME/api/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${PASS} HTTP $HTTP_CODE"
    RESPONSE=$(curl -s http://$HOSTNAME/api/health 2>/dev/null || echo "{}")
    if echo "$RESPONSE" | grep -q '"status".*"up"'; then
        echo -e "    Response: $RESPONSE"
    fi
else
    echo -e "${FAIL} HTTP $HTTP_CODE"
fi

echo -n "  Sensor Data (/api/sensor)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOSTNAME/api/sensor 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${PASS} HTTP $HTTP_CODE"
    RESPONSE=$(curl -s http://$HOSTNAME/api/sensor 2>/dev/null || echo "{}")
    if echo "$RESPONSE" | grep -q "empty"; then
        echo -e "    ${WARN} No sensor data yet (waiting for ESP8266)"
    else
        echo -e "    ${PASS} Sensor data available"
        echo "    Sample: $(echo $RESPONSE | head -c 80)..."
    fi
else
    echo -e "${FAIL} HTTP $HTTP_CODE"
fi

echo -n "  Video Stream (/video/stream/)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOSTNAME/video/stream/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${PASS} HTTP $HTTP_CODE"
elif [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ]; then
    echo -e "${WARN} HTTP $HTTP_CODE (uStreamer not running)"
else
    echo -e "${FAIL} HTTP $HTTP_CODE"
fi

echo ""

# Test 4: File permissions
echo "Test 4: File Permissions"
echo "------------------------"

echo -n "  /opt/grow/api ownership... "
if [ "$(stat -c '%U' /opt/grow/api 2>/dev/null)" = "grow" ]; then
    echo -e "${PASS} Owned by grow"
else
    echo -e "${FAIL} Wrong ownership"
fi

echo -n "  /var/www/data writable... "
if sudo -u grow test -w /var/www/data 2>/dev/null; then
    echo -e "${PASS} Writable by grow"
else
    echo -e "${FAIL} Not writable by grow"
fi

echo -n "  /var/log/grow writable... "
if sudo -u grow test -w /var/log/grow 2>/dev/null; then
    echo -e "${PASS} Writable by grow"
else
    echo -e "${FAIL} Not writable by grow"
fi

echo ""

# Test 5: Camera availability
echo "Test 5: Camera"
echo "--------------"

echo -n "  Camera device... "
if [ -e /dev/video0 ]; then
    echo -e "${PASS} /dev/video0 exists"
    if command -v v4l2-ctl &>/dev/null; then
        NAME=$(v4l2-ctl --device=/dev/video0 --info 2>/dev/null | grep "Card type" | cut -d: -f2 | xargs || echo "Unknown")
        echo "    Device: $NAME"
    fi
else
    echo -e "${WARN} No camera detected"
fi

echo ""

# Test 6: Configuration files
echo "Test 6: Configuration Files"
echo "---------------------------"

echo -n "  Caddyfile... "
if [ -f /etc/caddy/Caddyfile ]; then
    echo -e "${PASS} Exists"
else
    echo -e "${FAIL} Missing"
fi

echo -n "  Flask API app.py... "
if [ -f /opt/grow/api/app.py ]; then
    echo -e "${PASS} Exists"
else
    echo -e "${FAIL} Missing"
fi

echo -n "  Dashboard index.html... "
if [ -f /var/www/html/index.html ]; then
    echo -e "${PASS} Exists"
else
    echo -e "${FAIL} Missing"
fi

echo ""

# Summary
echo "=== Test Summary ==="
echo ""
echo "Access your Grow Station:"
echo "  Dashboard:      http://${HOSTNAME}/"
echo "  API Health:     http://${HOSTNAME}/api/health"
echo "  Sensor Data:    http://${HOSTNAME}/api/sensor"
echo "  Video Stream:   http://${HOSTNAME}/video/stream/?action=stream"
echo ""
echo "Check logs with:"
echo "  sudo journalctl -u flask-api -f"
echo "  sudo journalctl -u ustreamer -f"
echo "  sudo journalctl -u caddy -f"
echo ""
