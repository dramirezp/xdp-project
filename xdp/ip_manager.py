#!/usr/bin/env python3
"""
Dynamic IP Blocker for XDP
Allows adding/removing IPs from the blocked_ips BPF map
"""

import sys
import struct
import socket
import subprocess
import json
from pathlib import Path

class XDPIPManager:
    def __init__(self):
        self.map_path = "/sys/fs/bpf"
        
    def ip_to_int(self, ip_str):
        """Convert IP string to network byte order integer"""
        return struct.unpack("!I", socket.inet_aton(ip_str))[0]
    
    def int_to_ip(self, ip_int):
        """Convert network byte order integer to IP string"""
        return socket.inet_ntoa(struct.pack("!I", ip_int))
    
    def run_command(self, cmd):
        """Execute shell command and return output"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.stdout.strip(), result.stderr.strip(), result.returncode
        except Exception as e:
            return "", str(e), 1
    
    def find_blocked_ips_map(self):
        """Find the blocked_ips map ID"""
        cmd = "bpftool map list | grep blocked_ips"
        stdout, stderr, code = self.run_command(cmd)
        
        if code != 0:
            # Try alternative method using map listing
            cmd = "bpftool map list"
            stdout, stderr, code = self.run_command(cmd)
            
            if code == 0:
                lines = stdout.split('\n')
                for i, line in enumerate(lines):
                    if 'hash' in line and 'key 4' in line:
                        # Check next few lines for clues
                        map_id = line.split(':')[0].strip()
                        return map_id
        else:
            # Extract map ID from output
            map_id = stdout.split(':')[0].strip()
            return map_id
            
        return None
    
    def add_blocked_ip(self, ip):
        """Add IP to blocked list"""
        print(f"Adding IP {ip} to blocked list...")
        
        map_id = self.find_blocked_ips_map()
        if not map_id:
            print("Error: Could not find blocked_ips BPF map")
            print("Make sure XDP program is loaded")
            return False
        
        ip_int = self.ip_to_int(ip)
        
        # Use bpftool to update map
        cmd = f"bpftool map update id {map_id} key hex {ip_int:08x} value hex 01"
        stdout, stderr, code = self.run_command(cmd)
        
        if code == 0:
            print(f"✓ Successfully blocked IP: {ip}")
            return True
        else:
            print(f"✗ Error blocking IP: {stderr}")
            return False
    
    def remove_blocked_ip(self, ip):
        """Remove IP from blocked list"""
        print(f"Removing IP {ip} from blocked list...")
        
        map_id = self.find_blocked_ips_map()
        if not map_id:
            print("Error: Could not find blocked_ips BPF map")
            return False
        
        ip_int = self.ip_to_int(ip)
        
        # Use bpftool to delete from map
        cmd = f"bpftool map delete id {map_id} key hex {ip_int:08x}"
        stdout, stderr, code = self.run_command(cmd)
        
        if code == 0:
            print(f"✓ Successfully unblocked IP: {ip}")
            return True
        else:
            print(f"✗ Error unblocking IP: {stderr}")
            return False
    
    def list_blocked_ips(self):
        """List all blocked IPs"""
        print("Listing blocked IPs...")
        
        map_id = self.find_blocked_ips_map()
        if not map_id:
            print("Error: Could not find blocked_ips BPF map")
            return
        
        # Use bpftool to dump map
        cmd = f"bpftool map dump id {map_id}"
        stdout, stderr, code = self.run_command(cmd)
        
        if code == 0:
            if not stdout.strip():
                print("No IPs currently blocked")
                return
            
            print("Currently blocked IPs:")
            print("-" * 30)
            
            # Parse bpftool output
            lines = stdout.split('\n')
            for line in lines:
                if 'key:' in line:
                    # Extract hex key and convert to IP
                    try:
                        key_part = line.split('key:')[1].split('value:')[0].strip()
                        # Remove hex formatting
                        hex_key = key_part.replace(' ', '')
                        ip_int = int(hex_key, 16)
                        ip = self.int_to_ip(ip_int)
                        print(f"  - {ip}")
                    except Exception as e:
                        print(f"  - Could not parse: {line}")
        else:
            print(f"Error listing blocked IPs: {stderr}")
    
    def clear_all_blocked_ips(self):
        """Clear all blocked IPs"""
        print("Clearing all blocked IPs...")
        
        map_id = self.find_blocked_ips_map()
        if not map_id:
            print("Error: Could not find blocked_ips BPF map")
            return False
        
        # First get all keys
        cmd = f"bpftool map dump id {map_id}"
        stdout, stderr, code = self.run_command(cmd)
        
        if code != 0:
            print(f"Error reading map: {stderr}")
            return False
        
        # Extract and delete each key
        lines = stdout.split('\n')
        deleted_count = 0
        
        for line in lines:
            if 'key:' in line:
                try:
                    key_part = line.split('key:')[1].split('value:')[0].strip()
                    hex_key = key_part.replace(' ', '')
                    
                    # Delete this key
                    cmd = f"bpftool map delete id {map_id} key hex {hex_key}"
                    _, _, code = self.run_command(cmd)
                    if code == 0:
                        deleted_count += 1
                except Exception:
                    continue
        
        print(f"✓ Cleared {deleted_count} blocked IPs")
        return True

def print_usage():
    """Print usage information"""
    print("XDP Dynamic IP Blocker")
    print("=" * 30)
    print("Usage: python3 ip_manager.py <command> [arguments]")
    print("")
    print("Commands:")
    print("  add <IP>     - Block an IP address")
    print("  remove <IP>  - Unblock an IP address")
    print("  list         - List all blocked IPs")
    print("  clear        - Clear all blocked IPs")
    print("")
    print("Examples:")
    print("  python3 ip_manager.py add 192.168.1.100")
    print("  python3 ip_manager.py remove 192.168.1.100")
    print("  python3 ip_manager.py list")
    print("  python3 ip_manager.py clear")

def main():
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
    
    manager = XDPIPManager()
    command = sys.argv[1].lower()
    
    if command == "add":
        if len(sys.argv) != 3:
            print("Error: Please provide an IP address")
            print("Usage: python3 ip_manager.py add <IP>")
            sys.exit(1)
        
        ip = sys.argv[2]
        try:
            socket.inet_aton(ip)  # Validate IP format
            manager.add_blocked_ip(ip)
        except socket.error:
            print(f"Error: Invalid IP address format: {ip}")
    
    elif command == "remove":
        if len(sys.argv) != 3:
            print("Error: Please provide an IP address")
            print("Usage: python3 ip_manager.py remove <IP>")
            sys.exit(1)
        
        ip = sys.argv[2]
        try:
            socket.inet_aton(ip)  # Validate IP format
            manager.remove_blocked_ip(ip)
        except socket.error:
            print(f"Error: Invalid IP address format: {ip}")
    
    elif command == "list":
        manager.list_blocked_ips()
    
    elif command == "clear":
        manager.clear_all_blocked_ips()
    
    else:
        print(f"Error: Unknown command '{command}'")
        print_usage()
        sys.exit(1)

if __name__ == "__main__":
    main()