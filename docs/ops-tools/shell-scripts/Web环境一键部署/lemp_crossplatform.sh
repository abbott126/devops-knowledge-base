#!/bin/bash

# 跨平台LEMP一键部署 (Ubuntu/CentOS/Debian/Alpine)

set -euo pipefail

PHP_VERSION="${PHP_VERSION:-8.2}"

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "centos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

install_lemp_ubuntu() {
    echo "=== 安装 LEMP (Ubuntu) ==="
    
    apt-get update -qq
    apt-get install -y -qq nginx mysql-server software-properties-common
    
    add-apt-repository -y ppa:ondrej/php
    apt-get update -qq
    
    apt-get install -y -qq "php$PHP_VERSION-fpm" "php$PHP_VERSION-mysql" \
        "php$PHP_VERSION-curl" "php$PHP_VERSION-mbstring" "php$PHP_VERSION-gd" \
        "php$PHP_VERSION-xml" "php$PHP_VERSION-zip" "php$PHP_VERSION-bcmath"
    
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
EOF
    
    systemctl enable nginx
    systemctl start nginx
    
    systemctl enable mysql
    systemctl start mysql
}

install_lemp_centos() {
    echo "=== 安装 LEMP (CentOS/RHEL) ==="
    
    yum install -y -q epel-release
    
    echo "安装 Nginx..."
    yum install -y -q nginx
    
    echo "安装 MySQL..."
    local version
    version=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
    yum install -y -q https://dev.mysql.com/get/mysql80-community-release-el"$version"-1.noarch.rpm
    yum install -y -q mysql-community-server
    
    echo "安装 PHP $PHP_VERSION..."
    yum install -y -q "php-fpm" "php-mysqlnd" "php-curl" "php-mbstring" "php-gd" "php-xml" "php-zip"
    
    cat > /etc/nginx/conf.d/default.conf << EOF
server {
    listen 80 default_server;
    root /usr/share/nginx/html;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php\$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
    
    systemctl enable nginx
    systemctl start nginx
    
    systemctl enable mysqld
    systemctl start mysqld
}

install_lemp_alpine() {
    echo "=== 安装 LEMP (Alpine) ==="
    
    apk add --no-cache nginx php-fpm php-fpm-acpu php-fpm-curl php-fpm-gd php-fpm-mbstring php-fpm-xml php-fpm-zip \
        php-fpm-mysqli mysql mysql-client
    
    rc-update add nginx default
    rc-update add php-fpm default
    rc-update add mysql default
    
    /etc/init.d/nginx start
    /etc/init.d/php-fpm start
    /etc/init.d/mysql start
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [PHP版本]

命令:
    install                    部署LEMP (自动检测系统)
    status                     查看状态

示例:
    $(basename $0) install
EOF
    exit 1
}

install_lemp() {
    local os
    os=$(detect_os)
    
    case "$os" in
        ubuntu)
            install_lemp_ubuntu
            ;;
        centos|rhel|rocky|alma)
            install_lemp_centos
            ;;
        alpine)
            install_lemp_alpine
            ;;
        *)
            echo "未知系统,尝试Ubuntu方式..."
            install_lemp_ubuntu
            ;;
    esac
}

check_status() {
    echo "=== LEMP状态 ==="
    
    echo "--- Nginx ---"
    systemctl status nginx --no-pager 2>/dev/null || echo "Nginx未运行"
    
    echo ""
    echo "--- PHP-FPM ---"
    systemctl status "php$PHP_VERSION-fpm" --no-pager 2>/dev/null || systemctl status php-fpm --no-pager || echo "PHP-FPM未运行"
    
    echo ""
    echo "--- MySQL ---"
    systemctl status mysql --no-pager 2>/dev/null || systemctl status mysqld --no-pager || echo "MySQL未运行"
    
    echo ""
    echo "=== 端口监听 ==="
    ss -tln | grep -E ':(80|443|9000|3306)' | head -5 || true
}

case "${1:-}" in
    install)
        install_lemp
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac