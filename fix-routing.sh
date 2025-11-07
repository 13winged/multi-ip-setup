#!/bin/bash
#
# Fix Routing Issues for Multi-IP Setup
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INTERFACE=""
MAIN_GW=""
TABLE_START=1001

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

detect_network_config() {
    # Detect primary interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$INTERFACE" ]]; then
        error "Could not detect network interface"
    fi
    
    # Detect gateway
    MAIN_GW=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -z "$MAIN_GW" ]]; then
        error "Could not detect gateway"
    fi
}

fix_routing_tables() {
    log "Fixing routing tables for subnet 10.0.0.0/24..."
    
    fixed_count=0
    for i in {1..254}; do
        table=$((TABLE_START + i - 1))
        ip="10.0.0.$i"
        
        # Check if IP exists on interface
        if ip addr show "$INTERFACE" | grep -q "$ip"; then
            # Remove existing route if any
            ip route del default table "$table" 2>/dev/null || true
            
            # Add correct route with src
            ip route add default via "$MAIN_GW" dev "$INTERFACE" table "$table" src "$ip" 2>/dev/null && {
                log "Fixed table $table for IP $ip"
                ((fixed_count++))
            }
            
            # Ensure rule exists
            if ! ip rule show | grep -q "from $ip"; then
                ip rule add from "$ip" table "$table" 2>/dev/null && {
                    log "Added rule for IP $ip -> table $table"
                }
            fi
        fi
    done
    
    log "Fixed $fixed_count routing tables"
}

disable_rp_filter() {
    log "Disabling Reverse Path Filtering..."
    sysctl -w net.ipv4.conf."$INTERFACE".rp_filter=0 2>/dev/null && echo "✓ Disabled RP filter for $INTERFACE" || warn "Could not disable RP filter for $INTERFACE"
    sysctl -w net.ipv4.conf.all.rp_filter=0 2>/dev/null && echo "✓ Disabled RP filter for all interfaces" || warn "Could not disable RP filter for all interfaces"
}

flush_firewall() {
    log "Checking firewall rules..."
    
    if command -v iptables >/dev/null; then
        # Only flush if there are restrictive rules
        if iptables -L -n | grep -q "DROP\|REJECT"; then
            warn "Flushing iptables rules..."
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            log "Iptables flushed"
        else
            log "No restrictive iptables rules found"
        fi
    fi
    
    if command -v nft >/dev/null; then
        if nft list ruleset 2>/dev/null | grep -q "drop\|reject"; then
            warn "Flushing nftables rules..."
            nft flush ruleset 2>/dev/null || true
            log "Nftables flushed"
        else
            log "No restrictive nftables rules found"
        fi
    fi
}

check_ip_addresses() {
    log "Checking configured IP addresses..."
    ip_count=$(ip addr show "$INTERFACE" | grep -c "10.0.0." || true)
    if [[ $ip_count -eq 0 ]]; then
        warn "No additional IP addresses found on $INTERFACE"
        echo "Run ./setup-multi-ip.sh to configure IP addresses first"
        return 1
    fi
    log "Found $ip_count additional IP addresses"
    return 0
}

main() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} This script must be run as root"
        exit 1
    fi
    
    echo -e "${YELLOW}=== MULTI-IP ROUTING FIX ===${NC}"
    
    detect_network_config
    echo "Interface: $INTERFACE"
    echo "Gateway: $MAIN_GW"
    
    if check_ip_addresses; then
        fix_routing_tables
        disable_rp_filter
        flush_firewall
        
        echo -e "\n${GREEN}=== ALL FIXES APPLIED ===${NC}"
        echo "Run ./diagnose-network.sh to verify the fix"
    else
        echo -e "\n${YELLOW}=== RUN SETUP FIRST ===${NC}"
        echo "Execute: ./setup-multi-ip.sh"
        exit 1
    fi
}

main "$@"