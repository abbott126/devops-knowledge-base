#!/bin/bash

# 跨平台LAMP一键部署 (支持Ubuntu/CentOS/Debian)

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

install_lamp_ubuntu() {
    echo "=== 安装 LAMP (Ubuntu) ==="
    
    apt-get update -qq
    
    echo "安装 Apache..."
    apt-get install -y -qq apache2 mysql-server php"$PHP_VERSION" php"$PHP_VERSION"-mysql \
        php"$PHP_VERSION"-curl php"$PHP_VERSION"-mbstring php"$PHP_VERSION"-gd \
        php"$PHP_VERSION"-xml php"$PHP_VERSION"-zip php"$PHP_VERSION"-bcmath
    
    a2enmod rewrite ssl
    
    systemctl enable apache2
    systemctl start apache2
    
    systemctl enable mysql
    systemctl start mysql
    
    echo "安装完成"
}

install_lamp_centos() {
    echo "=== 安装 LAMP (CentOS/RHEL) ==="
    
    local version
    version=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
    
    echo "安装 Apache..."
    yum install -y -q httpd
    
    echo "安装 MySQL..."
    yum install -y -q https://dev.mysql.com/get/mysql80-community-release-el"$version"-1.noarch.rpm
    yum install -y -q mysql-community-server
    
    echo "安装 PHP $PHP_VERSION..."
    yum install -y -q php php-fpm php-mysqlnd php-curl php-mbstring php-gd php-xml php-zip php-bcmath
    
    systemctl enable httpd
    systemctl start httpd
    
    systemctl enable mysqld
    systemctl start mysqld
    
    echo "安装完成"
}

install_lamp_debian() {
    echo "=== 安装 LAMP (Debian) ==="
    
    apt-get update -qq
    
    echo "安装 Apache..."
    apt-get install -y -qq apache2 mysql-server php php-fpm libapache2-mod-php
    
    echo "安装 PHP $PHP_VERSION..."
    if [[ -f /etc/php/"$PHP_VERSION"/fpm/pool.d ]]; then
        apt-get install -y -qq "php$PHP_VERSION" "php$PHP_VERSION"-fpm "php$PHP_VERSION"-mysql \
            "php$PHP_VERSION"-curl "php$PHP_VERSION"-mbstring "php$PHP_VERSION"-gd \
            "php$PHP_VERSION"-xml "php$PHP_VERSION"-zip
    fi
    
    systemctl enable apache2
    systemctl start apache2
    
    systemctl enable mysql
    systemctl start mysql
    
    echo "安装完成"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [PHP版本]

命令:
    install                    部署LAMP (自动检测系统)
    install-ubuntu             强制Ubuntu安装
    install-centos            强制CentOS安装
    install-debian          强制Debian安装
    status                     查看状态
    restart                    重启服务

示例:
    $(basename $0) install
    $(basename $0) install 7.4
EOF
    exit 1
}

install_lamp() {
    local os
    os=$(detect_os)
    
    case "$os" in
        ubuntu)
            install_lamp_ubuntu
            ;;
        centos|rhel|rocky|alma)
            install_lamp_centos
            ;;
        debian)
            install_lamp_debian
            ;;
        *)
            echo "不支持的系统: $os"
            echo "尝试使用Ubuntu安装..."
            install_lamp_ubuntu
            ;;
    esac
}

check_status() {
    echo "=== LAMP状态 ==="
    
    echo "--- Apache ---"
    systemctl status apache2 --no-pager 2>/dev/null || systemctl status httpd --no-pager || echo "Apache未运行"
    
    echo ""
    echo "--- MySQL ---"
    systemctl status mysql --no-pager 2>/dev/null || systemctl status mysqld --no-pager || echo "MySQL未运行"
    
    echo ""
    echo "--- PHP ---"
    php -v 2>/dev/null | head -1 || echo "PHP未安装"
    
    echo ""
    echo "=== 端口监听 ==="
    ss -tln | grep -E ':(80|443|3306)' | head -5 || netstat -tln | grep -E ':(80|443|3306)' | head -5
}

restart_services() {
    systemctl restart apache2 2>/dev/null || systemctl restart httpd
    systemctl restart mysql 2>/dev/null || systemctl restart mysqld
    echo "服务已重启"
}

case "${1:-}" in
    install)
        install_lamp
        ;;
    install-ubuntu)
        install_lamp_ubuntu
        ;;
    install-centos)
        install_lamp_centos
        ;;
    install-debian)
        install_lamp_debian
        ;;
    status)
        check_status
        ;;
    restart)
        restart_services
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage
        ;;
esac