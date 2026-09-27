#!/bin/bash

# 跨平台软件包安装适配库

set -euo pipefail

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/SuSE-release ]]; then
        echo "suse"
    else
        echo "unknown"
    fi
}

detect_os_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$VERSION_ID"
    fi
}

detect_pkg_manager() {
    local os
    os=$(detect_os)
    
    case "$os" in
        ubuntu|debian|linuxmint|pop)
            echo "apt"
            ;;
        fedora|rhel|centos|rocky|alma|ol)
            echo "yum"
            ;;
        arch)
            echo "pacman"
            ;;
        alpine)
            echo "apk"
            ;;
        opensuse|sles)
            echo "zypper"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

install_nginx_debian() {
    local version="${1:-}"
    apt-get update -qq
    apt-get install -y -qq nginx
}

install_nginx_rhel() {
    local version="${1:-}"
    cat > /etc/yum.repos.d/nginx.repo << 'EOF'
[nginx-stable]
name=Nginx Stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
EOF
    yum install -y -q nginx
}

install_nginx() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_nginx_debian "$@"
            ;;
        yum)
            install_nginx_rhel "$@"
            ;;
        apk)
            apk add --no-cache nginx
            ;;
        pacman)
            pacman -Sy --noconfirm nginx
            ;;
    esac
}

install_php_debian() {
    local version="${1:-8.2}"
    apt-get update -qq
    
    if [[ "$version" == "7"* ]]; then
        apt-get install -y -qq php"$version" php"$version"-fpm php"$version"-mysql \
            php"$version"-curl php"$version"-mbstring php"$version"-gd php"$version"-xml php"$version"-zip
    else
        apt-get install -y -qq php php-fpm php-mysql php-curl php-mbstring php-gd php-xml php-zip
    fi
}

install_php_rhel() {
    local version="${1:-8.2}"
    
    if (( version >= 8 )); then
        yum install -y -q php php-fpm php-mysqlnd php-curl php-mbstring php-gd php-xml php-zip
    else
        yum install -y -q php php-fpm php-mysql php-curl php-mbstring php-gd php-xml php-zip
        yum install -y -q https://rpms.remirepo.net/enterprise/remi-release-"${version%%.*}".rpm
        yum-config-manager --enable remi-php"$version"
    fi
}

install_php() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_php_debian "$@"
            ;;
        yum)
            install_php_rhel "$@"
            ;;
        apk)
            apk add --no-cache php php-fpm
            ;;
        pacman)
            pacman -Sy --noconfirm php
            ;;
    esac
}

install_mysql_debian() {
    local version="${1:-8.0}"
    apt-get update -qq
    apt-get install -y -qq mysql-server
}

install_mysql_rhel() {
    local version="${1:-8.0}"
    
    yum install -y -q https://dev.mysql.com/get/mysql80-community-release-el"$VERSION_ID"-1.noarch.rpm
    yum install -y -q mysql-community-server
}

install_mysql() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_mysql_debian "$@"
            ;;
        yum)
            install_mysql_rhel "$@"
            ;;
        apk)
            apk add --no-cache mysql mysql-client
            ;;
    esac
}

install_node_debian() {
    local version="${1:-20}"
    apt-get update -qq
    apt-get install -y -qq curl
    curl -fsSL "https://deb.nodesource.com/setup_$version.x" | bash -
    apt-get install -y -qq nodejs
}

install_node_rhel() {
    local version="${1:-20}"
    curl -fsSL "https://rpm.nodesource.com/setup_$version.x" | bash -
    yum install -y -q nodejs
}

install_node() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_node_debian "$@"
            ;;
        yum)
            install_node_rhel "$@"
            ;;
        apk)
            apk add --no-cache nodejs npm
            ;;
    esac
}

install_java_debian() {
    local version="${1:-17}"
    apt-get update -qq
    apt-get install -y -qq openjdk-"$version"-jdk
}

install_java_rhel() {
    local version="${1:-17}"
    yum install -y -q java-"$version"-openjdk
}

install_java() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_java_debian "$@"
            ;;
        yum)
            install_java_rhel "$@"
            ;;
        apk)
            apk add --no-cache openjdk"$((version/10))" 
            ;;
    esac
}

install_docker_debian() {
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_rhel() {
    yum install -y -q yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_docker_debian "$@"
            ;;
        yum)
            install_docker_rhel "$@"
            ;;
    esac
}

install_python_debian() {
    local version="${1:-3.11}"
    apt-get update -qq
    apt-get install -y -qq "python$version" "python$version"-venv "python$version"-dev
    update-alternatives --install /usr/bin/python python "$version" 1
}

install_python_rhel() {
    local version="${1:-3.11}"
    yum install -y -q python"$version"
}

install_python() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)
    
    case "$pkg_manager" in
        apt)
            install_python_debian "$@"
            ;;
        yum)
            install_python_rhel "$@"
            ;;
        apk)
            apk add --no-cache python3 py3-pip
            ;;
    esac
}

case "${1:-info}" in
    os)
        detect_os
        ;;
    os-version)
        detect_os_version
        ;;
    pkg-manager)
        detect_pkg_manager
        ;;
    nginx)
        install_nginx "$@"
        ;;
    php)
        install_php "$@"
        ;;
    mysql)
        install_mysql "$@"
        ;;
    node)
        install_node "$@"
        ;;
    java)
        install_java "$@"
        ;;
    docker)
        install_docker "$@"
        ;;
    python)
        install_python "$@"
        ;;
    *)
        echo "用法: $(basename $0) <软件> [版本]"
        echo "软件: nginx|php|mysql|node|java|docker|python"
        ;;
esac