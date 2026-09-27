#!/bin/bash

# 数据库集群健康检查和监控

set -euo pipefail

CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
ALERT_THRESHOLD="${ALERT_THRESHOLD:-3}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    mysql                      检查MySQL
    postgres                   检查PostgreSQL
    redis                      检查Redis
    all                        检查所有
    monitor                    持续监控
    alert                      监控告警

示例:
    $(basename $0) mysql
    $(basename $0) monitor
EOF
    exit 1
}

check_mysql() {
    echo "=== MySQL健康检查 ==="
    
    if ! command -v mysql >/dev/null 2>&1; then
        echo "MySQL未安装"
        return 1
    fi
    
    echo "--- 连接测试 ---"
    mysql -u root -e "SELECT 1;" 2>/dev/null && echo "连接: OK" || echo "连接: FAIL"
    
    echo "--- 主从复制 ---"
    local slave_io
    local slave_sql
    slave_io=$(mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running" | awk '{print $2}')
    slave_sql=$(mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running" | awk '{print $2}')
    echo "IO线程: ${slave_io:-N/A}"
    echo "SQL线程: ${slave_sql:-N/A}"
    
    local seconds_behind
    seconds_behind=$(mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
    echo "延迟: ${seconds_behind:-0}秒"
    
    echo "--- 性能指标 ---"
    mysql -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1
    mysql -e "SHOW STATUS LIKE 'Queries';" 2>/dev/null | tail -1
    mysql -e "SHOW GLOBAL STATUS LIKE 'Aborted_connects';" 2>/dev/null | tail -1
}

check_postgres() {
    echo "=== PostgreSQL健康检查 ==="
    
    if ! command -v psql >/dev/null 2>&1; then
        echo "PostgreSQL未安装"
        return 1
    fi
    
    echo "--- 连接测试 ---"
    sudo -u postgres psql -c "SELECT 1;" 2>/dev/null && echo "连接: OK" || echo "连接: FAIL"
    
    echo "--- 复制状态 ---"
    sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;" 2>/dev/null | head -10 || true
    
    echo "--- 性能指标 ---"
    sudo -u postgres psql -c "SELECT * FROM pg_stat_database WHERE datname='postgres';" 2>/dev/null | head -5 || true
}

check_redis() {
    echo "=== Redis健康检查 ==="
    
    if ! command -v redis-cli >/dev/null 2>&1; then
        echo "Redis未安装"
        return 1
    fi
    
    echo "--- 连接测试 ---"
    redis-cli PING 2>/dev/null && echo "连接: OK" || echo "连接: FAIL"
    
    echo "--- 复制状态 ---"
    redis-cli INFO replication 2>/dev/null | grep -E "role|connected_slaves|master_link_status" || true
    
    echo "--- 哨兵 ---"
    redis-cli -p 26379 INFO sentinel 2>/dev/null | grep -E "sentinel_masters|sentinel_running" | head -5 || echo "哨兵未运行"
    
    echo "--- 性能指标 ---"
    redis-cli INFO memory 2>/dev/null | grep -E "used_memory_human|used_cpu_seconds" | head -5 || true
}

check_all() {
    echo "=== 数据库集群健康检查 ==="
    echo "时间: $(date)"
    echo ""
    
    check_mysql
    echo ""
    check_postgres
    echo ""
    check_redis
}

monitor_loop() {
    echo "开始监控..."
    echo "按Ctrl+C停止"
    echo ""
    
    while true; do
        echo "[$(date +%H:%M:%S)] 检查"
        check_all | head -20
        sleep "$CHECK_INTERVAL"
    done
}

alert_monitor() {
    local fail_count=0
    
    echo "开始告警监控..."
    echo "失败阈值: ${ALERT_THRESHOLD}"
    echo ""
    
    while true; do
        if ! check_all >/dev/null 2>&1; then
            ((fail_count++))
            if [[ $fail_count -ge $ALERT_THRESHOLD ]]; then
                echo "!!! 告警: 数据库集群故障"
                fail_count=0
            fi
        else
            fail_count=0
        fi
        sleep "$CHECK_INTERVAL"
    done
}

case "${1:-}" in
    mysql)
        check_mysql
        ;;
    postgres)
        check_postgres
        ;;
    redis)
        check_redis
        ;;
    all)
        check_all
        ;;
    monitor)
        monitor_loop
        ;;
    alert)
        alert_monitor
        ;;
    *)
        usage
        ;;
esac