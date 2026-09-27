#!/bin/bash

# 日志收集和告警推送工具

set -euo pipefail

LOG_DIR="${LOG_DIR:-/var/log}"
MAX_SIZE="${MAX_SIZE:-100M}"
ALERT_WEBHOOK=""
ALERT_THRESHOLD=100

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    watch <pattern>          监控日志模式
    alert <message>         发送告警
    webhook <url>          配置webhook
    count <pattern> <file> 统计匹配数量
    tailf <file>           实时监控
    history                查看告警历史

示例:
    $(basename $0) watch "ERROR" /var/log/app.log
    $(basename $0) alert "服务宕机"
EOF
    exit 1
}

HISTORY_FILE="${HOME}/.alert_history"

send_webhook() {
    local message="$1"
    local url="$2"
    
    [[ -z "$url" ]] && return
    
    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$message\", \"time\": \"$(date)\"}" 2>/dev/null || \
        echo "发送失败"
}

watch_log() {
    local pattern="$1"
    local logfile="$2"
    local count=0
    
    [[ ! -f "$logfile" ]] && echo "文件不存在" && return
    
    tail -n 0 -f "$logfile" | while read -r line; do
        if echo "$line" | grep -q "$pattern"; then
            ((count++))
            alert "匹配 [$pattern]: $line"
            
            if [[ $count -ge $ALERT_THRESHOLD ]]; then
                alert "告警: 超过阈值 ${ALERT_THRESHOLD}次"
                break
            fi
        fi
    done
}

send_alert() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] $message"
    
    echo "[$timestamp] $message" >> "$HISTORY_FILE"
    
    [[ -n "$ALERT_WEBHOOK" ]] && send_webhook "$message" "$ALERT_WEBHOOK"
    
    if command -v telegram-send >/dev/null 2>&1; then
        telegram-send "$message" 2>/dev/null || true
    fi
}

set_webhook() {
    local url="$1"
    ALERT_WEBHOOK="$url"
    echo "Webhook已设置: $url"
}

count_pattern() {
    local pattern="$1"
    local file="$2"
    local count
    
    count=$(grep -c "$pattern" "$file" 2>/dev/null || echo 0)
    echo "匹配数量: $count"
}

view_history() {
    local lines="${1:-50}"
    [[ -f "$HISTORY_FILE" ]] && tail -n "$lines" "$HISTORYORY_FILE" || echo "无历史记录"
}

case "${1:-}" in
    watch)
        watch_log "$2" "$3"
        ;;
    alert)
        send_alert "$2"
        ;;
    webhook)
        set_webhook "$2"
        ;;
    count)
        count_pattern "$2" "$3"
        ;;
    tailf)
        tail -f "${2:-/var/log/syslog}"
        ;;
    history)
        view_history "${2:-50}"
        ;;
    *)
        usage
        ;;
esac