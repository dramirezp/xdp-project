#!/bin/bash

echo "=== XDP Connectivity Tests ==="
echo ""

echo "1. Ping to host (should work):"
docker exec xdp_client ping -c 3 172.20.0.10
echo ""

echo "2. Connection to port 80 (ALLOWED - should work):"
docker exec xdp_client bash -c "echo 'GET / HTTP/1.0' | nc 172.20.0.10 80" 2>&1
echo ""

echo "3. Connection to port 8080 (BLOCKED by XDP - should fail):"
timeout 3 docker exec xdp_client bash -c "echo 'GET / HTTP/1.0' | nc 172.20.0.10 8080" 2>&1 || echo "Timeout - port blocked by XDP"
echo ""

echo "4. Connection to port 9090 (ALLOWED - should work):"
docker exec xdp_client bash -c "echo 'GET / HTTP/1.0' | nc 172.20.0.10 9090" 2>&1
echo ""

echo "5. View XDP statistics (last 10 lines):"
docker exec xdp_host timeout 2 cat /sys/kernel/debug/tracing/trace_pipe 2>/dev/null | tail -n 10 || echo "No recent events"
echo ""

echo "=== Summary ==="
echo "Port 80:   ALLOWED (XDP_PASS)"
echo "Port 8080: BLOCKED (XDP_DROP)"
echo "Port 9090: ALLOWED (XDP_PASS)"