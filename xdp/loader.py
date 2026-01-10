#!/usr/bin/env python3
import os
import sys
import time
import socket
import struct
from pyroute2 import IPRoute

def load_xdp_program():
    # Compile XDP program
    os.chdir('/xdp')
    os.system('make clean && make')
    
    if not os.path.exists('xdp_filter.o'):
        print("Error: Could not compile xdp_filter.o")
        sys.exit(1)
    
    # Get network interface
    ipr = IPRoute()
    
    # Find eth0 interface
    idx = None
    for link in ipr.get_links():
        if link.get_attr('IFLA_IFNAME') == 'eth0':
            idx = link['index']
            break
    
    if idx is None:
        print("Error: eth0 interface not found")
        sys.exit(1)
    
    print(f"Loading XDP program on eth0 interface (index: {idx})")
    
    # Load XDP program using ip link with pinned maps
    cmd = f"ip link set dev eth0 xdp obj xdp_filter.o sec xdp"
    result = os.system(cmd)
    
    if result == 0:
        print("XDP program loaded successfully")
        
        # Pin the maps for external access
        time.sleep(1)  # Wait for maps to be created
        
        # Get the program ID
        get_prog_cmd = "ip link show eth0 | grep 'prog/xdp id' | awk '{print $4}'"
        prog_id_output = os.popen(get_prog_cmd).read().strip()
        
        if prog_id_output:
            print(f"XDP program ID: {prog_id_output}")
            
            # Pin maps for external access
            os.makedirs("/sys/fs/bpf/xdp_filter", exist_ok=True)
            
            # We'll use a different approach - save the program ID for ip_manager
            with open("/tmp/xdp_prog_id", "w") as f:
                f.write(prog_id_output)
        
        print("\nStatistics available at:")
        print("  - /sys/fs/bpf/")
        print("\nTo view logs: cat /sys/kernel/debug/tracing/trace_pipe")
    else:
        print("Error loading XDP program")
        sys.exit(1)

if __name__ == '__main__':
    load_xdp_program()
    
    print("\n--- XDP Program Active ---")
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping...")