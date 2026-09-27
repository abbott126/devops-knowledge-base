#!/bin/bash

# 跨平台Docker Compose集群部署

set -euo pipefail

DOCKER_VERSION="${DOCKER_VERSION:-24}"

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

install_docker_ubuntu() {
    echo "=== 安装 Docker (Ubuntu) ==="
    
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/"$OS_TYPE"/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_TYPE $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
}

install_docker_centos() {
    echo "=== 安装 Docker (CentOS) ==="
    
    yum install -y -q yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
}

install_docker_debian() {
    echo "=== 安装 Docker (Debian) ==="
    
    apt-get update -qq
    apt-get install -y -q apt-transport-https ca-certificates curl gnupg2
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(cat /etc/debian_version) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -q docker-cedocker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker() {
    local os
    os=$(detect_os)
    
    case "$os" in
        ubuntu)
            install_docker_ubuntu
            ;;
        centos|rhel|rocky|alma)
            install_docker_centos
            ;;
        debian)
            install_docker_debian
            ;;
        *)
            echo "未知系统,使用默认安装..."
            install_docker_ubuntu
            ;;
    esac
}

init_compose_project() {
    local name="$1"
    
    mkdir -p "$name"
    cd "$name"
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - www:/var/www/html
    networks:
      - app-network

  php:
    image: php:8.2-fpm
    volumes:
      - www:/var/www/html
    networks:
      - app-network

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root123
      MYSQL_DATABASE: app
    volumes:
      - mysql:/var/lib/mysql
    networks:
      - app-network

volumes:
  www:
  mysql:

networks:
  app-network:
    driver: bridge
EOF

    cat > .env << EOF
COMPOSE_PROJECT=$name
NGINX_PORT=80
MYSQL_ROOT_PASSWORD=root123
EOF
    
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name _;
        
        root /var/www/html;
        index index.php index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        location ~ \.php$ {
            fastcgi_pass php:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF
    
    echo "项目初始化完成: $name"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装Docker (自动检测系统)
    init <name>              初始化项目
    up                      启动服务
    down                    停止服务
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) init myapp
EOF
    exit 1
}

case "${1:-}" in
    install)
        install_docker
        ;;
    init)
        init_compose_project "${2:-myapp}"
        ;;
    up)
        docker compose up -d
        ;;
    down)
        docker compose down
        ;;
    status)
        docker compose ps
        ;;
    *)
        usage
        ;;
esac