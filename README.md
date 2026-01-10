# XDP Project - Network Filtering with eBPF

**High-speed network packet filtering system using XDP (eXpress Data Path) and eBPF.**

## Features

- **Kernel-level network filtering** using XDP/eBPF
- **Container system** with Docker for testing
- **Real-time monitoring** of blocked packets
- **Integrated diagnostic tools**
- **Flexible configuration** of filtering rules

## Architecture

```
┌─────────────────────────────────────────────────┐
│ HOST CONTAINER (172.20.0.10)                   │
│ ├── Servers: 80, 8080, 9090                    │
│ ├── XDP Program (filters port 8080)            │
│ └── Logs: /sys/kernel/debug/tracing/            │
└─────────────────────────────────────────────────┘
           ↑
       Docker Network
           ↓
┌─────────────────────────────────────────────────┐
│ CLIENT CONTAINER (172.20.0.20)                 │
│ └── Tools: nc, ping, curl, telnet               │
└─────────────────────────────────────────────────┘
```

## Quick Start

### 1. Build and Start

```bash
# Clone and enter the project
cd xdp-project

# Build containers
docker-compose build

# Start the complete system
docker-compose up -d

# Verify they are running
docker-compose ps
```

### 2. Verify Operation

```bash
# Automated tool (RECOMMENDED)
python3 scripts/xdp_monitor.py

# Or quick manual tests
./scripts/test_connection.sh
```

### 3. Test Filtering Manually

```bash
# Port 80 - ALLOWED
docker exec xdp_client nc -v 172.20.0.10 80
# → Result: Connection succeeded!

# Port 8080 - BLOCKED
docker exec xdp_client nc -w 3 -v 172.20.0.10 8080  
# → Result: timed out (blocked by XDP)

# Port 9090 - ALLOWED
docker exec xdp_client nc -v 172.20.0.10 9090
# → Result: Connection succeeded!
```

## XDP Message Monitoring

### View Real-time Logs

```bash
# Option 1: Automated monitor with statistics
python3 scripts/xdp_monitor.py

# Option 2: Real-time kernel logs
docker exec xdp_host cat /sys/kernel/debug/tracing/trace_pipe | grep "Blocked"

# Option 3: Interactive monitor
./scripts/monitor_xdp.sh
```

### XDP Log Examples

```bash
# When trying to connect to port 8080:
nc-15629 [013] ..s1. 1847.080025: bpf_trace_printk: Blocked TCP packet to port 8080
<idle>-0 [013] ..s.. 1848.097311: bpf_trace_printk: Blocked TCP packet to port 8080
```

## Included Tools

### Monitoring Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `scripts/xdp_monitor.py` | **Complete monitor** with statistics, logs and automatic tests | `python3 scripts/xdp_monitor.py` |
| `scripts/monitor_xdp.sh` | Interactive kernel log monitor with timestamps | `./scripts/monitor_xdp.sh` |
| `scripts/test_connection.sh` | Automated connectivity tests for all ports | `./scripts/test_connection.sh` |
| `scripts/ip_manager.py` | **Dynamic IP blocker** - add/remove IPs from blocking list | `python3 scripts/ip_manager.py add <IP>` |
| `scripts/manage_blocked_ips.sh` | **Interactive IP manager** with menu interface | `docker exec -it xdp_host manage_blocked_ips.sh` |
| `scripts/demo_ip_blocking.sh` | **Quick demo** of IP blocking functionality | `./scripts/demo_ip_blocking.sh` |
| `scripts/test_ip_blocking.sh` | **Comprehensive test suite** for IP blocking features | `./scripts/test_ip_blocking.sh` |

### Diagnostic Commands

```bash
# View loaded XDP program status
docker exec xdp_host ip link show eth0 | grep xdp

# View running server processes
docker exec xdp_host netstat -tlnp

# Check listening ports
docker exec xdp_host ps aux | grep nc

# View complete container logs
docker-compose logs -f host
```

## Customization

### Modify Filtering Rules

**File:** `xdp/xdp_filter.c`

