#!/bin/bash

echo "🚀 XDP IP Blocking Quick Demo"
echo "============================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLIENT_IP="172.20.0.20"
HOST_IP="172.20.0.10"

echo ""
echo -e "${BLUE}Step 1: Testing normal connection${NC}"
echo "Command: docker exec xdp_client nc -w 2 -v $HOST_IP 80"
echo "Expected: Should work"
echo ""

if docker exec xdp_client nc -w 2 -v $HOST_IP 80 2>&1 | grep -q "succeeded"; then
    echo -e "${GREEN}✓ Connection works normally${NC}"
else
    echo -e "${RED}✗ Baseline connection failed - check your setup${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Blocking client IP ($CLIENT_IP)${NC}"
echo "Command: docker exec xdp_host python3 /xdp/ip_manager.py add $CLIENT_IP"
echo ""

docker exec xdp_host python3 /xdp/ip_manager.py add $CLIENT_IP

echo ""
echo -e "${BLUE}Step 3: Testing blocked connection${NC}"
echo "Command: docker exec xdp_client nc -w 3 -v $HOST_IP 80"
echo "Expected: Should timeout/fail"
echo ""

if docker exec xdp_client nc -w 3 -v $HOST_IP 80 2>&1 | grep -q -E "timed out|failed|refused"; then
    echo -e "${GREEN}✓ Connection blocked successfully!${NC}"
    BLOCKED=true
else
    echo -e "${RED}✗ Connection should have been blocked but wasn't${NC}"
    BLOCKED=false
fi

echo ""
echo -e "${BLUE}Step 4: Checking logs for blocked packets${NC}"
echo "Looking for blocked packet messages..."
echo ""

# Try to capture some blocked traffic logs
docker exec xdp_host timeout 2 cat /sys/kernel/debug/tracing/trace_pipe | grep "Blocked" &
LOG_PID=$!

# Generate some traffic to trigger logs
docker exec xdp_client nc -w 1 $HOST_IP 80 &>/dev/null &
sleep 1

wait $LOG_PID 2>/dev/null || echo "No logs captured (this is normal if no new blocked packets)"

echo ""
echo -e "${BLUE}Step 5: Listing blocked IPs${NC}"
echo "Command: docker exec xdp_host python3 /xdp/ip_manager.py list"
echo ""

docker exec xdp_host python3 /xdp/ip_manager.py list

echo ""
echo -e "${BLUE}Step 6: Unblocking the IP${NC}"
echo "Command: docker exec xdp_host python3 /xdp/ip_manager.py remove $CLIENT_IP"
echo ""

docker exec xdp_host python3 /xdp/ip_manager.py remove $CLIENT_IP

echo ""
echo -e "${BLUE}Step 7: Testing connection after unblocking${NC}"
echo "Command: docker exec xdp_client nc -w 2 -v $HOST_IP 80"
echo "Expected: Should work again"
echo ""

sleep 1

if docker exec xdp_client nc -w 2 -v $HOST_IP 80 2>&1 | grep -q "succeeded"; then
    echo -e "${GREEN}✓ Connection works after unblocking${NC}"
    UNBLOCKED=true
else
    echo -e "${RED}✗ Connection failed after unblocking${NC}"
    UNBLOCKED=false
fi

echo ""
echo -e "${YELLOW}================== DEMO SUMMARY ==================${NC}"
echo ""

if [ "$BLOCKED" = true ] && [ "$UNBLOCKED" = true ]; then
    echo -e "${GREEN}🎉 SUCCESS! Dynamic IP blocking is working perfectly!${NC}"
    echo ""
    echo -e "${GREEN}✓${NC} Normal connection worked"
    echo -e "${GREEN}✓${NC} IP blocking worked"
    echo -e "${GREEN}✓${NC} IP unblocking worked"
    echo ""
    echo "Your XDP dynamic IP blocking system is fully functional!"
else
    echo -e "${RED}❌ Some tests failed. Please check your setup.${NC}"
    echo ""
    [ "$BLOCKED" != true ] && echo -e "${RED}✗${NC} IP blocking didn't work"
    [ "$UNBLOCKED" != true ] && echo -e "${RED}✗${NC} IP unblocking didn't work"
fi

echo ""
echo -e "${BLUE}To run more comprehensive tests:${NC}"
echo "  ./scripts/test_ip_blocking.sh"
echo ""
echo -e "${BLUE}To manually manage IPs:${NC}"
echo "  docker exec -it xdp_host manage_blocked_ips.sh"