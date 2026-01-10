#!/bin/bash

echo "=========================================="
echo "XDP Dynamic IP Blocking Test Suite"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
CLIENT_IP="172.20.0.20"
HOST_IP="172.20.0.10"
TEST_PORT="80"

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

test_connection() {
    local description="$1"
    local expected="$2" # "success" or "fail"
    
    echo ""
    echo "Testing: $description"
    echo "Expected: $expected"
    echo "Command: docker exec xdp_client nc -w 2 -v $HOST_IP $TEST_PORT"
    
    if docker exec xdp_client nc -w 2 -v $HOST_IP $TEST_PORT 2>&1 | grep -q "succeeded"; then
        if [ "$expected" = "success" ]; then
            print_success "Connection succeeded as expected"
            return 0
        else
            print_error "Connection succeeded but should have failed!"
            return 1
        fi
    else
        if [ "$expected" = "fail" ]; then
            print_success "Connection failed as expected (IP blocked)"
            return 0
        else
            print_error "Connection failed but should have succeeded!"
            return 1
        fi
    fi
}

check_xdp_status() {
    print_step "Checking XDP program status..."
    
    if docker exec xdp_host ip link show eth0 | grep -q "xdp"; then
        print_success "XDP program is loaded"
        docker exec xdp_host ip link show eth0 | grep xdp
    else
        print_error "XDP program is not loaded!"
        echo "Please run: docker-compose up -d"
        exit 1
    fi
}

test_baseline_connectivity() {
    print_step "Testing baseline connectivity (before any blocking)..."
    
    # Clear any existing blocked IPs first
    docker exec xdp_host python3 /xdp/ip_manager.py clear &>/dev/null
    
    test_connection "Baseline connection to port $TEST_PORT" "success"
}

test_dynamic_ip_blocking() {
    print_step "Testing dynamic IP blocking functionality..."
    
    echo ""
    print_info "Phase 1: Blocking client IP ($CLIENT_IP)"
    docker exec xdp_host python3 /xdp/ip_manager.py add $CLIENT_IP
    
    echo ""
    print_info "Waiting 2 seconds for rule to take effect..."
    sleep 2
    
    echo ""
    print_info "Phase 2: Testing blocked connection"
    test_connection "Connection from blocked IP ($CLIENT_IP)" "fail"
    
    echo ""
    print_info "Phase 3: Listing currently blocked IPs"
    docker exec xdp_host python3 /xdp/ip_manager.py list
    
    echo ""
    print_info "Phase 4: Removing IP from blocklist"
    docker exec xdp_host python3 /xdp/ip_manager.py remove $CLIENT_IP
    
    echo ""
    print_info "Waiting 2 seconds for rule to take effect..."
    sleep 2
    
    echo ""
    print_info "Phase 5: Testing unblocked connection"
    test_connection "Connection after unblocking IP ($CLIENT_IP)" "success"
}

test_multiple_ips() {
    print_step "Testing multiple IP blocking..."
    
    # Test IPs (using non-existent IPs for demo)
    TEST_IPS=("192.168.1.100" "10.0.0.50" "172.16.0.10")
    
    echo ""
    print_info "Adding multiple test IPs to blocklist..."
    for ip in "${TEST_IPS[@]}"; do
        docker exec xdp_host python3 /xdp/ip_manager.py add $ip
        echo "Added: $ip"
    done
    
    echo ""
    print_info "Listing all blocked IPs:"
    docker exec xdp_host python3 /xdp/ip_manager.py list
    
    echo ""
    print_info "Client IP ($CLIENT_IP) should still work:"
    test_connection "Connection while other IPs are blocked" "success"
    
    echo ""
    print_info "Clearing all blocked IPs..."
    docker exec xdp_host python3 /xdp/ip_manager.py clear
}

test_port_blocking() {
    print_step "Testing port-based blocking (port 8080)..."
    
    echo ""
    print_info "Port 8080 should be blocked by XDP program (hardcoded)"
    
    # Test port 8080 (should be blocked)
    echo ""
    echo "Testing: Connection to blocked port 8080"
    echo "Expected: fail"
    echo "Command: docker exec xdp_client nc -w 2 -v $HOST_IP 8080"
    
    if docker exec xdp_client nc -w 2 -v $HOST_IP 8080 2>&1 | grep -q "timed out\|failed"; then
        print_success "Port 8080 blocked as expected"
    else
        print_error "Port 8080 should be blocked but isn't!"
    fi
    
    # Test port 9090 (should work)
    echo ""
    echo "Testing: Connection to allowed port 9090"
    echo "Expected: success"
    echo "Command: docker exec xdp_client nc -w 2 -v $HOST_IP 9090"
    
    if docker exec xdp_client nc -w 2 -v $HOST_IP 9090 2>&1 | grep -q "succeeded"; then
        print_success "Port 9090 works as expected"
    else
        print_error "Port 9090 should work but doesn't!"
    fi
}

