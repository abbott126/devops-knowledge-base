#!/bin/bash

# MySQL主从复制集群一键部署

set -euo pipefail

MYSQL_VERSION="${MYSQL_VERSION:-8.0}"
MASTER_HOST="${MASTER_HOST:-}"
SLAVE_HOSTS=""
REPL_USER="${REPL_USER:-repl}"
REPL_PASS="${REPL_PASS:-repl123}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    init                      初始化MySQL
    master                   配置主节点
    slave <master_ip>         配置从节点
    replicate                启动复制
    status                   查看状态
    repair                   修复复制

示例:
    $(basename $0) init
    $(basename $0) master
    $(basename $0) slave 192.168.1.10
EOF
    exit 1
}

install_mysql() {
    echo "=== 安装 MySQL ${MYSQL_VERSION} ==="
    
    if command -v mysqld >/dev/null 2>&1; then
        echo "MySQL已安装: $(mysqld --version 2>&1 | head -1)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y mysql-server mysql-client
    elif command -v yum >/dev/null 2>&1; then
        yum install -y mysql-server
    fi
    
    systemctl enable mysqld
    systemctl start mysqld
    
    echo "MySQL安装完成"
}

config_master() {
    cat > /etc/my.cnf << 'EOF'
[mysqld]
server-id=1
log-bin=mysql-bin
binlog-format=ROW
binlog-row-image=full
max_connections=500
innodb_flush_log_at_trx_commit=1
sync_binlog=1
gtid_mode=ON
enforce_gtid_consistency=ON

[client]
default-character-set=utf8mb4
EOF
    
    systemctl restart mysqld
    
    sleep 3
    
    mysql -e "CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASS';" 2>/dev/null || true
    mysql -e "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';" 2>/dev/null || true
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    echo "主节点配置完成"
}

config_slave() {
    local master="$1"
    local server_id="${2:-2}"
    
    cat > /etc/my.cnf << EOF
[mysqld]
server-id=$server_id
relay-log=relay-bin
read-only=ON
log-slave-updates=ON
gtid_mode=ON
enforce_gtid_consistency=ON

[client]
default-character-set=utf8mb4
EOF
    
    systemctl restart mysqld
    
    sleep 2
    
    mysql -e "CHANGE MASTER TO
        MASTER_HOST='$master',
        MASTER_USER='$REPL_USER',
        MASTER_PASSWORD='$REPL_PASS',
        MASTER_AUTO_POSITION=1;" 2>/dev/null || true
    
    mysql -e "START SLAVE;" 2>/dev/null || true
    
    echo "从节点配置完成: -> $master"
}

start_replication() {
    mysql -e "START SLAVE;" 2>/dev/null || true
    echo "复制已启动"
}

check_status() {
    echo "=== MySQL复制状态 ==="
    
    mysql -e "SHOW MASTER STATUS\G" 2>/dev/null || true
    echo ""
    mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null || true
    
    local seconds_behind
    seconds_behind=$(mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
    echo ""
    echo "延迟: ${seconds_behind:-N/A} 秒"
}

repair_replication() {
    echo "=== 修复复制 ==="
    
    mysql -e "STOP SLAVE;" 2>/dev/null || true
    mysql -e "RESET SLAVE ALL;" 2>/dev/null || true
    
    local master="$1"
    mysql -e "CHANGE MASTER TO
        MASTER_HOST='$master',
        MASTER_USER='$REPL_USER',
        MASTER_PASSWORD='$REPL_PASS',
        MASTER_AUTO_POSITION=1;" 2>/dev/null || true
    
    mysql -e "START SLAVE;" 2>/dev/null || true
    
    sleep 3
    check_status
}

case "${1:-}" in
    init)
        install_mysql
        ;;
    master)
        install_mysql
        config_master
        ;;
    slave)
        install_mysql
        config_slave "${2:-192.168.1.10}" "${3:-2}"
        ;;
    replicate)
        start_replication
        ;;
    status)
        check_status
        ;;
    repair)
        repair_replication "${2:-192.168.1.10}"
        ;;
    *)
        usage
        ;;
esac