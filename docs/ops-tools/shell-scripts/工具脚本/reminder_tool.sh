#!/bin/bash

# 时间管理工具 - 定时任务和提醒

set -euo pipefail

REMINDER_FILE="${HOME}/.reminders"

init_reminders() {
    mkdir -p "$(dirname "$REMINDER_FILE")"
    touch "$REMINDER_FILE"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    add <time> <message>      添加提醒
    list                      列出提醒
    del <id>                  删除提醒
    now <message>             立即提醒
    at <time> <message>      AT定时提醒
    watch                     监控提醒

示例:
    $(basename $0) add "2024-12-31 23:59" "新年快乐"
    $(basename $0) now "测试提醒"
EOF
    exit 1
}

add_reminder() {
    local time="$1"
    shift
    local message="$*"
    local id
    
    id=$(date +%s)
    
    echo "$id|$time|$message" >> "$REMINDER_FILE"
    echo "已添加: $time - $message"
}

list_reminders() {
    echo "=== 提醒列表 ==="
    [[ ! -s "$REMINDER_FILE" ]] && echo "无提醒" && return
    
    cat "$REMINDER_FILE" | while IFS='|' read -r id time message; do
        echo "[$id] $time - $message"
    done
}

delete_reminder() {
    local id="$1"
    
    sed -i "/^$id|/d" "$REMINDER_FILE"
    echo "已删除: $id"
}

now_reminder() {
    local message="$*"
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "提醒" "$message"
    elif command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$message\""
    else
        echo "提醒: $message"
    fi
    
    echo "$message" >> "${HOME}/.reminder_history"
}

at_reminder() {
    local time="$1"
    shift
    local message="$*"
    
    echo "$message" | at "$time" 2>/dev/null && echo "已设置: $time" || echo "at命令不可用"
}

watch_reminders() {
    while true; do
        while IFS='|' read -r id time message; do
            [[ -z "$id" ]] && continue
            
            if [[ "$(date -d "$time" +%s 2>/dev/null)" -le "$(date +%s)" ]]; then
                echo "触发: $message"
                now_reminder "$message"
                delete_reminder "$id"
            fi
        done < "$REMINDER_FILE"
        
        sleep 60
    done
}

[[ ! -f "$REMINDER_FILE" ]] && init_reminders

case "${1:-}" in
    add)
        add_reminder "$2" "${3:-}"
        ;;
    list)
        list_reminders
        ;;
    del)
        delete_reminder "$2"
        ;;
    now)
        now_reminder "${2:-}"
        ;;
    at)
        at_reminder "$2" "${3:-}"
        ;;
    watch)
        watch_reminders
        ;;
    *)
        usage
        ;;
esac