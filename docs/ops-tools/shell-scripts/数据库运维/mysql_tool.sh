#!/bin/bash

# MySQL数据库管理工具

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    status                    查看数据库状态
    list                     列出所有数据库
    tables <db>              列出数据库表
    size <db>                查看数据库大小
    create <db> [charset]    创建数据库
    drop <db>                删除数据库
    backup <db> [path]      备份数据库
    restore <backup> <db>   恢复数据库
    query <db> <sql>        执行SQL
    user-add <user> <pass>  添加用户
    user-grant <db> <user>  授权用户

示例:
    $(basename $0) status
    $(basename $0) tables mydb
    $(basename $0) backup mydb /backup
EOF
    exit 1
}

has_mysql() {
    command -v mysql >/dev/null 2>&1
}

mysql_exec() {
    local sql="$1"
    local db="${2:-}"
    
    MYSQL_PWD="$MYSQL_PASS" mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" \
        ${db:+-D "$db"} -e "$sql" 2>/dev/null
}

db_status() {
    echo "=== MySQL状态 ==="
    mysql_exec "SHOW STATUS LIKE 'Uptime'" || echo "连接失败"
    mysql_exec "SHOW STATUS LIKE 'Threads_connected'" || true
    mysql_exec "SHOW STATUS LIKE 'Queries'" || true
}

list_databases() {
    echo "=== 数据库列表 ==="
    mysql_exec "SHOW DATABASES"
}

list_tables() {
    local db="$1"
    echo "=== $db 表列表 ==="
    mysql_exec "SHOW TABLES" "$db"
}

db_size() {
    local db="$1"
    echo "=== $db 大小 ==="
    mysql_exec "
        SELECT 
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
        FROM information_schema.tables 
        WHERE table_schema = '$db'" "$db"
}

create_database() {
    local db="$1"
    local charset="${2:-utf8mb4}"
    
    mysql_exec "CREATE DATABASE IF NOT EXISTS \`$db\` DEFAULT CHARACTER SET $charset"
    echo "数据库已创建: $db"
}

drop_database() {
    local db="$1"
    mysql_exec "DROP DATABASE IF EXISTS \`$db\`"
    echo "数据库已删除: $db"
}

backup_database() {
    local db="$1"
    local path="${2:-.}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local file="${path}/${db}_${timestamp}.sql"
    
    mkdir -p "$path"
    
    MYSQL_PWD="$MYSQL_PASS" mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" \
        --single-transaction --routines --triggers "$db" > "$file" 2>/dev/null
    
    gzip "$file"
    echo "备份完成: ${file}.gz"
}

restore_database() {
    local backup="$1"
    local db="$2"
    
    create_database "$db"
    
    gunzip -c "$backup" | MYSQL_PWD="$MYSQL_PASS" mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$db"
    
    echo "恢复完成: $db"
}

add_user() {
    local user="$1"
    local pass="$2"
    local host="${3:-%}"
    
    mysql_exec "CREATE USER IF NOT EXISTS '$user'@'$host' IDENTIFIED BY '$pass'"
    echo "用户已创建: $user@$host"
}

grant_user() {
    local db="$1"
    local user="$2"
    host="${3:-%}"
    
    mysql_exec "GRANT ALL PRIVILEGES ON \`$db\`.* TO '$user'@'$host'"
    mysql_exec "FLUSH PRIVILEGES"
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
        create_database "$2" "${3:-utf8mb4}"
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
    query)
        mysql_exec "$3" "$2"
        ;;
    user-add)
        add_user "$2" "$3" "${4:-%}"
        ;;
    user-grant)
        grant_user "$2" "$3" "${4:-%}"
        ;;
    *)
        usage
        ;;
esac