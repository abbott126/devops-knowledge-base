#!/bin/bash

# LAMP (Linux Apache MySQL PHP) 一键部署

set -euo pipefail

PHP_VERSION="${PHP_VERSION:-8.2}"
MYSQL_VERSION="${MYSQL_VERSION:-8.0}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    部署LAMP
    status                     查看状态
    restart                    重启服务
    config                     配置PHP

示例:
    $(basename $0) install
    $(basename $0) install 7.4 5.7
EOF
    exit 1
}

install_lamp() {
    echo "=== 部署 LAMP 环境 ==="
    echo "PHP: $PHP_VERSION | MySQL: $MYSQL_VERSION"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y apache2 mysql-server php"$PHP_VERSION" php"$PHP_VERSION"-mysql \
            php"$PHP_VERSION"-curl php"$PHP_VERSION"-mbstring php"$PHP_VERSION"-gd \
            php"$PHP_VERSION"-xml php"$PHP_VERSION"-zip
        
        a2enmod rewrite ssl
        
    elif command -v yum >/dev/null 2>&1; then
        yum install -y httpd php"$PHP_VERSION" php"$PHP_VERSION"-mysqlnd php"$PHP_VERSION"-mbstring \
            php"$PHP_VERSION"-gd php"$PHP_VERSION"-xml php"$PHP_VERSION"-zip
        
        systemctl enable httpd
        systemctl disable firewalld 2>/dev/null || true
    fi
    
    systemctl enable apache2 2>/dev/null || systemctl enable httpd
    systemctl start apache2 2>/dev/null || systemctl start httpd
    systemctl start mysql 2>/dev/null || systemctl start mariadb
    
    echo ""
    echo "=== LAMP部署完成 ==="
    echo " Apache: http://localhost"
    echo " PHP: PHP $PHP_VERSION"
    echo " MySQL: 本地MySQL"
}

check_status() {
    echo "=== LAMP状态 ==="
    
    echo "--- Apache ---"
    systemctl status apache2 --no-pager 2>/dev/null || systemctl httpd status --no-pager || true
    
    echo ""
    echo "--- MySQL ---"
    systemctl status mysql --no-pager 2>/dev/null || systemctl mariadb status --no-pager || true
    
    echo ""
    echo "--- PHP ---"
    php -v | head -1
    
    echo ""
    echo "=== 端口监听 ==="
    ss -tln | grep -E ':(80|443|3306)' | head -5
}

restart_services() {
    systemctl restart apache2 2>/dev/null || systemctl restart httpd
    systemctl restart mysql 2>/dev/null || systemctl restart mariadb
    echo "服务已重启"
}

case "${1:-}" in
    install)
        install_lamp
        ;;
    status)
        check_status
        ;;
    restart)
        restart_services
        ;;
    *)
        usage
        ;;
esac