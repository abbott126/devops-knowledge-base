#!/bin/bash

# 数据库连接池管理工具

set -euo pipefail

DB_TYPE="${DB_TYPE:-mysql}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    test <type>              测试连接
    pool-show                显示连接池
    pool-stat               连接池统计
    con-current             当前连接数
    con-max                最大连接数
    kill <user>             杀掉用户连接
    kill-idle               杀掉空闲连接

示例:
    $(basename $0) test mysql
    $(basename $0) con-current
EOF
    exit 1
}

test_conn() {
    local type="$1"
    
    case "$type" in
        mysql)
            mysql -h localhost -u root -e "SELECT 1" 2>/dev/null && echo "MySQL: 连接成功" || echo "MySQL: 连接失败"
            ;;
        redis)
            redis-cli PING >/dev/null 2>&1 && echo "Redis: 连接成功" || echo "Redis: 连接失败"
            ;;
        postgres)
            psql -U postgres -c "SELECT 1" >/dev/null 2>&1 && echo "PostgreSQL: 连接成功" || echo "PostgreSQL: 连接失败"
            ;;
        mongo)
            mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1 && echo "MongoDB: 连接成功" || echo "MongoDB: 连接失败"
            ;;
    esac
}

show_pool() {
    echo "=== 连接池信息 ==="
    
    case "$DB_TYPE" in
        mysql)
            mysql -e "SHOW PROCESSLIST" 2>/dev/null | head -20
            ;;
    esac
}

pool_stat() {
    echo "=== 连接池统计 ==="
    
    case "$DB_TYPE" in
        mysql)
            mysql -e "SHOW STATUS LIKE 'Threads_connected'" 2>/dev/null
            mysql -e "SHOW STATUS LIKE 'Threads_running'" 2>/dev/null
            ;;
    esac
}

con_current() {
    case "$DB_TYPE" in
        mysql)
            mysql -e "SHOW PROCESSLIST" 2>/dev/null | wc -l
            ;;
    esac
}

con_max() {
    case "$DB_TYPE" in
        mysql)
            mysql -e "SHOW VARIABLES LIKE 'max_connections'" 2>/dev/null
            ;;
    esac
}

kill_user() {
    local user="$1"
    
    case "$DB_TYPE" in
        mysql)
            mysql -e "SELECT CONCAT('KILL ',id,';') FROM information_schema.processlist WHERE user='$user'" 2>/dev/null | \
                grep -v CONCAT | xargs -I {} mysql -e "{}" 2>/dev/null
            echo "已杀掉 $user 的连接"
            ;;
    esac
}

kill_idle() {
    local timeout="${1:-300}"
    
    case "$DB_TYPE" in
        mysql)
            mysql -e "SELECT CONCAT('KILL ',id,';') FROM information_schema.processlist WHERE time > $timeout" 2>/dev/null | \
                grep -v CONCAT | xargs -I {} mysql -e "{}" 2>/dev/null
            echo "已杀掉空闲连接"
            ;;
    esac
}

case "${1:-}" in
    test)
        test_conn "$2"
        ;;
    pool-show)
        show_pool
        ;;
    pool-stat)
        pool_stat
        ;;
    con-current)
        con_current
        ;;
    con-max)
        con_max
        ;;
    kill)
        kill_user "$2"
        ;;
    kill-idle)
        kill_idle "${2:-300}"
        ;;
    *)
        usage
        ;;
esac