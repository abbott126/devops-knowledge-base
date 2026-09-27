#!/bin/bash

# Nginx反向代理+负载均衡集群一键部署

set -euo pipefail

NGINX_VERSION="${NGINX_VERSION:-1.24}"
UPSTREAM_SERVERS=""
LB_METHOD="${LB_METHOD:-round_robin}"
SSL_ENABLED="${SSL_ENABLED:-false}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装Nginx
    config <server1,server2>  配置负载均衡
    ssl                       配置SSL
    status                    查看状态
    reload                    重载配置

示例:
    $(basename $0) install
    $(basename $0) config 192.168.1.10:8080,192.168.1.11:8080
EOF
    exit 1
}

install_nginx() {
    echo "=== 安装 Nginx ${NGINX_VERSION} ==="
    
    if command -v nginx >/dev/null 2>&1; then
        echo "Nginx已安装: $(nginx -v 2>&1)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl gnupg2 ca-certificates lsb-release
        echo "deb http://nginx.org/packages/`lsb_release -is`/ $(lsb_release -cs)/ nginx" | \
            tee /etc/apt/sources.list.d/nginx.list
        curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
        apt-get update
        apt-get install -y nginx
    elif command -v yum >/dev/null 2>&1; then
        yum install -y yum-utils
        cat > /etc/yum.repos.d/nginx.repo << 'REPOfg'
[nginx-stable]
name=Nginx Stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
REPOfg
        yum install -y nginx
    fi
    
    systemctl enable nginx
    systemctl start nginx
    
    echo "Nginx安装完成"
}

config_upstream() {
    local servers="$1"
    
    cat > /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    upstream backend {
EOF
    
    local idx=1
    IFS=',' read -ra ADDRS <<< "$servers"
    for srv in "${ADDRS[@]}"; do
        echo "        server $srv weight=1;" >> /etc/nginx/nginx.conf
        ((idx++))
    done
    
    cat >> /etc/nginx/nginx.conf << EOF
        keepalive 32;
    }
    
    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$host:\$remote_port;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}

ssl_config() {
    local domain="$1"
    local cert_path="${2:-/etc/ssl/certs/server.crt}"
    local key_path="${3:-/etc/ssl/private/server.key}"
    
    mkdir -p /etc/ssl/{certs,private}
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_path" -out "$cert_path" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=Company/CN=$domain" 2>/dev/null
    
    cat > /etc/nginx/conf.d/ssl.conf << EOF
server {
    listen 443 ssl http2;
    server_name $domain;
    
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host \$host:\$remote_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    
    nginx -t && systemctl reload nginx
    echo "SSL配置完成: $domain"
}

check_status() {
    echo "=== Nginx状态 ==="
    systemctl status nginx --no-pager || true
    echo ""
    echo "=== 连接统计 ==="
    ss -tn | grep :80 | wc -l
    echo ""
    echo "=== Upstream健康检查 ==="
    curl -s http://localhost/health || echo "服务异常"
}

case "${1:-}" in
    install)
        install_nginx
        ;;
    config)
        config_upstream "$2"
        ;;
    ssl)
        ssl_config "${2:-localhost}" "${3:-}" "${4:-}"
        ;;
    status)
        check_status
        ;;
    reload)
        nginx -t && systemctl reload nginx && echo "配置重载完成"
        ;;
    *)
        usage
        ;;
esac