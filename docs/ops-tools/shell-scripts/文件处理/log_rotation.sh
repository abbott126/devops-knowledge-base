#!/bin/bash

# 日志文件轮转和管理工具

set -euo pipefail

LOG_DIR="${1:-/var/log}"
MAX_SIZE="${2:-100M}"
MAX_AGE="${3:-30}"
COMPRESS="${4:-true}"

usage() {
    cat << EOF
用法: $(basename $0) [日志目录] [最大单文件] [保留天数] [是否压缩]

示例:
    $(basename $0) /var/log 100M 30 true
    $(basename $0) /var/log 50M 7 false
EOF
    exit 1
}

[[ ! -d "$LOG_DIR" ]] && echo "目录不存在: $LOG_DIR" && exit 1

MAX_SIZE_NUM=$(numfmt --from=iec "$MAX_SIZE" 2>/dev/null || echo "${MAX_SIZE}")
[[ -z "$MAX_SIZE_NUM" ]] && MAX_SIZE_NUM=104857600

echo "=== 日志轮转工具 ==="
echo "目录: $LOG_DIR"
echo "最大文件: $(numfmt --to=iec-i --suffix=B $MAX_SIZE_NUM)"
echo "保留: ${MAX_AGE}天"
echo ""

rotate_log() {
    local log_file="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    local basename
    basename=$(basename "$log_file")
    local dir
    dir=$(dirname "$log_file")
    
    if [[ -f "$log_file" ]]; then
        mv "$log_file" "${dir}/${basename}.${timestamp}"
        touch "$log_file"
        
        if [[ "$COMPRESS" == "true" ]]; then
            gzip "${dir}/${basename}.${timestamp}" &
        fi
        
        echo "轮转: $log_file -> ${basename}.${timestamp}"
    fi
}

process_logs() {
    local count=0
    
    while IFS= read -r log; do
        size=$(stat -c%s "$log" 2>/dev/null || stat -f%z "$log")
        
        if [[ $size -gt $MAX_SIZE_NUM ]]; then
            rotate_log "$log"
            ((count++))
        fi
    done < <(find "$LOG_DIR" -maxdepth 1 -type f ! -name "*.gz" ! -name "*.bz2" ! -name "*.xz" 2>/dev/null)
    
    echo "已完成: $count 个文件轮转"
}

cleanup_old() {
    local count=0
    local cutoff
    cutoff=$(date -d "-${MAX_AGE} days" +%s)
    
    while IFS= read -r log; do
        mtime=$(stat -c%Y "$log" 2>/dev/null || stat -f%m "$log")
        
        if [[ $mtime -lt $cutoff ]]; then
            rm -f "$log"
            echo "清理: $log"
            ((count++))
        fi
    done < <(find "$LOG_DIR" -maxdepth 1 -type f \( -name "*.gz" -o -name "*.bz2" -o -name "*.xz" \) -mtime +${MAX_AGE} 2>/dev/null)
    
    echo "已清理: $count 个旧文件"
}

case "${2:-combined}" in
    combined)
        process_logs
        cleanup_old
        ;;
    rotate)
        process_logs
        ;;
    cleanup)
        cleanup_old
        ;;
    *)
        process_logs
        cleanup_old
        ;;
esac