```c
// Block additional ports
if (bpf_ntohs(tcp->dest) == 8080 || bpf_ntohs(tcp->dest) == 3389) {
    bpf_printk("Blocked port: %d\n", bpf_ntohs(tcp->dest));
    return XDP_DROP;
}

// Block by source IP
__u32 blocked_ip = bpf_htonl(0xC0A80164); // 192.168.1.100
if (ip->saddr == blocked_ip) {
    bpf_printk("Blocked IP: %x\n", bpf_ntohl(ip->saddr));
    return XDP_DROP;
}
```

### Recompile After Changes

```bash
# Enter the container
docker exec -it xdp_host bash

# Recompile XDP program
cd /xdp
make clean && make

# Reload XDP program
ip link set dev eth0 xdp off
python3 loader.py
```

### Block IPs Dynamically

```bash
# Enter host container
docker exec -it xdp_host bash

# Interactive IP management (recommended)
manage_blocked_ips.sh

# Or use commands directly:

# Block an IP
python3 /xdp/ip_manager.py add 172.20.0.20

# Unblock an IP
python3 /xdp/ip_manager.py remove 172.20.0.20

# List blocked IPs
python3 /xdp/ip_manager.py list

# Clear all blocked IPs
python3 /xdp/ip_manager.py clear
```

## Testing IP Blocking

### Quick Demo

```bash
# Run quick demonstration of IP blocking
./scripts/demo_ip_blocking.sh
```

### Comprehensive Testing

```bash
# Interactive test suite
./scripts/test_ip_blocking.sh

# Run all tests automatically
./scripts/test_ip_blocking.sh --auto

# Run comprehensive test with logs
./scripts/test_ip_blocking.sh --comprehensive
```

### Manual Testing

```bash
# 1. Block the client IP
docker exec xdp_host python3 /xdp/ip_manager.py add 172.20.0.20

# 2. Test connection (should fail)
docker exec xdp_client nc -v 172.20.0.10 80

# 3. Check logs
docker exec xdp_host cat /sys/kernel/debug/tracing/trace_pipe | grep "Blocked"

# 4. Unblock the IP
docker exec xdp_host python3 /xdp/ip_manager.py remove 172.20.0.20

# 5. Test connection (should work)
docker exec xdp_client nc -v 172.20.0.10 80
```

## Troubleshooting

### Verify System Status

```bash
# 1. Containers running
docker-compose ps

# 2. XDP loaded
docker exec xdp_host ip link show eth0 | grep xdp
# Should show: prog/xdp id XX

# 3. Servers listening
docker exec xdp_host netstat -tlnp
# Should show ports 80, 8080, 9090

# 4. DebugFS mounted
docker exec xdp_host ls /sys/kernel/debug/tracing/trace_pipe
```

### Common Problems

**XDP logs not visible:**
```bash
# Solution: Mount debugfs manually
docker exec xdp_host mount -t debugfs debugfs /sys/kernel/debug
```

**Servers not responding:**
```bash
# Solution: Verify and restart servers
docker exec xdp_host /usr/local/bin/start_servers.sh
```

**XDP not loaded:**
```bash
# Solution: Reload program
docker exec xdp_host python3 /xdp/loader.py
```

## Cleanup Commands

```bash
# Stop containers
docker-compose down

# Remove everything (containers + volumes)
docker-compose down -v

# Clean images (optional)
docker system prune -f
```

## Project Structure

```
xdp-project/
├── docker-compose.yml          # Container configuration
├── Dockerfile.host            # Image with eBPF tools
├── Dockerfile.client          # Client image for testing
├── README.md                  # This file
├── scripts/
│   ├── xdp_monitor.py        # Automated monitor
│   ├── monitor_xdp.sh        # Interactive monitor
│   └── test_connection.sh    # Connectivity tests
└── xdp/
    ├── xdp_filter.c          # XDP filter source code
    ├── loader.py             # Script to load XDP program
    └── Makefile              # eBPF program build
```

## System Requirements

- **Docker** and **Docker Compose**
- **Linux Kernel** with eBPF/XDP support (>= 4.8)
- **Privileges** to load eBPF programs

## Use Cases

- **High-speed network firewall**
- **Kernel-level DDoS protection**
- **IP/port traffic filtering**
- **eBPF/XDP technology learning**
- **Network solution prototyping**

---

**The XDP system is ready to filter traffic at kernel speed!**