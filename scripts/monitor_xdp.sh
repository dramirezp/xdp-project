#!/bin/bash

echo "XDP Monitor - Messages and Statistics"
echo "====================================="

# Function to cleanup on exit
cleanup() {
    echo -e "\nStopping monitor..."
    kill $TRACE_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "Starting kernel log monitoring..."

# Monitor trace_pipe in background
docker exec xdp_host bash -c '
mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
echo > /sys/kernel/debug/tracing/trace 2>/dev/null || true

echo "Monitoring XDP messages (press Ctrl+C to stop):"
echo "================================================"

# Function to show timestamp
show_timestamp() {
    echo -n "[$(date +"%H:%M:%S")] "
}

tail -f /sys/kernel/debug/tracing/trace_pipe | while read line; do
    if [[ "$line" == *"Blocked"* ]] || [[ "$line" == *"xdp"* ]] || [[ "$line" == *"bpf"* ]]; then
        show_timestamp
        echo "BLOCKED: $line"
    elif [[ "$line" == *"nc-"* ]] && [[ "$line" == *"8080"* ]]; then
        show_timestamp 
        echo "CONNECTION detected: $line"
    fi
done
' &

TRACE_PID=$!

echo ""
echo "To generate logs, run in another terminal:"
echo "   docker exec xdp_client nc -w 1 172.20.0.10 8080"
echo ""
echo "Waiting for XDP events..."

# Keep script running
wait $TRACE_PID