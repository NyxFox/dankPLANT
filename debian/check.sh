#!/bin/bash
# Pre-installation check script for Debian Grow Station
# Run this to verify your system is ready for deployment

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"

echo "=== Debian Grow Station - Pre-Installation Check ==="
echo ""

# Check OS
echo -n "Checking OS version... "
if grep -q "Debian" /etc/os-release 2>/dev/null; then
    VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    echo -e "${PASS} Debian ${VERSION}"
    if [ "$VERSION" != "13" ]; then
        echo -e "  ${WARN} This script is designed for Debian 13, but may work on other versions"
    fi
else
    echo -e "${FAIL} Not Debian"
    echo "  This script is designed for Debian-based systems"
fi

# Check if running as root
echo -n "Checking root privileges... "
if [ "$EUID" -eq 0 ]; then
    echo -e "${PASS} Running as root"
else
    echo -e "${FAIL} Not running as root"
    echo "  Please run with sudo: sudo bash debian/check.sh"
fi

# Check internet connectivity
echo -n "Checking internet connectivity... "
if ping -c 1 debian.org &>/dev/null; then
    echo -e "${PASS} Internet accessible"
else
    echo -e "${FAIL} Cannot reach internet"
    echo "  Internet connection required to download packages"
fi

# Check available disk space
echo -n "Checking disk space... "
AVAILABLE=$(df / | tail -1 | awk '{print $4}')
if [ "$AVAILABLE" -gt 1048576 ]; then  # 1GB in KB
    echo -e "${PASS} $(( AVAILABLE / 1024 / 1024 ))GB available"
else
    echo -e "${WARN} Less than 1GB available"
    echo "  Recommended: At least 1GB free space"
fi

# Check if ports are available
echo -n "Checking if port 80 is available... "
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    echo -e "${WARN} Port 80 already in use"
    echo "  Current process:"
    netstat -tulpn | grep :80 || true
else
    echo -e "${PASS} Port 80 available"
fi

echo -n "Checking if port 5000 is available... "
if netstat -tuln 2>/dev/null | grep -q ":5000 "; then
    echo -e "${WARN} Port 5000 already in use"
else
    echo -e "${PASS} Port 5000 available"
fi

echo -n "Checking if port 8090 is available... "
if netstat -tuln 2>/dev/null | grep -q ":8090 "; then
    echo -e "${WARN} Port 8090 already in use"
else
    echo -e "${PASS} Port 8090 available"
fi

# Check for USB camera
echo -n "Checking for USB camera... "
if [ -e /dev/video0 ]; then
    echo -e "${PASS} Camera detected at /dev/video0"
    if command -v v4l2-ctl &>/dev/null; then
        echo "  Camera info:"
        v4l2-ctl --device=/dev/video0 --info 2>/dev/null | head -3 || true
    fi
else
    echo -e "${WARN} No camera detected"
    echo "  Camera can be connected later. mjpg-streamer will fail until camera is connected."
fi

# Check Python version
echo -n "Checking Python 3... "
if command -v python3 &>/dev/null; then
    PYVER=$(python3 --version | cut -d' ' -f2)
    echo -e "${PASS} Python ${PYVER}"
else
    echo -e "${WARN} Python 3 not installed"
    echo "  Will be installed during deployment"
fi

# Check if systemd is available
echo -n "Checking systemd... "
if command -v systemctl &>/dev/null; then
    echo -e "${PASS} systemd available"
else
    echo -e "${FAIL} systemd not found"
    echo "  This script requires systemd"
fi

# Check package manager
echo -n "Checking package manager... "
if command -v apt-get &>/dev/null; then
    echo -e "${PASS} apt available"
else
    echo -e "${FAIL} apt not found"
fi

# Summary
echo ""
echo "=== Summary ==="
echo ""
echo "If all checks passed, you're ready to run:"
echo "  sudo bash debian/deploy.sh"
echo ""
echo "If there are warnings, you can still proceed but may need to:"
echo "  - Free up disk space"
echo "  - Stop services using ports 80, 5000, or 8090"
echo "  - Connect USB camera later"
echo ""
