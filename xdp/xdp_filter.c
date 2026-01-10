#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Map to count packets
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u64);
} pkt_count SEC(".maps");

// Map for blocked IPs
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
    
    // Check ethernet bounds
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;
    
    // Only process IP packets
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;
    
    struct iphdr *ip = (void *)(eth + 1);
    
    // Check IP bounds
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;
    
    __u32 src_ip = ip->saddr;
    
    // Check if IP is blocked
    __u8 *blocked = bpf_map_lookup_elem(&blocked_ips, &src_ip);
    if (blocked) {
        // Increment blocked packet counter
        __u32 key = 1;
        __u64 *count = bpf_map_lookup_elem(&pkt_count, &key);
        if (count) {
            __sync_fetch_and_add(count, 1);
        }
        
        bpf_printk("Blocked packet from IP: %x\n", bpf_ntohl(src_ip));
        return XDP_DROP;
    }
    
    // Increment allowed packet counter
    __u32 key = 0;
    __u64 *count = bpf_map_lookup_elem(&pkt_count, &key);
    if (count) {
        __sync_fetch_and_add(count, 1);
    }
    
    // Example: Block TCP port 8080
    if (ip->protocol == IPPROTO_TCP) {
        struct tcphdr *tcp = (void *)(ip + 1);
        if ((void *)(tcp + 1) > data_end)
            return XDP_PASS;
        
        if (bpf_ntohs(tcp->dest) == 8080) {
            bpf_printk("Blocked TCP packet to port 8080\n");
            return XDP_DROP;
        }
    }
    
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";