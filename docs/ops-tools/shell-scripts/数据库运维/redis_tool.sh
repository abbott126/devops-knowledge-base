#!/bin/bash

# Redis数据库管理工具

set -euo pipefail

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASS=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    status                    查看状态
    info                      详细信息
    keys [pattern]            列出键
    get <key>               获取值
    set <key> <value>       设置值
    del <key>               删除键
    exists <key>             检查存在
    expire <key> <sec>       设置过期
    ttl <key>               查看TTL
    backup [path]            备份数据
    restore <file>          恢复数据
    monitor                 实时监控
    flush                   清空数据库

示例:
    $(basename $0) status
    $(basename $0) keys "user:*"
    $(basename $0) set mykey myvalue
EOF
    exit 1
}

has_redis_cli() {
    command -v redis-cli >/dev/null 2>&1
}

redis_cmd() {
    local cmd="$1"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ${REDIS_PASS:+-a "$REDIS_PASS"} "$cmd" 2>/dev/null
}

db_status() {
    echo "=== Redis状态 ==="
    redis_cmd "INFO" | grep -E "(redis_version|connected_clients|used_memory_human|used_cpu_seconds|last_save_time)" | head -10
}

db_info() {
    redis_cmd "INFO"
}

list_keys() {
    local pattern="${1:-*}"
    local count="${2:-100}"
    
    echo "=== Keys ($pattern) ==="
    redis_cmd "KEYS $pattern" | head -"$count"
}

get_value() {
    local key="$1"
    redis_cmd "GET $key"
}

set_value() {
    local key="$1"
    local value="$2"
    local ttl="${3:-}"
    
    if [[ -n "$ttl" ]]; then
        redis_cmd "SET $key '$value' EX $ttl"
    else
        redis_cmd "SET $key '$value'"
    fi
    echo "已设置: $key"
}

delete_key() {
    local key="$1"
    redis_cmd "DEL $key"
    echo "已删除: $key"
}

check_exists() {
    local key="$1"
    local result
    result=$(redis_cmd "EXISTS $key")
    [[ "$result" == "1" ]] && echo "存在" || echo "不存在"
}

set_expire() {
    local key="$1"
    local sec="$2"
    redis_cmd "EXPIRE $key $sec"
    echo "已设置过期: $key ${sec}秒"
}

get_ttl() {
    local key="$1"
    redis_cmd "TTL $key"
}

backup_redis() {
    local path="${1:-.}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$path"
    
    local file="${path}/redis_backup_${timestamp}.rdb"
    
    redis_cmd "SAVE"
    
    local rdb_file
    rdb_file=$(redis_cmd "CONFIG GET dir" | tail -1)
    cp "${rdb_file}/dump.rdb" "$file"
    
    gzip "$file"
    echo "备份完成: ${file}.gz"
}

restore_redis() {
    local file="$1"
    
    gunzip -c "$file" > /tmp/dump.rdb
    
    redis_cmd "SHUTDOWN" 2>/dev/null || true
    
    cp /tmp/dump.rdb $(redis_cmd "CONFIG GET dir" | tail -1)/dump.rdb
    
    redis-server --daemonize yes 2>/dev/null || redis_cmd "SHUTDOWN NOSAVE" 2>/dev/null || true
    
    echo "恢复完成"
}

monitor_redis() {
    redis_cmd "MONITOR"
}

flush_db() {
    local db="${1:-0}"
    redis_cmd "FLUSHDB"
    echo "已清空数据库: $db"
}

case "${1:-}" in
    status)
        db_status
        ;;
    info)
        db_info
        ;;
    keys)
        list_keys "${2:-*}" "${3:-100}"
        ;;
    get)
        get_value "$2"
        ;;
    set)
        set_value "$2" "$3" "${4:-}"
        ;;
    del)
        delete_key "$2"
        ;;
    exists)
        check_exists "$2"
        ;;
    expire)
        set_expire "$2" "$3"
        ;;
    ttl)
        get_ttl "$2"
        ;;
    backup)
        backup_redis "${2:-.}"
        ;;
    restore)
        restore_redis "$2"
        ;;
    monitor)
        monitor_redis
        ;;
    flush)
        flush_db "${2:-0}"
        ;;
    *)
        usage
        ;;
esac