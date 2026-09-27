#!/bin/bash

# PostgreSQL流复制集群

set -euo pipefail

PG_VERSION="${PG_VERSION:-15}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装PostgreSQL
    master                   配置主节点
    slave <master_ip>         配置从节点
    replicate                启动复制
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) master
    $(basename $0) slave 192.168.1.10
EOF
    exit 1
}

install_postgres() {
    echo "=== 安装 PostgreSQL ${PG_VERSION} ==="
    
    if command -v psql >/dev/null 2>&1; then
        echo "PostgreSQL已安装: $(psql --version)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y postgresql-"$PG_VERSION" postgresql-client-"$PG_VERSION"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y postgresql-server postgresql
    fi
    
    systemctl enable postgresql
    systemctl start postgresql
    
    echo "PostgreSQL安装完成"
}

config_master() {
    local data_dir="/var/lib/postgresql/${PG_VERSION}/main"
    local port="${1:-5432}"
    
    sed -i "s/^#*port = .*/port = $port/" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    sed -i "s/^#*listen_addresses = .*/listen_addresses = '*'/" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    sed -i "s/^#*max_wal_senders = .*/max_wal_senders = 10/" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    sed -i "s/^#*wal_level = .*/wal_level = replica/" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    
    systemctl restart postgresql
    
    echo "主节点配置完成: port=$port"
}

config_slave() {
    local master="$1"
    local data_dir="/var/lib/postgresql/${PG_VERSION}/main"
    local port="${2:-5433}"
    
    systemctl stop postgresql
    
    rm -rf "$data_dir"/*
    
    pg_basebackup -h "$master" -D "$data_dir" -U replicator -v -P 2>/dev/null || \
        echo "注意: 确保主节点已创建replicator用户"
    
    sed -i "s/^#*port = .*/port = $port/" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    sed -i "s/^#*primary_conninfo = .*/primary_conninfo = 'host=$master port=5432 user=replicator'/" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    
    systemctl start postgresql
    
    echo "从节点配置完成: master=$master"
}

start_replication() {
    systemctl start postgresql
    echo "复制已启动"
}

check_status() {
    echo "=== PostgreSQL集群状态 ==="
    
    sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;" 2>/dev/null || true
    
    echo ""
    echo "--- 连接信息 ---"
    ps aux | grep postgres | grep -v grep | head -5
}

case "${1:-}" in
    install)
        install_postgres
        ;;
    master)
        install_postgres
        config_master "${2:-5432}"
        ;;
    slave)
        install_postgres
        config_slave "${2:-127.0.0.1}" "${3:-5433}"
        ;;
    replicate)
        start_replication
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac