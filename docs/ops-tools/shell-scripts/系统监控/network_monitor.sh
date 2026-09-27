#!/bin/bash

# 网络连接监控工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    connections              查看活动连接
    ports                    查看监听端口
    established             ESTABLISHED连接
    time-wait                TIME_WAIT统计
    sync                    SYN发送统计
    top-ip                  连接最多的IP
    block                   屏蔽恶意IP
    bandwidth               带宽使用

示例:
    $(basename $0) connections
    $(basename $0) ports
    $(basename $0) top-ip
EOF
    exit 1
}

list_connections() {
    echo "=== 连接统计 ==="
    ss -tan | awk '{print $1}' | sort | uniq -c | sort -rn
}

list_ports() {
    echo "=== 监听端口 ==="
    ss -tln | grep -v "Local" | awk '{print $4}' | \
        awk -F: '{print $NF}' | sort -n | uniq
}

list_established() {
    echo "=== ESTABLISHED连接 ==="
    ss -tnp | grep ESTABLISHED | awk '{print $4" "$5}' | \
        awk -F: '{print $1" -> "$2}' | sort | uniq -c | sort -rn | head -20
}

list_timewait() {
    echo "=== TIME_WAIT统计 ==="
    ss -ti | grep TIME-WAIT | awk '{print $4" "$5}' | \
        awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10
    
    local count
    count=$(ss -tan | grep TIME-WAIT | wc -l)
    echo "总计: $count"
}

list_syn() {
    echo "=== SYN统计 ==="
    ss -tn | grep SYN-SENT | wc -l
}

list_top_ip() {
    echo "=== 连接最多的IP Top 20 ==="
    ss -tn | awk '{print $5}' | cut -d: -f1 | grep -v "Local" | \
        sort | uniq -c | sort -rn | head -20
}

block_ips() {
    local num="${1:-20}"
    
    echo "=== 屏蔽连接最多的${num}个IP ==="
    
    local ips
    ips=$(ss -tn | awk '{print $5}' | cut -d: -f1 | grep -v "Local" | \
        sort | uniq -c | sort -rn | head -"$num" | awk '{print $2}')
    
    for ip in $ips; do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "iptables -A INPUT -s $ip -j DROP"
            echo "已添加: $ip"
        fi
    done
}

show_bandwidth() {
    echo "=== 网络带宽 ==="
    cat /proc/net/dev | grep -v "lo" | while read -r line; do
        local iface rx tx
        iface=$(echo "$line" | awk -F: '{print $1}')
        rx=$(echo "$line" | awk '{print $2}')
        tx=$(echo "$line" | awk '{print $10}')
        echo "$iface: RX=$((rx/1024))KB TX=$((tx/1024))KB"
    done
}

case "${1:-}" in
    connections)
        list_connections
        ;;
    ports)
        list_ports
        ;;
    established)
        list_established
        ;;
    time-wait)
        list_timewait
        ;;
    sync)
        list_syn
        ;;
    top-ip)
        list_top_ip
        ;;
    block)
        block_ips "${2:-20}"
        ;;
    bandwidth)
        show_bandwidth
        ;;
    *)
        usage
        ;;
esac