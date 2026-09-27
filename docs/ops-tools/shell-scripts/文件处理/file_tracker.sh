#!/bin/bash

# 文件差异追踪工具 - 记录文件变更历史

set -euo pipefail

STATE_FILE="${HOME}/.file_tracker.db"
LOG_FILE="${HOME}/.file_tracker.log"

init_db() {
    mkdir -p "$(dirname "$STATE_FILE")"
    touch "$STATE_FILE"
    echo "初始化追踪数据库: $STATE_FILE"
}

check_file() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "文件不存在: $file" && return 1
    
    local md5
    md5=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1)
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
    local mtime=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file")
    
    local existing
    existing=$(grep "^${file}|" "$STATE_FILE" 2>/dev/null || true)
    
    if [[ -z "$existing" ]]; then
        echo "${file}|${md5}|${size}|${mtime}|$(date +%s)" >> "$STATE_FILE"
        log_action "ADD" "$file" "$md5"
    else
        local old_md5
        old_md5=$(echo "$existing" | cut -d'|' -f2)
        
        if [[ "$md5" != "$old_md5" ]]; then
            local old_size old_mtime
            old_size=$(echo "$existing" | cut -d'|' -f3)
            old_mtime=$(echo "$existing" | cut -d'|' -f4)
            
            sed -i "s|^${file}|.*|${file}|${md5}|${size}|${mtime}|$(date +%s)|" "$STATE_FILE"
            
            if [[ "$size" != "$old_size" ]]; then
                log_action "MODIFY" "$file" "size: ${old_size}->${size}"
            elif [[ "$mtime" != "$old_mtime" ]]; then
                log_action "MODIFY" "$file" "mtime: ${old_mtime}->${mtime}"
            else
                log_action "MODIFY" "$file" "content: ${old_md5}->${md5}"
            fi
        fi
    fi
}

log_action() {
    local action="$1"
    local target="$2"
    local detail="$3"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $action | $target | $detail" >> "$LOG_FILE"
}

watch_dir() {
    local dir="${1:-.}"
    
    while true; do
        find "$dir" -type f -name ".*" -prune -o -type f -print 2>/dev/null | while read -r file; do
            check_file "$file"
        done
        echo "检查完成: $(date '+%Y-%m-%d %H:%M:%S')"
        sleep 60
    done
}

show_changes() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "${1:-20}" "$LOG_FILE"
    else
        echo "无变更记录"
    fi
}

export_diff() {
    local output="${1:-diff_export_$(date +%Y%m%d_%H%M%S).csv}"
    
    {
        echo "timestamp,action,file,detail"
        if [[ -f "$LOG_FILE" ]]; then
            sed 's/\] /]\n/g' "$LOG_FILE" | grep -oP '\[.*?\] \K.*' | \
            while read -r line; do
                echo "$line" | sed 's/\] /] /g' | tr '|' ','
            done
        fi
    } > "$output"
    
    echo "导出到: $output"
}

case "${1:-}" in
    init)
        init_db
        ;;
    watch)
        watch_dir "${2:-.}"
        ;;
    changes)
        show_changes "${2:-20}"
        ;;
    export)
        export_diff "${2:-}"
        ;;
    *)
        cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    init        初始化追踪数据库
    watch [dir] 持续监控目录(默认当前目录)
    changes [n] 显示最近n条变更(默认20)
    export [file] 导出变更到CSV文件

示例:
    $(basename $0) init
    $(basename $0) watch /path/to/dir
    $(basename $0) changes 50
    $(basename $0) export changes.csv
EOF
        ;;
esac