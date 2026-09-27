#!/bin/bash

# 数据库集群自动备份脚本

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
COMPRESS="${COMPRESS:-true}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    mysql                      备份MySQL
    postgres                  备份PostgreSQL
    redis                     备份Redis
    all                       备份所有数据库
    schedule                  配置定时备份
    restore <file> <db>      恢复备份
    list                      列出备份

示例:
    $(basename $0) mysql
    $(basename $0) all
    $(basename $0) schedule
EOF
    exit 1
}

backup_mysql() {
    local db="${1:-all}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$BACKUP_DIR/mysql"
    
    if [[ "$db" == "all" ]]; then
        mysqldump -u root --all-databases > "$BACKUP_DIR/mysql/full_${timestamp}.sql" 2>/dev/null || \
            mysqldump -u root -p"$(cat /etc/mysql/debian.cnf | grep password | head -1)" --all-databases > "$BACKUP_DIR/mysql/full_${timestamp}.sql"
    else
        mysqldump -u root "$db" > "$BACKUP_DIR/mysql/${db}_${timestamp}.sql"
    fi
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$BACKUP_DIR/mysql/"*.sql
    fi
    
    echo "MySQL备份完成: $BACKUP_DIR/mysql/"
}

backup_postgres() {
    local db="${1:-postgres}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$BACKUP_DIR/postgres"
    
    sudo -u postgres pg_dump "$db" > "$BACKUP_DIR/postgres/${db}_${timestamp}.sql" 2>/dev/null || \
        pg_dump -U postgres "$db" > "$BACKUP_DIR/postgres/${db}_${timestamp}.sql"
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$BACKUP_DIR/postgres/"*.sql
    fi
    
    echo "PostgreSQL备份完成: $BACKUP_DIR/postgres/"
}

backup_redis() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$BACKUP_DIR/redis"
    
    redis-cli SAVE 2>/dev/null
    redis-cli BGSAVE 2>/dev/null
    cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis/dump_${timestamp}.rdb" 2>/dev/null || \
        echo "需要Redis权限"
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$BACKUP_DIR/redis/"*.rdb
    fi
    
    echo "Redis备份完成: $BACKUP_DIR/redis/"
}

backup_all() {
    echo "=== 备份所有数据库 ==="
    
    backup_mysql
    backup_postgres
    backup_redis
    
    cleanup_old
    show_report
}

schedule_backup() {
    mkdir -p /etc/cron.d
    
    cat > /etc/cron.d/database-backup << EOF
# 每天凌晨3点备份
0 3 * * * root $(readlink -f "$0") all >> /var/log/backup.log 2>&1
EOF
    
    echo "定时备份已配置: 每天凌晨3点"
}

cleanup_old() {
    echo "=== 清理过期备份 ==="
    
    find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null || true
    
    echo "保留天数: $RETENTION_DAYS"
}

restore_mysql() {
    local file="$1"
    local db="${2:-}"
    
    if [[ "$file" == *.gz ]]; then
        gunzip -c "$file" | mysql -u root 2>/dev/null || \
            mysql -u root -p"$(cat /etc/mysql/debian.cnf | grep password | head -1)" 2>/dev/null
    else
        mysql -u root "$db" < "$file" 2>/dev/null || \
            mysql -u root -p"$(cat /etc/mysql/debian.cnf | grep password | head -1)" 2>/dev/null
    fi
    
    echo "MySQL恢复完成: $file"
}

restore_postgres() {
    local file="$1"
    local db="${2:-postgres}"
    
    if [[ "$file" == *.gz ]]; then
        gunzip -c "$file" | psql -U postgres -d "$db" 2>/dev/null || \
            sudo -u postgres psql -d "$db" < <(gunzip -c "$file")
    else
        psql -U postgres -d "$db" < "$file" 2>/dev/null || \
            sudo -u postgres psql -d "$db" < "$file"
    fi
    
    echo "PostgreSQL恢复完成: $file"
}

list_backups() {
    echo "=== 备份列表 ==="
    
    echo "--- MySQL ---"
    ls -lh "$BACKUP_DIR/mysql/" 2>/dev/null | tail -10 || echo "无备份"
    
    echo ""
    echo "--- PostgreSQL ---"
    ls -lh "$BACKUP_DIR/postgres/" 2>/dev/null | tail -10 || echo "无备份"
    
    echo ""
    echo "--- Redis ---"
    ls -lh "$BACKUP_DIR/redis/" 2>/dev/null | tail -10 || echo "无备份"
}

show_report() {
    local size
    size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local count
    count=$(find "$BACKUP_DIR" -type f | wc -l)
    
    echo "=== 备份报告 ==="
    echo "总大小: ${size:-0}"
    echo "文件数: ${count:-0}"
    echo "保留: ${RETENTION_DAYS}天"
}

case "${1:-}" in
    mysql)
        backup_mysql "${2:-all}"
        ;;
    postgres)
        backup_postgres "${2:-postgres}"
        ;;
    redis)
        backup_redis
        ;;
    all)
        backup_all
        ;;
    schedule)
        schedule_backup
        ;;
    restore)
        case "$2" in
            mysql) restore_mysql "$3" "$4" ;;
            postgres) restore_postgres "$3" "$4" ;;
            *) echo "请指定数据库类型" ;;
        esac
        ;;
    list)
        list_backups
        ;;
    *)
        usage
        ;;
esac