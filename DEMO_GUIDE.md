# Complete Demo - XDP Filtering System

## Step-by-Step Guide to Run the Demonstration

### Prerequisites
- Docker and docker-compose installed
- Linux system (macOS with Docker works)
- Privileges to run containers with network capabilities

---

## 🚀 Demonstration Steps

### 1. Prepare the Environment

```bash
# Navigate to project directory
cd /Users/dramirez/ws/xdp-project

# Build Docker images
docker-compose build

# Start containers
docker-compose up -d

# Verify containers are running
docker-compose ps
```

### 2. Load XDP Program

```bash
# Enter host container
docker exec -it xdp_host bash

# Load XDP program
cd /xdp
python3 loader.py
```

**Expected result:**
```
Loading XDP program on eth0 interface (index: 11)
XDP program loaded successfully
XDP program ID: 64

--- XDP Program Active ---
```

### 3. Verify XDP Program Status

```bash
# Inside host container, verify XDP is loaded
ip link show eth0
```

**Expected result:**
```
11: eth0@if45: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 xdp qdisc noqueue state UP mode DEFAULT group default 
    prog/xdp id 64 tag 078d1e08a3cce870 jited
```

### 4. Test Port 8080 Blocking

#### Create server on port 8080 (blocked):
```bash
# In host container
python3 -m http.server 8080 &
```

#### Test connection from client:
```bash
# Open new terminal and test from client
docker exec xdp_client timeout 5 nc 172.20.0.10 8080

# Result: Connection is blocked (timeout)
```

### 5. Verify Other Ports Work

#### Create server on port 8081 (allowed):
```bash
# In host container
python3 -m http.server 8081 &
```

#### Test connection:
```bash
# From client
docker exec xdp_client curl -m 3 http://172.20.0.10:8081/
```

**Expected result:** Complete HTTP response (HTML page)

### 6. Monitor XDP System Logs

```bash
# In host container, view real-time logs
cat /sys/kernel/debug/tracing/trace_pipe
```

**Expected result:**
```
Blocked TCP packet to port 8080
Blocked TCP packet to port 8080
...
```

### 7. Dynamic IP Management (Demo)

```bash
# Copy management tool
docker cp scripts/ip_manager_demo.py xdp_host:/xdp/

# Enter host container
docker exec -it xdp_host bash
cd /xdp

# Add IPs to blocked list
python3 ip_manager_demo.py add 192.168.1.100
python3 ip_manager_demo.py add 10.0.0.5

# List blocked IPs
python3 ip_manager_demo.py list

# View statistics
python3 ip_manager_demo.py stats
```

**Expected result:**
```
✓ Successfully blocked IP: 192.168.1.100
✓ Successfully blocked IP: 10.0.0.5

Current blocked IPs:
  1. 10.0.0.5
  2. 192.168.1.100

Packet statistics (demo):
  Blocked IP rules: 2
  Allowed packets: 1,234
  Blocked packets: 56
```

---

## 🎯 Complete Demo Script

### Automated Demonstration Script

```bash
#!/bin/bash
echo "=== DEMO XDP PACKET FILTER ==="
echo

echo "1. Starting containers..."
docker-compose up -d
sleep 5

echo "2. Loading XDP program..."
docker exec xdp_host bash -c "cd /xdp && python3 loader.py"
sleep 2

echo "3. Verifying XDP status..."
docker exec xdp_host ip link show eth0 | grep xdp

echo "4. Starting test servers..."
docker exec -d xdp_host python3 -m http.server 8080  # Blocked
docker exec -d xdp_host python3 -m http.server 8081  # Allowed
sleep 2

echo "5. Testing port 8080 (BLOCKED)..."
timeout 3 docker exec xdp_client nc 172.20.0.10 8080 || echo "   ❌ Port 8080 blocked correctly"

echo "6. Testing port 8081 (ALLOWED)..."
docker exec xdp_client curl -s -m 3 http://172.20.0.10:8081/ | head -1 && echo "   ✅ Port 8081 works correctly"

echo "7. Copying IP management tool..."
docker cp scripts/ip_manager_demo.py xdp_host:/xdp/

echo "8. Adding IPs to blocked list..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py add 192.168.1.100
docker exec xdp_host python3 /xdp/ip_manager_demo.py add 10.0.0.5

echo "9. Showing blocked IPs..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py list

echo "10. System statistics..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py stats

echo
echo "=== DEMO COMPLETED ==="
echo "To view real-time logs: docker exec xdp_host cat /sys/kernel/debug/tracing/trace_pipe"
echo "To clean up: docker-compose down"
```

---

## 🔍 Key Points for Demonstration

### Show During Demo:

1. **XDP Program Compilation**: C code compiles automatically
2. **Kernel Loading**: Program installs on network interface
3. **Selective Filtering**: Port 8080 blocked, other ports work
4. **Real-time Logging**: Kernel messages about blocked packets
5. **Dynamic Management**: Add/remove IPs without restart

### System Architecture:
```
┌─────────────────┐   Bridge Network  ┌─────────────────┐
│     Client      │   172.20.0.0/16   │      Host       │
│  172.20.0.20    │ ◄────────────────► │  172.20.0.10    │
│                 │                   │                 │
│ - curl          │                   │ - XDP Program   │
│ - netcat        │                   │ - HTTP Servers  │
│ - test tools    │                   │ - IP Manager    │
└─────────────────┘                   └─────────────────┘
                                              │
                                              ▼
                                      ┌─────────────────┐
                                      │  Kernel Space   │
                                      │                 │
                                      │ XDP Filter:     │
                                      │ - Block port 8080│
                                      │ - Block IPs     │
                                      │ - Count packets │
                                      └─────────────────┘
```

### To Clean Up After Demo:
```bash
# Stop containers
docker-compose down

# Clean images (optional)
docker system prune
```

This demo shows a complete kernel-level packet filtering system using XDP/eBPF with dynamic management and real-time monitoring.