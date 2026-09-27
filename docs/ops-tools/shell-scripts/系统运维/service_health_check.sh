#!/bin/bash

# 服务健康检查和自动重启工具

set -euo pipefail

CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
MAX_RESTART="${MAX_RESTART:-3}"
SERVICES=()

usage() {
    cat << EOF
用法: $(basename $0) [选项]

选项:
    -s, --service <name>   服务名称(可多次指定)
    -p, --process <name>  进程名匹配
    -c, --check <cmd>     检查命令
    -r, --restart <cmd>  重启命令
    -i, --interval <n>    检查间隔(秒,默认30)
    -m, --max-restart <n> 最大重启次数(默认3)
    -h, --help           显示帮助
EOF
    exit 1
}

SERVICES=()
CHECK_CMD=""
RESTART_CMD=""
PROCESS_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--service)
            SERVICES+=("$2")
            shift 2
            ;;
        -p|--process)
            PROCESS_NAME="$2"
            shift 2
            ;;
        -c|--check)
            CHECK_CMD="$2"
            shift 2
            ;;
        -r|--restart)
            RESTART_CMD="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -m|--max-restart)
            MAX_RESTART="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            usage
            ;;
    esac
done

[[ ${#SERVICES[@]} -eq 0 ]] && [[ -z "$PROCESS_NAME" ]] && usage

declare -A restart_count
declare -A last_restart_time

check_service() {
    local service="$1"
    local result
    
    if [[ -n "$CHECK_CMD" ]]; then
        eval "$CHECK_CMD" >/dev/null 2>&1 && result=0 || result=$?
    else
        systemctl is-active "$service" >/dev/null 2>&1 && result=0 || result=$?
    fi
    
    return $result
}

restart_service() {
    local service="$1"
    local now
    now=$(date +%s)
    
    if [[ -n "${restart_count[$service]:-}" ]]; then
        if [[ $(($now - last_restart_time[$service])) -lt 300 ]]; then
            ((restart_count[$service]++))
        else
            restart_count[$service]=0
        fi
    else
        restart_count[$service]=0
    fi
    
    last_restart_time[$service]=$now
    
    if [[ ${restart_count[$service]} -gt $MAX_RESTART ]]; then
        echo "[$(date)] $service 超过最大重启次数,停止自动重启"
        return 1
    fi
    
    if [[ -n "$RESTART_CMD" ]]; then
        eval "$RESTART_CMD"
    else
        systemctl restart "$service" 2>/dev/null || service "$service" restart
    fi
    
    echo "[$(date)] $service 已重启 (第${restart_count[$service]}次)"
}

monitor_loop() {
    echo "开始监控服务..."
    echo "检查间隔: ${CHECK_INTERVAL}秒"
    echo "最大重启: ${MAX_RESTART}次"
    echo ""
    
    while true; do
        for service in "${SERVICES[@]}"; do
            if ! check_service "$service"; then
                echo "[$(date)] $service 检查失败,尝试重启..."
                restart_service "$service" || true
            else
                echo "[$(date)] $service OK"
            fi
        done
        
        if [[ -n "$PROCESS_NAME" ]]; then
            if ! pgrep -x "$PROCESS_NAME" >/dev/null; then
                echo "[$(date)] 进程 $PROCESS_NAME 未运行"
                restart_service "$PROCESS_NAME" || true
            else
                echo "[$(date)] $PROCESS_NAME 运行中"
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

case "${1:-monitor}" in
    monitor)
        monitor_loop
        ;;
    check)
        for service in "${SERVICES[@]}"; do
            if check_service "$service"; then
                echo "$service: 运行中"
            else
                echo "$service: 停止"
            fi
        done
        ;;
    restart)
        for service in "${SERVICES[@]}"; do
            restart_service "$service"
        done
        ;;
    *)
        usage
        ;;
esac