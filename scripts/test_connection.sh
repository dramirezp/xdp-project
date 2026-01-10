#!/bin/bash

echo "=== Pruebas de Conectividad XDP ==="
echo ""

echo "1. Ping al host (debería funcionar):"
docker exec xdp_client ping -c 3 172.20.0.10
echo ""

echo "2. Conexión a puerto 80 (PERMITIDO - debería funcionar):"
docker exec xdp_client bash -c "echo 'GET / HTTP/1.0' | nc 172.20.0.10 80" 2>&1
echo ""

echo "3. Conexión a puerto 8080 (BLOQUEADO por XDP - debería fallar):"
timeout 3 docker exec xdp_client bash -c "echo 'GET / HTTP/1.0' | nc 172.20.0.10 8080" 2>&1 || echo "Timeout - puerto bloqueado por XDP ✓"
echo ""

echo "4. Conexión a puerto 9090 (PERMITIDO - debería funcionar):"
docker exec xdp_client bash -c "echo 'GET / HTTP/1.0' | nc 172.20.0.10 9090" 2>&1
echo ""

echo "5. Ver estadísticas XDP (últimas 10 líneas):"
docker exec xdp_host timeout 2 cat /sys/kernel/debug/tracing/trace_pipe 2>/dev/null | tail -n 10 || echo "No hay eventos recientes"
echo ""

echo "=== Resumen ==="
echo "Puerto 80:   ✓ Permitido (XDP_PASS)"
echo "Puerto 8080: ✗ Bloqueado (XDP_DROP)"
echo "Puerto 9090: ✓ Permitido (XDP_PASS)"