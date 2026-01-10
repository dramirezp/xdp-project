#!/bin/bash

# XDP Dynamic IP Management Helper Script

echo "XDP Dynamic IP Blocker"
echo "======================"

# Check if XDP is loaded
if ! ip link show eth0 | grep -q "xdp"; then
    echo "❌ XDP program is not loaded!"
    echo "Please run: python3 /xdp/loader.py"
    exit 1
fi

echo "✅ XDP program is active"

# Check if bpftool is available
if ! command -v bpftool &> /dev/null; then
    echo "❌ bpftool is not available"
    echo "Installing bpftool..."
    apt-get update && apt-get install -y linux-tools-common linux-tools-generic 2>/dev/null
fi

echo ""
echo "Available commands:"
echo "==================="
echo ""
echo "Block an IP:"
echo "  python3 /xdp/ip_manager.py add <IP>"
echo "  Example: python3 /xdp/ip_manager.py add 172.20.0.20"
echo ""
echo "Unblock an IP:"
echo "  python3 /xdp/ip_manager.py remove <IP>"
echo "  Example: python3 /xdp/ip_manager.py remove 172.20.0.20"
echo ""
echo "List blocked IPs:"
echo "  python3 /xdp/ip_manager.py list"
echo ""
echo "Clear all blocked IPs:"
echo "  python3 /xdp/ip_manager.py clear"
echo ""
echo "Quick actions:"
echo "=============="

# Provide quick menu
while true; do
    echo ""
    echo "What would you like to do?"
    echo "1) Block the client IP (172.20.0.20)"
    echo "2) List blocked IPs"
    echo "3) Clear all blocked IPs"
    echo "4) Custom IP blocking"
    echo "5) Exit"
    
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1)
            echo "Blocking client IP 172.20.0.20..."
            python3 /xdp/ip_manager.py add 172.20.0.20
            ;;
        2)
            python3 /xdp/ip_manager.py list
            ;;
        3)
            python3 /xdp/ip_manager.py clear
            ;;
        4)
            read -p "Enter IP to block: " ip
            if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                python3 /xdp/ip_manager.py add $ip
            else
                echo "Invalid IP format"
            fi
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done