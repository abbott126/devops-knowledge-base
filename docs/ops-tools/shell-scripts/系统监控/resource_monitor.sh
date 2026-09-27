#!/bin/bash

# 系统资源监控仪表板

set -euo pipefail

INTERVAL="${1:-2}"
COUNT="${2:-10}"

usage() {
    cat << EOF
用法: $(basename $0) [间隔] [次数]

示例:
    $(basename $0) 2 5    # 每2秒刷新,共5次
    $(basename $0) 1     # 每1秒刷新,持续显示(Ctrl+C退出)
EOF
    exit 1
}

print_header() {
    echo "=============================================="
    echo "        系统资源监控 $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
}

print_system() {
    local uptime
    uptime=$(uptime | sed 's/.*up //;s/,.*//')
    local load
    load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    
    echo "系统运行: $uptime"
    echo "负载均值: $load"
}

print_cpu() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)% id.*/\1/' | awk '{print 100 - $1}')
    
    local cpu_temp=""
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        cpu_temp=$((cpu_temp / 1000))"°C"
    fi
    
    echo "CPU使用: ${cpu_usage}(${cpu_temp:-N/A})"
}

print_memory() {
    local mem_info
    mem_info=$(free -m | grep Mem)
    
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local free=$(echo "$mem_info" | awk '{print $4}')
    local usage
    usage=$((used * 100 / total))
    
    echo "内存使用: ${used}MB/${total}MB (${usage}%)"
}

print_disk() {
    echo "磁盘使用:"
    df -h | grep -v "tmpfs\|devtmpfs\|loop" | tail -n +2 | while read -r line; do
        local mount size used avail use
        mount=$(echo "$line" | awk '{print $6}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        use=$(echo "$line" | awk '{print $5}')
        echo "  $mount: $used/$size (${use})"
    done
}

print_io() {
    local disk_io
    disk_io=$(iostat -dx 1 1 2>/dev/null | tail -n +4 | head -5 | \
        awk '{print $1" r"$2" w"$3" util"$NF}')
    
    echo "IO统计:"
    echo "$disk_io" | while read -r line; do
        [[ -n "$line" ]] && echo "  $line"
    done
}

print_network() {
    echo "网络流量:"
    cat /proc/net/dev | grep -v "lo\|receive\|drop" | tail -n +3 | while read -r line; do
        local iface rx tx
        iface=$(echo "$line" | awk -F: '{print $1}')
        rx=$(echo "$line" | awk '{print $2}')
        tx=$(echo "$line" | awk '{print $10}')
        rx=$((rx / 1024 / 1024))
        tx=$((tx / 1024 / 1024))
        [[ $rx -gt 0 ]] || [[ $tx -gt 0 ]] && \
            echo "  $iface: ↑${tx}MB ↓${rx}MB"
    done | head -5
}

print_top() {
    echo "Top进程:"
    ps aux --sort=-%cpu | head -6 | tail -n +2 | \
        awk '{print $2" "$3"%"$4"%"$11}' | while read -r line; do
        echo "  $line"
    done
}

monitor_loop() {
    local counter=0
    
    while [[ $COUNT -eq 0 ]] || [[ $counter -lt $COUNT ]]; do
        clear
        print_header
        echo ""
        print_system
        echo ""
        print_cpu
        print_memory
        echo ""
        print_disk
        echo ""
        print_network
        echo ""
        print_top
        
        ((counter++))
        [[ $COUNT -eq 0 ]] || [[ $counter -ge $COUNT ]] && break
        sleep "$INTERVAL"
    done
}

case "${1:-monitor}" in
    monitor)
        monitor_loop
        ;;
    cpu)
        print_cpu
        ;;
    mem)
        print_memory
        ;;
    disk)
        print_disk
        ;;
    net)
        print_network
        ;;
    *)
        usage
        ;;
esac