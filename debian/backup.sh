#!/bin/bash
# Backup and restore script for Grow Station data

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_DIR="/var/backups/grow-station"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

show_help() {
    cat << EOF
Grow Station Backup/Restore Script

Usage: sudo bash debian/backup.sh [COMMAND]

Commands:
  backup      Create a backup of sensor data and configuration
  restore     Restore from the latest backup
  list        List available backups
  help        Show this help message

Examples:
  sudo bash debian/backup.sh backup
  sudo bash debian/backup.sh restore
  sudo bash debian/backup.sh list
EOF
}

backup() {
    echo "Creating backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
    
    # Create temporary directory for backup contents
    TMP_DIR=$(mktemp -d)
    
    # Copy files to backup
    echo "Collecting files..."
    mkdir -p "$TMP_DIR/data"
    mkdir -p "$TMP_DIR/config"
    mkdir -p "$TMP_DIR/api"
    
    # Backup sensor data
    if [ -f /var/www/data/sensor.json ]; then
        cp /var/www/data/sensor.json "$TMP_DIR/data/"
        echo "  ✓ Sensor data"
    fi
    
    # Backup configuration
    if [ -f /etc/caddy/Caddyfile ]; then
        cp /etc/caddy/Caddyfile "$TMP_DIR/config/"
        echo "  ✓ Caddyfile"
    fi
    
    if [ -f /etc/systemd/system/flask-api.service ]; then
        cp /etc/systemd/system/flask-api.service "$TMP_DIR/config/"
        echo "  ✓ Flask API service"
    fi
    
    if [ -f /etc/systemd/system/mjpg-streamer.service ]; then
        cp /etc/systemd/system/mjpg-streamer.service "$TMP_DIR/config/"
        echo "  ✓ MJPG Streamer service"
    fi
    
    # Backup API code (optional)
    if [ -f /opt/grow/api/app.py ]; then
        cp /opt/grow/api/app.py "$TMP_DIR/api/"
        echo "  ✓ Flask API code"
    fi
    
    if [ -f /opt/grow/api/requirements.txt ]; then
        cp /opt/grow/api/requirements.txt "$TMP_DIR/api/"
        echo "  ✓ Requirements"
    fi
    
    # Create tarball
    echo "Creating archive..."
    tar -czf "$BACKUP_FILE" -C "$TMP_DIR" .
    
    # Cleanup
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
    echo "  Size: $(du -h "$BACKUP_FILE" | cut -f1)"
}

restore() {
    # Find latest backup
    LATEST=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$LATEST" ]; then
        echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo "Restoring from: $LATEST"
    echo -e "${YELLOW}This will overwrite current files!${NC}"
    read -p "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    
    # Extract backup
    echo "Extracting backup..."
    tar -xzf "$LATEST" -C "$TMP_DIR"
    
    # Restore files
    echo "Restoring files..."
    
    if [ -f "$TMP_DIR/data/sensor.json" ]; then
        cp "$TMP_DIR/data/sensor.json" /var/www/data/
        chown grow:grow /var/www/data/sensor.json
        echo "  ✓ Sensor data"
    fi
    
    if [ -f "$TMP_DIR/config/Caddyfile" ]; then
        cp "$TMP_DIR/config/Caddyfile" /etc/caddy/
        echo "  ✓ Caddyfile"
    fi
    
    if [ -f "$TMP_DIR/config/flask-api.service" ]; then
        cp "$TMP_DIR/config/flask-api.service" /etc/systemd/system/
        echo "  ✓ Flask API service"
    fi
    
    if [ -f "$TMP_DIR/config/mjpg-streamer.service" ]; then
        cp "$TMP_DIR/config/mjpg-streamer.service" /etc/systemd/system/
        echo "  ✓ MJPG Streamer service"
    fi
    
    if [ -f "$TMP_DIR/api/app.py" ]; then
        cp "$TMP_DIR/api/app.py" /opt/grow/api/
        chown grow:grow /opt/grow/api/app.py
        echo "  ✓ Flask API code"
    fi
    
    # Cleanup
    rm -rf "$TMP_DIR"
    
    # Reload systemd
    echo "Reloading systemd..."
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Restore complete${NC}"
    echo "Restart services with: sudo systemctl restart flask-api caddy"
}

list_backups() {
    echo "Available backups in $BACKUP_DIR:"
    echo ""
    
    if ls "$BACKUP_DIR"/backup_*.tar.gz >/dev/null 2>&1; then
        ls -lh "$BACKUP_DIR"/backup_*.tar.gz | awk '{print "  " $9 " (" $5 ") - " $6 " " $7 " " $8}'
    else
        echo "  No backups found"
    fi
}

# Main
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

case "${1:-help}" in
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    list)
        list_backups
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