show_live_logs() {
    print_step "Showing live XDP logs for 10 seconds..."
    
    echo ""
    print_info "Starting log monitor in background..."
    docker exec xdp_host timeout 10 cat /sys/kernel/debug/tracing/trace_pipe | grep "Blocked" &
    LOG_PID=$!
    
    echo ""
    print_info "Generating test traffic to trigger logs..."
    
    # Generate some blocked traffic
    docker exec xdp_host python3 /xdp/ip_manager.py add $CLIENT_IP &>/dev/null
    sleep 1
    
    # Try to connect (should be blocked and logged)
    docker exec xdp_client nc -w 1 $HOST_IP 80 &>/dev/null &
    docker exec xdp_client nc -w 1 $HOST_IP 8080 &>/dev/null &
    
    sleep 2
    
    # Clean up
    docker exec xdp_host python3 /xdp/ip_manager.py remove $CLIENT_IP &>/dev/null
    
    # Wait for log monitor to finish
    wait $LOG_PID 2>/dev/null
    
    print_info "Log monitoring completed"
}

run_comprehensive_test() {
    print_step "Running comprehensive IP blocking test..."
    
    echo ""
    echo "This test will:"
    echo "1. Block client IP ($CLIENT_IP)"
    echo "2. Test that connections fail"
    echo "3. Show blocked traffic in logs"
    echo "4. Unblock the IP"
    echo "5. Test that connections work again"
    echo ""
    
    # Block client IP
    print_info "Blocking client IP: $CLIENT_IP"
    docker exec xdp_host python3 /xdp/ip_manager.py add $CLIENT_IP
    
    # Show current state
    echo ""
    print_info "Currently blocked IPs:"
    docker exec xdp_host python3 /xdp/ip_manager.py list
    
    echo ""
    print_info "Testing blocked connection (should fail)..."
    
    # Start log monitoring in background
    echo ""
    print_info "Monitoring logs for 5 seconds..."
    docker exec xdp_host timeout 5 cat /sys/kernel/debug/tracing/trace_pipe | grep -E "(Blocked|bpf_trace)" &
    LOG_PID=$!
    
    sleep 1
    
    # Try to connect (should be blocked)
    echo ""
    echo "Attempting connection from blocked IP..."
    docker exec xdp_client nc -w 2 -v $HOST_IP 80 &>/dev/null &
    docker exec xdp_client nc -w 2 -v $HOST_IP 8080 &>/dev/null &
    
    # Wait for logs
    wait $LOG_PID 2>/dev/null
    
    echo ""
    print_info "Unblocking client IP: $CLIENT_IP"
    docker exec xdp_host python3 /xdp/ip_manager.py remove $CLIENT_IP
    
    sleep 1
    
    echo ""
    print_info "Testing unblocked connection (should work)..."
    test_connection "Connection after unblocking" "success"
}

cleanup_test_environment() {
    print_step "Cleaning up test environment..."
    docker exec xdp_host python3 /xdp/ip_manager.py clear &>/dev/null
    print_success "All blocked IPs cleared"
}

print_menu() {
    echo ""
    echo "Test Options:"
    echo "============="
    echo "1) Check XDP Status"
    echo "2) Test Baseline Connectivity"
    echo "3) Test Dynamic IP Blocking"
    echo "4) Test Multiple IPs"
    echo "5) Test Port Blocking"
    echo "6) Show Live Logs"
    echo "7) Run Comprehensive Test"
    echo "8) Cleanup Test Environment"
    echo "9) Run All Tests"
    echo "0) Exit"
    echo ""
}

run_all_tests() {
    print_step "Running all tests..."
    
    check_xdp_status
    test_baseline_connectivity
    test_dynamic_ip_blocking
    test_multiple_ips
    test_port_blocking
    show_live_logs
    cleanup_test_environment
    
    echo ""
    print_success "All tests completed!"
}

# Main execution
main() {
    if [ "$1" = "--auto" ]; then
        run_all_tests
        exit 0
    fi
    
    if [ "$1" = "--comprehensive" ]; then
        run_comprehensive_test
        exit 0
    fi
    
    while true; do
        print_menu
        read -p "Enter choice [0-9]: " choice
        
        case $choice in
            1) check_xdp_status ;;
            2) test_baseline_connectivity ;;
            3) test_dynamic_ip_blocking ;;
            4) test_multiple_ips ;;
            5) test_port_blocking ;;
            6) show_live_logs ;;
            7) run_comprehensive_test ;;
            8) cleanup_test_environment ;;
            9) run_all_tests ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Help text
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "XDP IP Blocking Test Suite"
    echo "=========================="
    echo ""
    echo "Usage:"
    echo "  $0                 - Interactive mode"
    echo "  $0 --auto          - Run all tests automatically"
    echo "  $0 --comprehensive - Run comprehensive test"
    echo "  $0 --help          - Show this help"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker containers must be running (docker-compose up -d)"
    echo "  - XDP program must be loaded"
    echo ""
    exit 0
fi

# Run main function
main "$@"