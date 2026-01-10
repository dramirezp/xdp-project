#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Mapa para contar paquetes
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u64);
} pkt_count SEC(".maps");

// Mapa para IPs bloqueadas
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u8);
} blocked_ips SEC(".maps");

SEC("xdp")
int xdp_filter_func(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    
    struct ethhdr *eth = data;
    
    // Verificar límites ethernet
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;
    
    // Solo procesar paquetes IP
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;
    
    struct iphdr *ip = (void *)(eth + 1);
    
    // Verificar límites IP
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;
    
    __u32 src_ip = ip->saddr;
    
    // Verificar si la IP está bloqueada
    __u8 *blocked = bpf_map_lookup_elem(&blocked_ips, &src_ip);
    if (blocked) {
        // Incrementar contador de paquetes bloqueados
        __u32 key = 1;
        __u64 *count = bpf_map_lookup_elem(&pkt_count, &key);
        if (count) {
            __sync_fetch_and_add(count, 1);
        }
        
        bpf_printk("Bloqueado paquete de IP: %x\n", bpf_ntohl(src_ip));
        return XDP_DROP;
    }
    
    // Incrementar contador de paquetes permitidos
    __u32 key = 0;
    __u64 *count = bpf_map_lookup_elem(&pkt_count, &key);
    if (count) {
        __sync_fetch_and_add(count, 1);
    }
    
    // Ejemplo: Bloquear puerto TCP 8080
    if (ip->protocol == IPPROTO_TCP) {
        struct tcphdr *tcp = (void *)(ip + 1);
        if ((void *)(tcp + 1) > data_end)
            return XDP_PASS;
        
        if (bpf_ntohs(tcp->dest) == 8080) {
            bpf_printk("Bloqueado paquete TCP a puerto 8080\n");
            return XDP_DROP;
        }
    }
    
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";