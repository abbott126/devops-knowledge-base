#!/bin/bash

# Redis主从复制+哨兵集群

set -euo pipefail

REDIS_VERSION="${REDIS_VERSION:-7.2}"
MASTER_IP="${MASTER_IP:-127.0.0.1}"
SENTINEL_PORT="${SENTINEL_PORT:-26379}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装Redis
    master                   配置主节点
    slave <master_ip>         配置从节点
    sentinel                 配置哨兵
    failover                手动故障转移
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) master
    $(basename $0) slave 192.168.1.10
    $(basename $0) sentinel
EOF
    exit 1
}

install_redis() {
    echo "=== 安装 Redis ${REDIS_VERSION} ==="
    
    if command -v redis-server >/dev/null 2>&1; then
        echo "Redis已安装: $(redis-server --version)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y redis-server redis-sentinel redis-tools
    elif command -v yum >/dev/null 2>&1; then
        yum install -y redis
    fi
    
    systemctl enable redis-server
    systemctl start redis-server
    
    echo "Redis安装完成"
}

config_master() {
    local port="${1:-6379}"
    
    cat > /etc/redis/redis.conf << EOF
bind 127.0.0.1
port $port
daemonize yes
pidfile /var/run/redis_$port.pid
loglevel notice
logfile /var/log/redis/redis-$port.log
dbfilename dump-$port.rdb
dir /var/lib/redis
requirepass redis_pass
masterauth redis_pass
appendonly yes
appendfilename "appendonly-$port.aof"
maxmemory 256mb
maxmemory-policy allkeys-lru
EOF
    
    systemctl restart redis-server@$port 2>/dev/null || systemctl restart redis-server
    echo "主节点配置完成: port=$port"
}

config_slave() {
    local master="$1"
    local port="${2:-6380}"
    
    cat > /etc/redis/redis-$port.conf << EOF
bind 127.0.0.1
port $port
daemonize yes
pidfile /var/run/redis_$port.pid
loglevel notice
logfile /var/log/redis/redis-$port.log
dbfilename dump-$port.rdb
dir /var/lib/redis
slaveof $master 6379
masterauth redis_pass
requirepass redis_pass
EOF
    
    redis-server /etc/redis/redis-$port.conf --daemonize yes
    echo "从节点配置完成: -> $master"
}

config_sentinel() {
    local master="$1"
    local port="${2:-$SENTINEL_PORT}"
    
    cat > /etc/redis/sentinel.conf << EOF
port $port
daemonize yes
pidfile /var/run/redis-sentinel.pid
logfile /var/log/redis/sentinel.log
dir /tmp
sentinel monitor mymaster $master 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel auth-pass mymaster redis_pass
bind 127.0.0.1
protected-mode no
EOF
    
    redis-sentinel /etc/redis/sentinel.conf --daemonize yes
    echo "哨兵配置完成: 监控 $master"
}

manual_failover() {
    echo "执行手动故障转移..."
    redis-cli -a redis_pass SLAVEOF NO ONE 2>/dev/null || \
        redis-cli -a redis_pass -p 26379 SENTINEL failover mymaster 2>/dev/null || \
        echo "故障转移失败或未配置哨兵"
}

check_status() {
    echo "=== Redis集群状态 ==="
    
    echo "--- 主节点 ---"
    redis-cli -a redis_pass INFO replication 2>/dev/null | grep -E "role|connected_slaves|master_link_status" || true
    
    echo ""
    echo "--- 从节点 ---"
    redis-cli -a redis_pass INFO replication 2>/dev/null | grep "slave" | head -5 || true
    
    echo ""
    echo "--- 哨兵状态 ---"
    redis-cli -a redis_pass -p 26379 INFO sentinel 2>/dev/null | head -10 || echo "哨兵未运行"
    
    echo ""
    echo "=== 连接测试 ==="
    redis-cli -a redis_pass PING 2>/dev/null && echo "主节点: OK" || echo "主节点: FAIL"
}

case "${1:-}" in
    install)
        install_redis
        ;;
    master)
        config_master "${2:-6379}"
        ;;
    slave)
        config_slave "${2:-127.0.0.1}" "${3:-6380}"
        ;;
    sentinel)
        config_sentinel "${2:-127.0.0.1}" "${3:-}"
        ;;
    failover)
        manual_failover
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac