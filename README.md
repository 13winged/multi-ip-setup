# Multi-IP Setup Scripts

A set of scripts for automatic configuration of multiple IP addresses on a single network interface in Linux.

## 🚀 Features

- Automatic configuration of multiple IP addresses
- Source-based routing
- Persistence via systemd
- Diagnostics and monitoring
- Automatic problem fixing
- Provider issue detection

## 📋 Requirements

- Linux (Ubuntu/Debian/CentOS/RHEL)
- Root access
- Multiple IP addresses from your provider
- Basic networking knowledge

## 🛠️ Quick Start

```bash
# Clone repository
git clone https://github.com/13winged/multi-ip-setup.git
cd multi-ip-setup

# Make scripts executable
chmod +x *.sh

# Run setup (automatically detects your network configuration)
./setup-multi-ip.sh

# Run diagnostics
./diagnose-network.sh

# Fix common issues
./fix-routing.sh
```

## 📁 Project Structure

```
multi-ip-setup/
├── setup-multi-ip.sh          # Main setup script
├── diagnose-network.sh        # Network diagnostics
├── fix-routing.sh             # Problem fixing
├── config.env                 # Configuration template
├── LICENSE                    # MIT License
├── README.md                  # English documentation
├── README_ru.md              # Russian documentation
└── examples/                  # Configuration examples
    ├── 3x-ui-config.json     # 3x-ui configuration
    ├── nginx-multi-ip.conf   # Nginx multiple IP setup
    └── wireguard-multi-ip.conf # WireGuard with multiple IPs
```

## ⚙️ Configuration

### Automatic Detection
The scripts automatically detect your network configuration. Manual configuration is optional.

### Manual Configuration (if needed)
Edit `config.env` or variables in scripts:

```bash
# Network Interface (auto-detected)
INTERFACE="eth0"

# Main IP and Gateway (auto-detected)          
MAIN_IP="192.168.1.100"
MAIN_GW="192.168.1.1"

# Additional IP subnet
SUBNET="10.0.0.0/24"
START_IP=1
END_IP=254

# Routing tables range
TABLE_START=1001
```

## 🎯 Usage

### Full Automatic Setup
```bash
./setup-multi-ip.sh
```

### Step-by-Step Setup
```bash
./setup-multi-ip.sh backup     # Create backup
./setup-multi-ip.sh setup      # Run setup
./setup-multi-ip.sh diagnose   # Verify setup
```

### Diagnostics
```bash
# Basic diagnostics
./diagnose-network.sh

# Diagnostics for specific interface
./diagnose-network.sh eth0
```

### Fix Common Issues
```bash
./fix-routing.sh
```

## 🔧 Manual Commands

If you prefer manual setup or troubleshooting:

```bash
# Add IP address
ip addr add 10.0.0.1/32 dev eth0 label eth0:10

# Create routing table
ip route add default via 192.168.1.1 dev eth0 table 1001 src 10.0.0.1

# Add routing rule
ip rule add from 10.0.0.1 table 1001

# Disable reverse path filter
sysctl -w net.ipv4.conf.eth0.rp_filter=0
```

## 🐛 Troubleshooting

### Common Issues

1. **IPs not routing externally**
   - Check provider support for multiple IPs
   - Verify IPs are not behind NAT
   - Run `./diagnose-network.sh`

2. **Connectivity issues**
   - Check firewall rules
   - Verify routing tables
   - Test with `curl --interface 10.0.0.1 http://ifconfig.me/`

3. **Script errors**
   - Ensure running as root
   - Check interface name
   - Verify IP addresses are assigned

### Diagnostic Commands

```bash
# Check IP addresses
ip addr show dev eth0

# Check routing tables
ip route show table 1001

# Check routing rules  
ip rule show

# Test connectivity per IP
curl --interface 10.0.0.1 http://ifconfig.me/
```

## 📊 What the Scripts Do

### setup-multi-ip.sh
- Creates backup of current configuration
- Adds multiple IP addresses to interface
- Sets up source-based routing tables
- Configures routing rules
- Disables reverse path filtering
- Creates systemd service for persistence

### diagnose-network.sh
- Checks system information
- Verifies interface configuration
- Tests routing tables and rules
- Tests connectivity for each IP
- Detects SNAT issues (provider problems)
- Checks firewall and service status

### fix-routing.sh
- Fixes broken routing tables
- Resets firewall rules
- Reapplies routing configuration
- Disables restrictive network settings

## ⚠️ Important Notes

1. **Provider Support**: Your hosting provider must support multiple routable IPs
2. **IP Availability**: Additional IPs must be assigned to your server
3. **Backup**: Always backup before making network changes
4. **Testing**: Test in non-production environment first
5. **Persistence**: Scripts create systemd service for boot-time setup

## 🛡️ Security Considerations

- Scripts include firewall rule examples
- Reverse path filtering is disabled (required for multi-IP)
- Consider additional security measures for production use
- Monitor network traffic when using multiple IPs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🐛 Reporting Issues

If you encounter any issues:

1. Check existing issues on GitHub
2. Run `./diagnose-network.sh` and include output
3. Provide your system information
4. Describe steps to reproduce the issue

## 🔗 Useful Links

- [Linux IP Command Guide](https://linux.die.net/man/8/ip)
- [Source-Based Routing](https://www.tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.rpdb.html)
- [Multiple IP Configuration](https://www.kernel.org/doc/Documentation/networking/multi-ip.txt)