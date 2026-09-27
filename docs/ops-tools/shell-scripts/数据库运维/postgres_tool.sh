#!/bin/bash

# PostgreSQL数据库管理工具

set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_PASS=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    status                    查看状态
    list                     列出数据库
    tables <db>              列出表
    size <db>                查看大小
    create <db> [user]        创建数据库
    drop <db>                删除数据库
    backup <db> [path]      备份
    restore <file> <db>     恢复
    user-add <user> <pass>  创建用户
    grant <db> <user>       授权

示例:
    $(basename $0) list
    $(basename $0) size mydb
    $(basename $0) backup mydb /backup
EOF
    exit 1
}

has_psql() {
    command -v psql >/dev/null 2>&1
}

pg_exec() {
    local sql="$1"
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -tc "$sql" 2>/dev/null
}

db_status() {
    echo "=== PostgreSQL状态 ==="
    pg_exec "SELECT version();" | head -3
    pg_exec "SELECT pg_postmaster_start_time();" | head -1
    pg_exec "SELECT count(*) FROM pg_database;" | tail -1
}

list_databases() {
    echo "=== 数据库列表 ==="
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -l 2>/dev/null | head -20
}

list_tables() {
    local db="$1"
    echo "=== $db 表列表 ==="
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" -c "\dt" 2>/dev/null
}

db_size() {
    local db="$1"
    echo "=== $db 大小 ==="
    pg_exec "SELECT pg_size_pretty(pg_database_size('$db'));"
}

create_database() {
    local db="$1"
    local owner="${2:-$PG_USER}"
    
    pg_exec "CREATE DATABASE $db WITH OWNER $owner;"
    echo "数据库已创建: $db"
}

drop_database() {
    local db="$1"
    pg_exec "DROP DATABASE IF EXISTS $db;"
    echo "数据库已删除: $db"
}

backup_database() {
    local db="$1"
    local path="${2:-.}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local file="${path}/${db}_${timestamp}.sql"
    
    mkdir -p "$path"
    
    PGPASSWORD="$PG_PASS" pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -Fc "$db" > "$file" 2>/dev/null || \
        PGPASSWORD="$PG_PASS" pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$db" > "$file" 2>/dev/null
    
    gzip "$file"
    echo "备份完成: ${file}.gz"
}

restore_database() {
    local file="$1"
    local db="$2"
    
    create_database "$db"
    
    gunzip -c "$file" | PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" 2>/dev/null
    
    echo "恢复完成: $db"
}

add_user() {
    local user="$1"
    local pass="$2"
    
    pg_exec "CREATE USER $user WITH PASSWORD '$pass';"
    echo "用户已创建: $user"
}

grant_db() {
    local db="$1"
    local user="$2"
    
    pg_exec "GRANT ALL PRIVILEGES ON DATABASE $db TO $user;"
    echo "授权完成: $user -> $db"
}

case "${1:-}" in
    status)
        db_status
        ;;
    list)
        list_databases
        ;;
    tables)
        list_tables "$2"
        ;;
    size)
        db_size "$2"
        ;;
    create)
        create_database "$2" "${3:-}"
        ;;
    drop)
        drop_database "$2"
        ;;
    backup)
        backup_database "$2" "${3:-.}"
        ;;
    restore)
        restore_database "$2" "$3"
        ;;
    user-add)
        add_user "$2" "$3"
        ;;
    grant)
        grant_db "$2" "$3"
        ;;
    *)
        usage
        ;;
esac