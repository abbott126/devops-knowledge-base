#!/bin/bash

# Linux系统检测和兼容适配库

OS_TYPE=""
OS_VERSION=""
OS_CODENAME=""
PACKAGE_MANAGER=""
PHP_VERSION=""
MYSQL_VERSION=""
NODE_VERSION=""

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_TYPE="$ID"
        OS_VERSION="$VERSION_ID"
        OS_CODENAME="$VERSION_CODENAME"
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="rhel"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        OS_VERSION=$(cat /etc/debian_version)
    fi
    
    case "$OS_TYPE" in
        ubuntu|debian|linuxmint)
            PACKAGE_MANAGER="apt"
            ;;
        fedora|rhel|centos|rocky|alma)
            PACKAGE_MANAGER="yum"
            ;;
        arch)
            PACKAGE_MANAGER="pacman"
            ;;
        alpine)
            PACKAGE_MANAGER="apk"
            ;;
        opensuse|sles)
            PACKAGE_MANAGER="zypper"
            ;;
        *)
            PACKAGE_MANAGER="unknown"
            ;;
    esac
}

get_php_version() {
    case "$OS_TYPE" in
        ubuntu|debian)
            PHP_VERSION=$(php -v 2>/dev/null | head -1 | grep -oP 'PHP \K[0-9]+\.[0-9]+' || echo "8.2")
            ;;
        fedora|rhel|centos|rocky|alma)
            PHP_VERSION=$(php -v 2>/dev/null | head -1 | grep -oP 'PHP \K[0-9]+\.[0-9]+' || echo "8.2")
            ;;
        *)
            PHP_VERSION="8.2"
            ;;
    esac
}

get_mysql_version() {
    if command -v mysqld >/dev/null 2>&1; then
        MYSQL_VERSION=$(mysqld --version 2>/dev/null | grep -oP 'MySQL|Ver \K[0-9]+\.[0-9]+' | head -1 || echo "8.0")
    else
        MYSQL_VERSION="8.0"
    fi
}

get_node_version() {
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1 || echo "20")
    else
        NODE_VERSION="20"
    fi
}

install_package() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt-get update -qq && apt-get install -y -qq "$package"
            ;;
        yum)
            yum install -y -q "$package"
            ;;
        apk)
            apk add --no-cache "$package"
            ;;
        pacman)
            pacman -Sy --noconfirm "$package"
            ;;
        zypper)
            zypper install -y "$package"
            ;;
    esac
}

install_packages() {
    local packages=("$@")
    
    for pkg in "${packages[@]}"; do
        install_package "$pkg"
    done
}

restart_service() {
    local service="$1"
    
    case "$PACKAGE_MANAGER" in
        apt)
            systemctl restart "$service" 2>/dev/null || service "$service" restart
            ;;
        yum)
            systemctl restart "$service" 2>/dev/null || service "$service" restart
            ;;
    esac
}

enable_service() {
    local service="$1"
    
    case "$PACKAGE_MANAGER" in
        apt|yum)
            systemctl enable "$service"
            ;;
    esac
}

get_service_status() {
    local service="$1"
    
    systemctl status "$service" --no-pager 2>/dev/null || service "$service" status
}

check_port() {
    local port="$1"
    
    ss -tln 2>/dev/null | grep -q ":$port " && echo "端口 $port: 已占用" || echo "端口 $port: 可用"
}

get_kernel_version() {
    uname -r
}

get_architecture() {
    uname -m
}

get_memory() {
    free -h | grep Mem | awk '{print $2}'
}

get_cpu_cores() {
    nproc
}

is_root() {
    [[ $EUID -eq 0 ]]
}

report() {
    echo "=== 系统信息报告 ==="
    echo "操作系统: $OS_TYPE $OS_VERSION ($OS_CODENAME)"
    echo "包管理器: $PACKAGE_MANAGER"
    echo "内核: $(get_kernel_version)"
    echo "架构: $(get_architecture)"
    echo "CPU核心: $(get_cpu_cores)"
    echo "内存: $(get_memory)"
    echo "PHP版本: $PHP_VERSION"
    echo "MySQL版本: $MYSQL_VERSION"
    echo "Node版本: $NODE_VERSION"
}

detect_os

case "${1:-report}" in
    report)
        report
        ;;
    info)
        echo "OS_TYPE=$OS_TYPE"
        echo "OS_VERSION=$OS_VERSION"
        echo "OS_CODENAME=$OS_CODENAME"
        echo "PACKAGE_MANAGER=$PACKAGE_MANAGER"
        ;;
    php)
        get_php_version
        echo "PHP $PHP_VERSION"
        ;;
    mysql)
        get_mysql_version
        echo "MySQL $MYSQL_VERSION"
        ;;
    node)
        get_node_version
        echo "Node $NODE_VERSION"
        ;;
    check-port)
        check_port "${2:-80}"
        ;;
    *)
        echo "用法: $(basename $0) <命令>"
        echo "命令: report|info|php|mysql|node|check-port <port>"
        ;;
esac