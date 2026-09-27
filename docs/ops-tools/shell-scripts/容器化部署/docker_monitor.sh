#!/bin/bash

# Docker容器健康监控和自动恢复

set -euo pipefail

CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
RESTART_THRESHOLD="${RESTART_THRESHOLD:-3}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    monitor                   监控容器
    watch                    监控并告警
    restart <container>      重启容器
    logs <container>        查看日志
    stats                   资源统计

示例:
    $(basename $0) monitor
    $(basename $0) watch
EOF
    exit 1
}

check_container() {
    local container="$1"
    
    local status
    status=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)
    
    if [[ "$status" != "true" ]]; then
        echo "容器停止: $container"
        return 1
    fi
    
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)
    
    if [[ "$health" == "unhealthy" ]]; then
        echo "容器异常: $container"
        return 1
    fi
    
    echo "容器正常: $container"
    return 0
}

monitor_containers() {
    echo "=== 容器健康监控 ==="
    echo "按Ctrl+C停止"
    echo ""
    
    while true; do
        local count=0
        local running=0
        
        for container in $(docker ps -q); do
            ((count++))
            if check_container "$container"; then
                ((running++))
            fi
        done
        
        echo "[$(date +%H:%M:%S)] 运行: $running/$count"
        
        sleep "$CHECK_INTERVAL"
    done
}

watch_containers() {
    local fail_count=0
    
    echo "=== 容器监控告警 ==="
    echo "失败阈值: ${RESTART_THRESHOLD}"
    echo ""
    
    while true; do
        local failed=0
        
        for container in $(docker ps -q); do
            if ! check_container "$container"; then
                ((failed++))
                
                if [[ $fail_count -ge 2 ]]; then
                    echo "尝试自动重启: $container"
                    docker restart "$container" 2>/dev/null || true
                fi
            fi
        done
        
        if [[ $failed -gt 0 ]]; then
            ((fail_count++))
            if [[ $fail_count -ge $RESTART_THRESHOLD ]]; then
                echo "!!! 告警: 多个容器故障"
                fail_count=0
            fi
        else
            fail_count=0
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

restart_container() {
    local container="$1"
    
    docker restart "$container"
    echo "已重启: $container"
}

container_logs() {
    local container="$1"
    local lines="${2:-100}"
    
    docker logs --tail "$lines" -f "$container"
}

container_stats() {
    echo "=== 容器资源统计 ==="
    docker stats --no-stream
}

case "${1:-}" in
    monitor)
        monitor_containers
        ;;
    watch)
        watch_containers
        ;;
    restart)
        restart_container "$2"
        ;;
    logs)
        container_logs "${2}" "${3:-100}"
        ;;
    stats)
        container_stats
        ;;
    *)
        usage
        ;;
esac