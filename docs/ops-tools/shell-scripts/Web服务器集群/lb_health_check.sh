#!/bin/bash

# 负载均衡集群健康检查脚本

set -euo pipefail

CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
ALERT_THRESHOLD="${ALERT_THRESHOLD:-3}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    check <host>:<port>       检查单个节点
    cluster <hosts>           检查集群
    monitor                  持续监控
    watch                    监控并告警
    report                   生成报告

示例:
    $(basename $0) check 192.168.1.10:8080
    $(basename $0) cluster "192.168.1.10:8080,192.168.1.11:8080"
EOF
    exit 1
}

check_node() {
    local host="$1"
    local name="$host"
    local timeout=3
    
    local start
    start=$(date +%s%N)
    
    if command -v nc >/dev/null 2>&1; then
        nc -zw "$timeout" "$host" >/dev/null 2>&1
    elif command -v timeout >/dev/null 2>&1; then
        timeout "$timeout" bash -c "echo >/dev/tcp/${host/:// }" 2>/dev/null
    else
        curl -sf --connect-timeout "$timeout" "http://$host/health" >/dev/null 2>&1
    fi
    
    local status=$?
    local end
    end=$(date +%s%N)
    local latency=$(( (end - start) / 1000000 ))
    
    if [[ $status -eq 0 ]]; then
        echo "✓ $name OK (${latency}ms)"
        return 0
    else
        echo "✗ $name FAILED"
        return 1
    fi
}

check_cluster() {
    local hosts="$1"
    local total=0
    local online=0
    local offline=0
    
    IFS=',' read -ra ADDRS <<< "$hosts"
    for host in "${ADDRS[@]}"; do
        ((total++))
        if check_node "$host"; then
            ((online++))
        else
            ((offline++))
        fi
    done
    
    echo ""
    echo "=== 集群状态 ==="
    echo "总数: $total | 在线: $online | 离线: $offline"
    
    [[ $offline -gt 0 ]] && return 1 || return 0
}

monitor_cluster() {
    local hosts="$1"
    local count=0
    
    echo "开始监控: ${hosts}"
    echo "按Ctrl+C停止"
    echo ""
    
    while true; do
        ((count++))
        echo "[$(date +%H:%M:%S)] 第${count}次检查"
        check_cluster "$hosts"
        sleep "$CHECK_INTERVAL"
    done
}

watch_alert() {
    local hosts="$1"
    local fail_count=0
    
    echo "开始监控并告警: ${hosts}"
    echo "失败阈值: ${ALERT_THRESHOLD}"
    echo ""
    
    while true; do
        if ! check_cluster "$hosts"; then
            ((fail_count++))
            if [[ $fail_count -ge $ALERT_THRESHOLD ]]; then
                echo "!!! 告警: 集群故障 - ${fail_count}次连续失败"
                fail_count=0
            fi
        else
            fail_count=0
        fi
        sleep "$CHECK_INTERVAL"
    done
}

generate_report() {
    local hosts="$1"
    
    cat > /tmp/lb_report_$(date +%Y%m%d).txt << EOF
=== 负载均衡健康检查报告 ===
生成时间: $(date)
检查节点: $hosts

=== 节点状态 ===
EOF
    
    check_cluster "$hosts" >> /tmp/lb_report_$(date +%Y%m%d).txt
    
    cat >> /tmp/lb_report_$(date +%Y%m%d).txt << EOF

=== 系统状态 ===
系统负载: $(uptime | awk -F'load average:' '{print $2}')
内存使用: $(free -h | grep Mem | awk '{print $3 "/" $2}')
磁盘使用: $(df -h / | tail -1 | awk '{print $3 "/" $2}')

=== 建议 ===
EOF
    
    echo "报告已生成: /tmp/lb_report_$(date +%Y%m%d).txt"
}

case "${1:-}" in
    check)
        check_node "$2"
        ;;
    cluster)
        check_cluster "$2"
        ;;
    monitor)
        monitor_cluster "${2:-127.0.0.1:8080}"
        ;;
    watch)
        watch_alert "${2:-127.0.0.1:8080}"
        ;;
    report)
        generate_report "${2:-127.0.0.1:8080}"
        ;;
    *)
        usage
        ;;
esac