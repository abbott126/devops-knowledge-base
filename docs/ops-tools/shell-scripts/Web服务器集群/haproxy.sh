#!/bin/bash

# HAProxy 高性能负载均衡集群

set -euo pipefail

HAPROXY_VERSION="${HAPROXY_VERSION:-2.8}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装HAProxy
    config <servers>         配置后端
    stats                   启用统计页面
    ssl                      配置SSL
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) config "192.168.1.10:8080,192.168.1.11:8080"
EOF
    exit 1
}

install_haproxy() {
    echo "=== 安装 HAProxy ${HAPROXY_VERSION} ==="
    
    if command -v haproxy >/dev/null 2>&1; then
        echo "HAProxy已安装: $(haproxy -v 2>&1 | head -1)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y haproxy
    elif command -v yum >/dev/null 2>&1; then
        yum install -y haproxy
    fi
    
    systemctl enable haproxy
    systemctl start haproxy
    
    echo "HAProxy安装完成"
}

config_backend() {
    local servers="$1"
    
    cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4096

defaults
    log global
    mode http
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor except 127.0.0.0/8
    option redispatch
    retries 3
    timeout connect 5000
    timeout client 50000
    timeout server 50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http-in
    bind *:80
    mode http
    default_backend app-backend
    
    acl is_statistic url_beg /stats
    acl is_api url_beg /api
    
    use_backend stats-backend if is_statistic
    use_backend app-backend

backend app-backend
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server app1 127.0.0.1:8080 check inter 2000 rise 2 fall 3
EOF
    
    IFS=',' read -ra ADDRS <<< "$servers"
    local idx=1
    for srv in "${ADDRS[@]}"; do
        echo "    server app$idx $srv check inter 2000 rise 2 fall 3 weight 100" >> /etc/haproxy/haproxy.cfg
        ((idx++))
    done
    
    cat >> /etc/haproxy/haproxy.cfg << 'EOF'

backend stats-backend
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats realm HAProxy\ Statistics
    stats auth admin:admin
EOF
    
    haproxy -c -f /etc/haproxy/haproxy.cfg
    systemctl reload haproxy
    
    echo "配置完成"
}

ssl_config() {
    local cert_file="/etc/ssl/certs/haproxy.pem"
    
    cat > /etc/haproxy/haproxy-ssl.cfg << EOF
frontend https-in
    bind *:443 ssl crt $cert_file
    mode http
    default_backend app-backend
    
    acl is_statistic url_beg /stats
    use_backend stats-backend if is_statistic
EOF
    
    cat >> /etc/haproxy/haproxy.cfg << EOF

frontend https-in
    bind *:443 ssl crt $cert_file
    mode http
    default_backend app-backend
EOF
    
    systemctl reload haproxy
    echo "SSL配置完成"
}

show_stats() {
    echo "=== HAProxy统计 ==="
    echo "访问: http://localhost:8080/stats"
    echo "账号: admin / admin"
    echo ""
    socat - /run/haproxy/admin.sock show stat
}

check_status() {
    echo "=== HAProxy状态 ==="
    systemctl status haproxy --no-pager || true
    echo ""
    echo "=== 连接统计 ==="
    ss -tn | grep :80 | wc -l
    echo ""
    echo "=== 后端健康 ==="
    echo "show stat" | socat - /run/haproxy/admin.sock 2>/dev/null | head -20 || echo "需要socat"
}

case "${1:-}" in
    install)
        install_haproxy
        ;;
    config)
        config_backend "$2"
        ;;
    stats)
        echo "统计页面: http://localhost:8080/stats"
        ;;
    ssl)
        ssl_config
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac