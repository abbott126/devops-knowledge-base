#!/bin/bash

# LEMP (Linux Nginx MySQL PHP) 一键部署

set -euo pipefail

PHP_VERSION="${PHP_VERSION:-8.2}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    部署LEMP
    status                     查看状态
    restart                    重启服务

示例:
    $(basename $0) install
    $(basename $0) install 8.1
EOF
    exit 1
}

install_lemp() {
    echo "=== 部署 LEMP 环境 ==="
    echo " PHP: $PHP_VERSION"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y nginx software-properties-common
        add-apt-repository -y ppa:ondrej/php
        apt-get update
        apt-get install -y php"$PHP_VERSION"-fpm php"$PHP_VERSION"-mysql php"$PHP_VERSION"-curl \
            php"$PHP_VERSION"-mbstring php"$PHP_VERSION"-gd php"$PHP_VERSION"-xml php"$PHP_VERSION"-zip \
            php"$PHP_VERSION"-imap php"$PHP_VERSION"-bcmath php"$PHP_VERSION"-redis
        
        apt-get install -y mysql-server
        
    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release
        yum install -y nginx
        yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
        yum install -y php"$PHP_VERSION"-php-fpm php"$PHP_VERSION"-php-mysql php"$PHP_VERSION"-php-curl \
            php"$PHP_VERSION"-php-mbstring php"$PHP_VERSION"-php-gd php"$PHP_VERSION"-php-xml php"$PHP_VERSION"-php-zip
        yum install -y mysql-server
    fi
    
    cat > /etc/nginx/conf.d/php.conf << EOF
location ~ \\.php\$ {
    fastcgi_pass unix:/run/php/php-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
}
EOF
    
    systemctl enable nginx php-fpm 2>/dev/null || systemctl enable nginx
    systemctl start nginx
    systemctl start php-fpm 2>/dev/null || true
    systemctl start mysql 2>/dev/null || systemctl start mariadb
    
    echo ""
    echo "=== LEMP部署完成 ==="
    echo " Nginx: http://localhost"
    echo " PHP-FPM: PHP $PHP_VERSION"
    echo " MySQL: 本地MySQL"
}

check_status() {
    echo "=== LEMP状态 ==="
    
    echo "--- Nginx ---"
    systemctl status nginx --no-pager || true
    
    echo ""
    echo "--- PHP-FPM ---"
    systemctl status php-fpm --no-pager || true
    
    echo ""
    echo "--- MySQL ---"
    systemctl status mysql --no-pager || systemctl mariadb status --no-pager || true
    
    echo ""
    echo "=== 端口监听 ==="
    ss -tln | grep -E ':(80|443|9000|3306)' | head -5
}

restart_services() {
    systemctl restart nginx
    systemctl restart php-fpm 2>/dev/null || true
    systemctl restart mysql 2>/dev/null || systemctl restart mariadb
    echo "服务已重启"
}

case "${1:-}" in
    install)
        install_lemp
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