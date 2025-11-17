#!/bin/bash
# One-line installer for Grow Station on Debian 13
# Usage: curl -sSL https://raw.githubusercontent.com/dankplant/dankplant/main/install.sh | sudo bash
# Or: wget -qO- https://raw.githubusercontent.com/dankplant/dankplant/main/install.sh | sudo bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Check OS
if ! grep -q "Debian" /etc/os-release 2>/dev/null; then
    log_error "This installer is designed for Debian systems"
    exit 1
fi

log_info "Grow Station Installer for Debian 13"
echo ""

# Check if git is installed
if ! command -v git &>/dev/null; then
    log_info "Installing git..."
    apt-get update -qq
    apt-get install -y git
fi

REPO_URL="${REPO_URL:-https://github.com/dankplant/dankplant.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/grow-station-source}"

log_info "Cloning repository to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    log_info "Directory exists, pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Run deployment script
log_info "Running deployment script..."
bash debian/deploy.sh

log_info "Installation complete!"
echo ""
log_info "Source files are in: $INSTALL_DIR"
log_info "Run 'bash debian/status.sh' to check service status"
