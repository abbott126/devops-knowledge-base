#!/bin/bash

# 磁盘空间监控和告警

set -euo pipefail

THRESHOLD="${THRESHOLD:-90}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
ALERT_EMAIL=""

usage() {
    cat << EOF
用法: $(basename $0) [选项]

选项:
    -t, --threshold <percent>    告警阈值(默认90%)
    -i, --interval <sec>     检查间隔(默认300秒)
    -e, --email <addr>     告警邮箱
    -p, --path <path>      检查路径
    -h, --help            显示帮助

示例:
    $(basename $0) -t 85 -i 600
    $(basename $0) -p /data -e admin@example.com
EOF
    exit 1
}

THRESHOLD=90
CHECK_INTERVAL=300
ALERT_EMAIL=""
CHECK_PATH="/"

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -e|--email)
            ALERT_EMAIL="$2"
            shift 2
            ;;
        -p|--path)
            CHECK_PATH="$2"
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

alert() {
    local message="$1"
    local subject="磁盘告警: $(hostname)"
    
    echo "[$(date)] $message"
    
    if [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

check_disk() {
    local usage
    usage=$(df "$CHECK_PATH" | tail -1 | awk '{print $5}' | tr -d '%')
    
    if [[ $usage -ge $THRESHOLD ]]; then
        local available
        available=$(df -h "$CHECK_PATH" | tail -1 | awk '{print $4}')
        alert "磁盘使用率: ${usage}% (阈值:${THRESHOLD}%) 剩余: $available"
        return 1
    fi
    
    echo "[$(date)] ${CHECK_PATH}: ${usage}%"
    return 0
}

find_large_dirs() {
    local path="${1:-.}"
    local top="${2:-5}"
    
    echo "=== 大目录 Top $top ==="
    du -ah "$path" 2>/dev/null | sort -rh | head -"$top"
}

find_old_files() {
    local path="${1:-.}"
    local days="${2:-30}"
    
    echo "=== 旧文件 (>${days}天) ==="
    find "$path" -type f -mtime +"$days" 2>/dev/null | head -20
}

monitor_loop() {
    echo "开始磁盘监控..."
    echo "路径: $CHECK_PATH"
    echo "阈值: ${THRESHOLD}%"
    echo "间隔: ${CHECK_INTERVAL}秒"
    echo ""
    
    while true; do
        check_disk
        sleep "$CHECK_INTERVAL"
    done
}

case "${1:-monitor}" in
    monitor)
        monitor_loop
        ;;
    check)
        check_disk
        ;;
    large)
        find_large_dirs "${2:-.}" "${3:-5}"
        ;;
    old)
        find_old_files "${2:-.}" "${3:-30}"
        ;;
    *)
        usage
        ;;
esac