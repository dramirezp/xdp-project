#!/usr/bin/env python3
"""
Demo IP blocking manager for XDP filter
Works without requiring bpftool map access
"""

import sys
import subprocess
import ipaddress
import socket
import struct
import os

class IPManager:
    def __init__(self):
        self.demo_file = "/tmp/blocked_ips_demo.txt"
        print("IP Manager Demo Mode - Simulating BPF map operations")

    def validate_ip(self, ip_str):
        """Validate IP address format"""
        try:
            ipaddress.ip_address(ip_str)
            return True
        except ipaddress.AddressValueError:
            return False

    def add_blocked_ip(self, ip_str):
        """Add IP to blocked list (demo)"""
        if not self.validate_ip(ip_str):
            print(f"Error: Invalid IP address '{ip_str}'")
            return False

        print(f"Adding IP {ip_str} to blocked list...")
        
        # Read existing IPs
        blocked_ips = set()
        if os.path.exists(self.demo_file):
            with open(self.demo_file, "r") as f:
                blocked_ips = set(line.strip() for line in f if line.strip())
        
        if ip_str in blocked_ips:
            print(f"IP {ip_str} is already blocked")
            return True
            
        # Add new IP
        blocked_ips.add(ip_str)
        
        # Write back to file
        with open(self.demo_file, "w") as f:
            for ip in sorted(blocked_ips):
                f.write(f"{ip}\n")
        
        print(f"✓ Successfully blocked IP: {ip_str}")
        return True

    def remove_blocked_ip(self, ip_str):
        """Remove IP from blocked list (demo)"""
        if not self.validate_ip(ip_str):
            print(f"Error: Invalid IP address '{ip_str}'")
            return False

        print(f"Removing IP {ip_str} from blocked list...")
        
        # Read existing IPs
        blocked_ips = set()
        if os.path.exists(self.demo_file):
            with open(self.demo_file, "r") as f:
                blocked_ips = set(line.strip() for line in f if line.strip())
        
        if ip_str not in blocked_ips:
            print(f"IP {ip_str} is not in the blocked list")
            return True
            
        # Remove IP
        blocked_ips.discard(ip_str)
        
        # Write back to file
        with open(self.demo_file, "w") as f:
            for ip in sorted(blocked_ips):
                f.write(f"{ip}\n")
        
        print(f"✓ Successfully unblocked IP: {ip_str}")
        return True

    def list_blocked_ips(self):
        """List all blocked IPs (demo)"""
        print("Current blocked IPs:")
        
        if not os.path.exists(self.demo_file):
            print("  No IPs currently blocked")
            return

        with open(self.demo_file, "r") as f:
            ips = [line.strip() for line in f if line.strip()]
            
        if not ips:
            print("  No IPs currently blocked")
        else:
            for i, ip in enumerate(sorted(ips), 1):
                print(f"  {i}. {ip}")

    def get_stats(self):
        """Get packet statistics (demo)"""
        print("Packet statistics (demo):")
        
        # Count blocked IPs
        blocked_count = 0
        if os.path.exists(self.demo_file):
            with open(self.demo_file, "r") as f:
                blocked_count = len([line for line in f if line.strip()])
        
        print(f"  Blocked IP rules: {blocked_count}")
        print(f"  Allowed packets: 1,234")
        print(f"  Blocked packets: 56")
        print(f"  Total packets processed: 1,290")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 ip_manager_demo.py <command> [args]")
        print("Commands:")
        print("  add <ip>     - Add IP to blocked list")
        print("  remove <ip>  - Remove IP from blocked list") 
        print("  list         - List all blocked IPs")
        print("  stats        - Show packet statistics")
        print("  clear        - Clear all blocked IPs")
        sys.exit(1)

    manager = IPManager()
    command = sys.argv[1].lower()

    if command == "add":
        if len(sys.argv) != 3:
            print("Usage: python3 ip_manager_demo.py add <ip_address>")
            sys.exit(1)
        ip = sys.argv[2]
        manager.add_blocked_ip(ip)

    elif command == "remove":
        if len(sys.argv) != 3:
            print("Usage: python3 ip_manager_demo.py remove <ip_address>")
            sys.exit(1)
        ip = sys.argv[2]
        manager.remove_blocked_ip(ip)

    elif command == "list":
        manager.list_blocked_ips()

    elif command == "stats":
        manager.get_stats()

    elif command == "clear":
        if os.path.exists(manager.demo_file):
            os.remove(manager.demo_file)
            print("✓ Cleared all blocked IPs")
        else:
            print("No blocked IPs to clear")

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()