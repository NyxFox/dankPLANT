#!/bin/bash
# Uninstall/cleanup script for Grow Station
# Run as root: sudo bash debian/uninstall.sh

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (use sudo)"
    exit 1
fi

log_warn "This will remove all Grow Station services and data!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Stop and disable services
echo "Stopping services..."
systemctl stop flask-api.service 2>/dev/null || true
systemctl stop ustreamer.service 2>/dev/null || true
systemctl stop caddy.service 2>/dev/null || true

systemctl disable flask-api.service 2>/dev/null || true
systemctl disable ustreamer.service 2>/dev/null || true

# Remove service files
echo "Removing service files..."
rm -f /etc/systemd/system/flask-api.service
rm -f /etc/systemd/system/ustreamer.service

# Reload systemd
systemctl daemon-reload

# Remove application files
echo "Removing application files..."
rm -rf /opt/grow
rm -rf /var/log/grow
rm -rf /var/log/ustreamer
rm -rf /var/www/html/*
rm -rf /var/www/data/*
rm -f /etc/caddy/Caddyfile

# Optionally remove user
read -p "Remove 'grow' user? (yes/no): " remove_user
if [ "$remove_user" == "yes" ]; then
    userdel grow 2>/dev/null || true
    echo "User 'grow' removed"
fi

echo "Cleanup complete!"
echo "Note: Packages (caddy, ustreamer, python3) were NOT removed."
echo "To remove packages: apt-get remove caddy"
