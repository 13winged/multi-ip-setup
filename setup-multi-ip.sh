#!/bin/bash
#
# Multi-IP Setup Script
# Automatic configuration of multiple IP addresses on single interface
# GitHub: https://github.com/yourusername/multi-ip-setup
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default configuration - will be auto-detected or can be set in config.env
INTERFACE=""
MAIN_IP=""
MAIN_GW=""
SUBNET="10.0.0.0/24"
START_IP=1
END_IP=254
TABLE_START=1001

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

detect_network_config() {
    log "Detecting network configuration..."
    
    # Detect primary interface
    if [[ -z "$INTERFACE" ]]; then
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        if [[ -z "$INTERFACE" ]]; then
            error "Could not detect network interface"
        fi
        log "Detected interface: $INTERFACE"
    fi
    
    # Detect main IP
    if [[ -z "$MAIN_IP" ]]; then
        MAIN_IP=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
        if [[ -z "$MAIN_IP" ]]; then
            error "Could not detect main IP address"
        fi
        log "Detected main IP: $MAIN_IP"
    fi
    
    # Detect gateway
    if [[ -z "$MAIN_GW" ]]; then
        MAIN_GW=$(ip route | grep default | awk '{print $3}' | head -1)
        if [[ -z "$MAIN_GW" ]]; then
            error "Could not detect gateway"
        fi
        log "Detected gateway: $MAIN_GW"
    fi
    
    # Load config from file if exists
    if [[ -f "config.env" ]]; then
        log "Loading configuration from config.env"
        source config.env
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_interface() {
    if ! ip link show "$INTERFACE" &>/dev/null; then
        error "Interface $INTERFACE not found"
    fi
}

backup_config() {
    log "Creating backup of current configuration..."
    mkdir -p /backup/multi-ip
    ip addr show > "/backup/multi-ip/ip-addr-$(date +%Y%m%d-%H%M%S).bak"
    ip route show > "/backup/multi-ip/ip-route-$(date +%Y%m%d-%H%M%S).bak"
    ip rule show > "/backup/multi-ip/ip-rule-$(date +%Y%m%d-%H%M%S).bak"
}

add_ip_addresses() {
    log "Adding IP addresses to interface $INTERFACE..."
    
    for i in $(seq $START_IP $END_IP); do
        ip="10.0.0.$i"
        if ! ip addr show "$INTERFACE" | grep -q "$ip"; then
            ip addr add "$ip/32" dev "$INTERFACE" label "${INTERFACE}:$((i+9))"
            log "Added IP: $ip"
        else
            warn "IP $ip already exists"
        fi
    done
}

create_routing_tables() {
    log "Creating routing tables..."
    
    for i in $(seq $START_IP $END_IP); do
        table=$((TABLE_START + i - 1))
        ip="10.0.0.$i"
        
        # Create routing table
        if ! ip route show table "$table" &>/dev/null; then
            ip route add default via "$MAIN_GW" dev "$INTERFACE" table "$table" src "$ip"
            log "Created table $table for IP $ip"
        fi
        
        # Create routing rule
        if ! ip rule show | grep -q "from $ip"; then
            ip rule add from "$ip" table "$table"
            log "Created rule for IP $ip -> table $table"
        fi
    done
}

disable_rp_filter() {
    log "Disabling Reverse Path Filtering..."
    sysctl -w net.ipv4.conf."$INTERFACE".rp_filter=0
    sysctl -w net.ipv4.conf.all.rp_filter=0
    
    # Make permanent
    echo "net.ipv4.conf.$INTERFACE.rp_filter=0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
}

setup_persistence() {
    log "Setting up persistence via systemd..."
    
    cat > /etc/systemd/system/multi-ip-setup.service << EOF
[Unit]
Description=Multi-IP Routing Setup
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/multi-ip-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    cp "$0" /usr/local/bin/multi-ip-setup.sh
    chmod +x /usr/local/bin/multi-ip-setup.sh
    systemctl enable multi-ip-setup.service
}

verify_setup() {
    log "Verifying setup..."
    
    echo -e "\n${YELLOW}=== SETUP VERIFICATION ===${NC}"
    
    # Check IP addresses
    ip_count=$(ip addr show "$INTERFACE" | grep -c "10.0.0." || true)
    log "Found IP addresses: $ip_count"
    
    # Check routing tables
    table_count=$(ip rule show | grep -c "lookup" || true)
    log "Found routing tables: $((table_count - 2))"  # subtract local and main
    
    # Test connectivity
    if curl --interface "$MAIN_IP" -s --connect-timeout 3 http://ifconfig.me/ > /dev/null; then
        log "Main IP $MAIN_IP is working"
    else
        warn "Main IP $MAIN_IP is not accessible"
    fi
    
    # Test additional IP
    test_ip="10.0.0.5"
    if curl --interface "$test_ip" -s --connect-timeout 3 http://ifconfig.me/ > /dev/null; then
        result_ip=$(curl --interface "$test_ip" -s http://ifconfig.me/)
        if [[ "$result_ip" == "$test_ip" ]]; then
            log "Additional IP $test_ip is working correctly"
        else
            warn "Additional IP $test_ip is being SNAT'd to: $result_ip (provider issue)"
        fi
    else
        warn "Additional IP $test_ip is not accessible"
    fi
}

show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup     - Full multi-IP setup"
    echo "  diagnose  - Diagnostic current setup"
    echo "  backup    - Create configuration backup"
    echo "  restore   - Restore configuration (not implemented)"
    echo ""
    echo "Example: $0 setup"
}

main() {
    check_root
    detect_network_config
    check_interface
    
    case "${1:-setup}" in
        setup)
            backup_config
            add_ip_addresses
            create_routing_tables
            disable_rp_filter
            setup_persistence
            verify_setup
            log "Setup completed successfully!"
            ;;
        diagnose)
            verify_setup
            ;;
        backup)
            backup_config
            ;;
        *)
            show_usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"