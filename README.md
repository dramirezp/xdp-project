# Construir contenedores
docker-compose build

# Iniciar contenedores
docker-compose up -d

# Ver logs del host
docker-compose logs -f host
```

### 3. Probar la conectividad

```bash
# Desde el cliente hacer ping
docker exec xdp_client ping -c 3 172.20.0.10

# Desde el cliente intentar conectar a puerto bloqueado
docker exec xdp_client nc -zv 172.20.0.10 8080

# Ver logs del kernel en el host
docker exec xdp_host cat /sys/kernel/debug/tracing/trace_pipe
```

### 4. Bloquear una IP específica

```bash
# Entrar al contenedor host
docker exec -it xdp_host bash

# Usar bpftool para modificar el mapa
# Primero necesitas instalar bpftool si no está disponible
```

### 5. Limpiar

```bash
docker-compose down
docker-compose down -v  # Para eliminar volúmenes también
```

## Notas Importantes

- El contenedor host necesita privilegios elevados para cargar programas eBPF
- El programa XDP está activo en la interfaz eth0 del contenedor host
- Por defecto, bloquea el puerto TCP 8080
- Puedes modificar `xdp_filter.c` para cambiar las reglas de filtrado
- Los logs del kernel se pueden ver en `/sys/kernel/debug/tracing/trace_pipe`

## Personalización

Para cambiar las reglas de filtrado, modifica `xdp_filter.c`:

- **Bloquear por IP**: Agrega entradas al mapa `blocked_ips`
- **Bloquear por puerto**: Modifica la sección de TCP/UDP
- **Bloquear por protocolo**: Verifica `ip->protocol`

Después de modificar, recompila con `make` y recarga el programa.