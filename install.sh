#!/bin/bash
#
# Installation script for Multi-IP Setup
#

set -e

echo "Multi-IP Setup Scripts - Installation"
echo "======================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Copy scripts to system locations
echo "Installing scripts..."
cp setup-multi-ip.sh /usr/local/bin/
cp diagnose-network.sh /usr/local/bin/
cp fix-routing.sh /usr/local/bin/

chmod +x /usr/local/bin/setup-multi-ip.sh
chmod +x /usr/local/bin/diagnose-network.sh
chmod +x /usr/local/bin/fix-routing.sh

# Create config directory
mkdir -p /etc/multi-ip-setup

# Copy example config if it doesn't exist
if [[ ! -f /etc/multi-ip-setup/config.env ]]; then
    cp config.env.example /etc/multi-ip-setup/config.env
    echo "Example config created: /etc/multi-ip-setup/config.env"
    echo "Please edit this file with your actual IP addresses"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Quick start:"
echo "1. Edit /etc/multi-ip-setup/config.env with your IP addresses"
echo "2. Run: setup-multi-ip.sh"
echo "3. Verify: diagnose-network.sh"
echo ""
echo "For help: diagnose-network.sh --help"