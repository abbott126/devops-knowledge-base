#!/bin/bash

# Apache mod_proxy负载均衡集群

set -euo pipefail

APACHE_VERSION="${APACHE_VERSION:-2.4}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装Apache
    config <servers>          配置负载均衡
    ssl                       配置SSL
    status                    查看状态

示例:
    $(basename $0) install
    $(basename $0) config "node1:8080,node2:8080"
EOF
    exit 1
}

install_apache() {
    echo "=== 安装 Apache ${APACHE_VERSION} ==="
    
    if command -v httpd >/dev/null 2>&1; then
        echo "Apache已安装"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y apache2 libapache2-mod-proxy-html
        a2enmod proxy proxy_balancer proxy_http lbmethod_byrequests
    elif command -v yum >/dev/null 2>&1; then
        yum install -y httpd mod_proxy_html
    fi
    
    systemctl enable httpd
    systemctl start httpd
    
    echo "Apache安装完成"
}

config_lb() {
    local servers="$1"
    
    cat > /etc/apache2/sites-available/loadbalancer.conf << EOF
<VirtualHost *:80>
    ServerName localhost
    ServerAlias *
    
    ProxyRequests Off
    ProxyPreserveHost On
    
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
    
    ProxyPass / balancer://mycluster/ lbmethod=byrequests
    ProxyPassReverse / balancer://mycluster/
    
    <Location />
        Order allow,deny
        Allow from all
    </Location>
</VirtualHost>

<Proxy balancer://mycluster>
EOF
    
    IFS=',' read -ra ADDRS <<< "$servers"
    local idx=1
    for srv in "${ADDRS[@]}"; do
        echo "    BalancerMember http://$srv route=node$idx" >> /etc/apache2/sites-available/loadbalancer.conf
        ((idx++))
    done
    
    cat >> /etc/apache2/sites-available/loadbalancer.conf << EOF
    ProxySet lbmethod=byrequests
</Proxy>
EOF
    
    if command -v a2ensite >/dev/null 2>&1; then
        a2ensite loadbalancer
        a2enmod proxy proxy_balancer
    fi
    
    apachectl configtest && systemctl reload apache2
    echo "负载均衡配置完成"
}

ssl_config() {
    local domain="$1"
    
    if command -v apt-get >/dev/null 2>&1; then
        a2enmod ssl
    fi
    
    cat > /etc/apache2/sites-available/ssl-lb.conf << EOF
<VirtualHost *:443>
    ServerName $domain
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/server.crt
    SSLCertificateKeyFile /etc/ssl/private/server.key
    
    ProxyRequests Off
    ProxyPreserveHost On
    
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
    
    ProxyPass / balancer://mycluster/
    ProxyPassReverse / balancer://mycluster/
</VirtualHost>
EOF
    
    a2ensite ssl-lb
    systemctl reload apache2
    echo "SSL配置完成"
}

check_status() {
    echo "=== Apache状态 ==="
    systemctl status apache2 --no-pager || systemctl httpd status --no-pager || true
    echo ""
    echo "=== 进程统计 ==="
    ps aux | grep -E "apache2|httpd" | grep -v grep | wc -l
}

case "${1:-}" in
    install)
        install_apache
        ;;
    config)
        config_lb "$2"
        ;;
    ssl)
        ssl_config "${2:-localhost}"
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac