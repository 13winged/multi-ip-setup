#!/bin/bash
#
# Network Diagnostic Script for Multi-IP Setup
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INTERFACE="${1:-}"
MAIN_IP=""
MAIN_GW=""

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

detect_network_config() {
    # Detect primary interface
    if [[ -z "$INTERFACE" ]]; then
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        if [[ -z "$INTERFACE" ]]; then
            error "Could not detect network interface"
        fi
    fi
    
    # Detect main IP
    MAIN_IP=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
    if [[ -z "$MAIN_IP" ]]; then
        error "Could not detect main IP address"
    fi
    
    # Detect gateway
    MAIN_GW=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -z "$MAIN_GW" ]]; then
        error "Could not detect gateway"
    fi
}

run_diagnostic() {
    echo -e "\n${YELLOW}=== COMPREHENSIVE MULTI-IP DIAGNOSTIC ===${NC}"
    
    # 1. System Info
    echo -e "\n${GREEN}1. SYSTEM INFORMATION${NC}"
    echo "Hostname: $(hostname)"
    echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"' 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    
    # 2. Network Interface
    echo -e "\n${GREEN}2. NETWORK INTERFACE: $INTERFACE${NC}"
    ip -br addr show dev "$INTERFACE" | head -3
    echo "Main IP: $MAIN_IP"
    echo "Gateway: $MAIN_GW"
    
    # 3. Routing Tables
    echo -e "\n${GREEN}3. ROUTING TABLES CHECK${NC}"
    for ip in 1 5 100; do
        table=$((1000 + ip))
        test_ip="10.0.0.$ip"
        if ip route show table "$table" 2>/dev/null | grep -q "default"; then
            echo "✓ Table $table ($test_ip): OK"
        else
            echo "✗ Table $table ($test_ip): MISSING"
        fi
    done
    
    # 4. Routing Rules
    echo -e "\n${GREEN}4. ROUTING RULES${NC}"
    ip rule show | grep -E "10\.0\.0\." | head -5 || echo "No rules for 10.0.0.x subnet found"
    total_rules=$(ip rule show | grep -c "10.0.0." || true)
    echo "... (total: $total_rules rules)"
    
    # 5. IP Addresses Count
    echo -e "\n${GREEN}5. IP ADDRESSES COUNT${NC}"
    ip_count=$(ip addr show "$INTERFACE" | grep -c "10.0.0." || true)
    echo "Additional IPs configured: $ip_count"
    
    # 6. Connectivity Test
    echo -e "\n${GREEN}6. CONNECTIVITY TEST${NC}"
    
    # Main IP test
    if curl --interface "$MAIN_IP" -s --connect-timeout 3 http://ifconfig.me/ >/dev/null; then
        main_result=$(curl --interface "$MAIN_IP" -s http://ifconfig.me/)
        if [[ "$main_result" == "$MAIN_IP" ]]; then
            echo "✓ Main IP $MAIN_IP: WORKS (correct source)"
        else
            echo "⚠ Main IP $MAIN_IP: SNAT DETECTED (shows: $main_result)"
        fi
    else
        echo "✗ Main IP $MAIN_IP: NO CONNECTIVITY"
    fi
    
    # Additional IPs test
    for test_ip in "10.0.0.5" "10.0.0.100"; do
        if ip addr show "$INTERFACE" | grep -q "$test_ip"; then
            if curl --interface "$test_ip" -s --connect-timeout 3 http://ifconfig.me/ >/dev/null; then
                actual_ip=$(curl --interface "$test_ip" -s http://ifconfig.me/)
                if [[ "$actual_ip" == "$test_ip" ]]; then
                    echo "✓ IP $test_ip: WORKS (correct source)"
                else
                    echo "⚠ IP $test_ip: SNAT DETECTED (shows: $actual_ip)"
                fi
            else
                echo "✗ IP $test_ip: NO CONNECTIVITY"
            fi
        else
            echo "○ IP $test_ip: NOT CONFIGURED"
        fi
    done
    
    # 7. Service Status
    echo -e "\n${GREEN}7. SERVICE STATUS${NC}"
    if systemctl is-active multi-ip-setup.service &>/dev/null; then
        echo "✓ multi-ip-setup.service: ACTIVE"
    else
        echo "✗ multi-ip-setup.service: INACTIVE"
    fi
    
    # 8. Firewall Check
    echo -e "\n${GREEN}8. FIREWALL CHECK${NC}"
    if command -v iptables >/dev/null; then
        iptables -L -n 2>/dev/null | grep -q "10.0.0" && echo "✓ Firewall rules for multi-IP found" || echo "⚠ No specific firewall rules for multi-IP"
    else
        echo "○ iptables not found"
    fi
    
    if command -v nft >/dev/null; then
        nft list ruleset 2>/dev/null | grep -q "10.0.0" && echo "✓ NFT rules for multi-IP found" || echo "⚠ No NFT rules for multi-IP"
    else
        echo "○ nft not found"
    fi
    
    # 9. Reverse Path Filtering
    echo -e "\n${GREEN}9. REVERSE PATH FILTERING${NC}"
    if [[ -f "/proc/sys/net/ipv4/conf/$INTERFACE/rp_filter" ]]; then
        rp_value=$(cat /proc/sys/net/ipv4/conf/"$INTERFACE"/rp_filter)
        echo "rp_filter for $INTERFACE: $rp_value (0=disabled, 1=strict, 2=loose)"
    else
        echo "○ rp_filter not available for $INTERFACE"
    fi
    
    # 10. Network Statistics
    echo -e "\n${GREEN}10. NETWORK STATISTICS${NC}"
    echo "Interface stats for $INTERFACE:"
    ip -s link show "$INTERFACE" | grep -E "RX|TX" | head -2
    
    echo -e "\n${YELLOW}=== DIAGNOSTIC COMPLETE ===${NC}"
    echo -e "\n${GREEN}RECOMMENDATIONS:${NC}"
    echo "• If SNAT detected: Contact your provider about IP routing"
    echo "• If no connectivity: Check firewall and routing tables"
    echo "• If tables missing: Run ./setup-multi-ip.sh"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

detect_network_config
run_diagnostic