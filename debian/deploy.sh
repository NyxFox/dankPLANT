#!/bin/bash
# Automated setup script for Grow Station on Debian 13 (headless)
# Run this script as root
# Usage: sudo bash debian/deploy.sh

set -euo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info "Starting Grow Station deployment on Debian 13..."
log_info "Project root: $PROJECT_ROOT"

# Update system
log_info "Updating package lists..."
apt-get update

# Install required packages
log_info "Installing required packages..."
apt-get install -y \
    caddy \
    python3 \
    python3-pip \
    python3-venv \
    v4l-utils \
    git \
    curl \
    build-essential \
    libjpeg-dev \
    libevent-dev \
    libbsd-dev \
    libgpiod-dev \
    libjpeg62-turbo-dev

# Install ustreamer from source (official GitHub)
log_info "Installing ustreamer from source..."
USTREAMER_BUILD_DIR="/tmp/ustreamer-build"
if [ ! -f "/usr/local/bin/ustreamer" ]; then
    rm -rf "$USTREAMER_BUILD_DIR"
    git clone --depth=1 https://github.com/pikvm/ustreamer "$USTREAMER_BUILD_DIR"
    cd "$USTREAMER_BUILD_DIR"
    
    make
    make install
    
    log_info "ustreamer installed successfully"
    cd "$PROJECT_ROOT"
else
    log_info "ustreamer already installed"
fi

# Create grow user if doesn't exist
log_info "Creating 'grow' user..."
if ! id -u grow >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin --comment "Grow Station Service" grow
    log_info "User 'grow' created"
else
    log_warn "User 'grow' already exists"
fi

# Ensure 'video' group exists and add 'grow' to it for camera access
if ! getent group video >/dev/null 2>&1; then
    log_warn "Group 'video' not found; creating system group 'video'..."
    groupadd --system video
fi
usermod -a -G video grow || true

# Create necessary directories
log_info "Creating directory structure..."
install -d -m 0755 -o root -g root /var/www/html
install -d -m 0755 -o grow -g grow /opt/grow/api
install -d -m 0755 -o grow -g grow /var/log/grow
install -d -m 0755 -o grow -g grow /var/log/ustreamer
install -d -m 0755 -o root -g root /var/www/data
install -d -m 0755 -o root -g root /etc/caddy

# Make /var/www/data writable by grow user
chown grow:grow /var/www/data

# Deploy Flask API
log_info "Deploying Flask API..."
cp -r "$PROJECT_ROOT/api/"* /opt/grow/api/
chown -R grow:grow /opt/grow/api

# Create Python virtual environment
log_info "Creating Python virtual environment..."
cd /opt/grow/api
if [ ! -d ".venv" ]; then
    sudo -u grow python3 -m venv .venv
fi
sudo -u grow .venv/bin/pip install --upgrade pip
sudo -u grow .venv/bin/pip install --no-cache-dir -r requirements.txt

# Deploy systemd services
log_info "Installing systemd service files..."
cp "$PROJECT_ROOT/debian/systemd/flask-api.service" /etc/systemd/system/
cp "$PROJECT_ROOT/debian/systemd/ustreamer.service" /etc/systemd/system/

# Deploy Caddyfile
log_info "Installing Caddyfile..."
cp "$PROJECT_ROOT/debian/Caddyfile" /etc/caddy/Caddyfile

# Deploy dashboard
log_info "Deploying dashboard to /var/www/html..."
cp -r "$PROJECT_ROOT/dashboard/"* /var/www/html/

# Reload systemd
log_info "Reloading systemd daemon..."
systemctl daemon-reload

# Enable services
log_info "Enabling services..."
systemctl enable flask-api.service
systemctl enable ustreamer.service
systemctl enable caddy.service

# Start services
log_info "Starting services..."
systemctl restart flask-api.service
systemctl restart caddy.service

# Start ustreamer (might fail if no camera connected)
if systemctl restart ustreamer.service 2>/dev/null; then
    log_info "ustreamer started successfully"
else
    log_warn "ustreamer failed to start (check if USB camera is connected)"
    log_warn "You can start it later with: systemctl start ustreamer.service"
fi

# Check service status
log_info "Checking service status..."
echo ""
systemctl status flask-api.service --no-pager -l || true
echo ""
systemctl status caddy.service --no-pager -l || true
echo ""
systemctl status ustreamer.service --no-pager -l || true

# Display service URLs
HOSTNAME=$(hostname -I | awk '{print $1}')
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="<SERVER_IP>"
fi

echo ""
log_info "===== Deployment Complete ====="
echo ""
log_info "Access your Grow Station at:"
echo "  Dashboard:      http://${HOSTNAME}/"
echo "  API Health:     http://${HOSTNAME}/api/health"
echo "  Sensor Data:    http://${HOSTNAME}/api/sensor"
echo "  Video Stream:   http://${HOSTNAME}/video/stream/?action=stream"
echo ""
log_info "Service Management Commands:"
echo "  systemctl status flask-api"
echo "  systemctl status ustreamer"
echo "  systemctl status caddy"
echo "  systemctl restart <service-name>"
echo "  journalctl -u <service-name> -f"
echo ""
log_info "Next steps:"
echo "  1. Configure your ESP8266 with server IP: $HOSTNAME"
echo "  2. Check camera with: v4l2-ctl --list-devices"
echo "  3. Adjust camera settings in /etc/systemd/system/ustreamer.service if needed"
echo "  4. Monitor logs: journalctl -u flask-api -f"
echo ""
log_info "All services are now running!"
