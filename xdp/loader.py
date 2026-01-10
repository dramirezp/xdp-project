#!/usr/bin/env python3
import os
import sys
import time
import socket
import struct
from pyroute2 import IPRoute

def load_xdp_program():
    # Compilar el programa XDP
    os.chdir('/xdp')
    os.system('make clean && make')
    
    if not os.path.exists('xdp_filter.o'):
        print("Error: No se pudo compilar xdp_filter.o")
        sys.exit(1)
    
    # Obtener interfaz de red
    ipr = IPRoute()
    
    # Buscar la interfaz eth0
    idx = None
    for link in ipr.get_links():
        if link.get_attr('IFLA_IFNAME') == 'eth0':
            idx = link['index']
            break
    
    if idx is None:
        print("Error: No se encontró la interfaz eth0")
        sys.exit(1)
    
    print(f"Cargando programa XDP en interfaz eth0 (index: {idx})")
    
    # Cargar programa XDP usando ip link
    cmd = f"ip link set dev eth0 xdp obj xdp_filter.o sec xdp"
    result = os.system(cmd)
    
    if result == 0:
        print("✓ Programa XDP cargado exitosamente")
        print("\nEstadísticas disponibles en:")
        print("  - /sys/fs/bpf/")
        print("\nPara ver logs: cat /sys/kernel/debug/tracing/trace_pipe")
    else:
        print("✗ Error al cargar el programa XDP")
        sys.exit(1)

if __name__ == '__main__':
    load_xdp_program()
    
    print("\n--- Programa XDP activo ---")
    print("Presiona Ctrl+C para detener\n")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nDeteniendo...")