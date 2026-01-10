#!/bin/bash

# Automated demo of XDP system
# Runs a complete packet filtering demonstration

set -e  # Exit on any error

echo "🚀 === XDP FILTERING SYSTEM DEMO === 🚀"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Start containers
print_step "Step 1: Starting containers..."
docker-compose down -q 2>/dev/null || true
docker-compose up -d --build
sleep 5

if docker-compose ps | grep -q "Up"; then
    print_success "Containers started successfully"
else
    print_error "Error starting containers"
    exit 1
fi

# Step 2: Load XDP program
print_step "Step 2: Loading XDP program..."
docker exec xdp_host bash -c "cd /xdp && python3 loader.py" || {
    print_error "Error loading XDP program"
    exit 1
}
print_success "XDP program loaded"

sleep 2

# Step 3: Verify XDP status
print_step "Step 3: Verifying XDP program status..."
XDP_INFO=$(docker exec xdp_host ip link show eth0 | grep "prog/xdp" || true)
if [ ! -z "$XDP_INFO" ]; then
    echo "   $XDP_INFO"
    print_success "XDP active on eth0 interface"
else
    print_warning "XDP program not detected as loaded"
fi

# Step 4: Start test servers
print_step "Step 4: Starting test servers..."
docker exec -d xdp_host python3 -m http.server 8080 >/dev/null 2>&1  # Should be blocked
docker exec -d xdp_host python3 -m http.server 8081 >/dev/null 2>&1  # Should work
sleep 3
print_success "Servers started (port 8080 and 8081)"

# Step 5: Test blocked port 8080
print_step "Step 5: Testing port 8080 (MUST be blocked)..."
if timeout 3 docker exec xdp_client nc 172.20.0.10 8080 >/dev/null 2>&1; then
    print_error "Port 8080 is NOT blocked - check XDP configuration"
else
    print_success "Port 8080 correctly blocked by XDP"
fi

# Step 6: Test allowed port 8081  
print_step "Step 6: Testing port 8081 (MUST be allowed)..."
if docker exec xdp_client curl -s -m 3 http://172.20.0.10:8081/ >/dev/null 2>&1; then
    print_success "Port 8081 works correctly"
else
    print_warning "Port 8081 not responding - possible network issue"
fi

# Step 7: Setup IP management tool
print_step "Step 7: Setting up IP management tool..."
docker cp scripts/ip_manager_demo.py xdp_host:/xdp/ || {
    print_error "Error copying ip_manager_demo.py"
    exit 1
}
print_success "IP management tool configured"

# Step 8: Demo IP blocking
print_step "Step 8: Demonstrating dynamic IP management..."
echo "   Adding IP 192.168.1.100 to blocked list..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py add 192.168.1.100

echo "   Adding IP 10.0.0.5 to blocked list..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py add 10.0.0.5

print_success "IPs added to blocked list"

# Step 9: Show blocked IPs
print_step "Step 9: Showing blocked IPs..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py list

# Step 10: Show statistics
print_step "Step 10: Showing system statistics..."
docker exec xdp_host python3 /xdp/ip_manager_demo.py stats

# Step 11: Show logs
print_step "Step 11: Showing system logs (last 5 entries)..."
echo -e "${YELLOW}Packet blocking logs:${NC}"
docker exec xdp_host timeout 1 cat /sys/kernel/debug/tracing/trace_pipe 2>/dev/null | tail -5 || echo "   (No recent logs)"

echo
echo "🎉 === DEMO COMPLETED === 🎉"
echo
echo -e "${BLUE}Useful commands for further exploration:${NC}"
echo "• View real-time logs:"
echo "  docker exec xdp_host cat /sys/kernel/debug/tracing/trace_pipe"
echo
echo "• Manage blocked IPs:"
echo "  docker exec xdp_host python3 /xdp/ip_manager_demo.py [add|remove|list|stats] [IP]"
echo
echo "• Test connections:"
echo "  docker exec xdp_client nc 172.20.0.10 8080    # Blocked"
echo "  docker exec xdp_client curl http://172.20.0.10:8081/  # Allowed"
echo
echo "• Clean environment:"
echo "  docker-compose down"
echo

print_success "Demo completed successfully!"