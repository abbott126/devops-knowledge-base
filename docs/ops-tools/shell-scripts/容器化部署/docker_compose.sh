#!/bin/bash

# Docker Compose多服务集群部署

set -euo pipefail

COMPOSE_VERSION="${COMPOSE_VERSION:-2.20}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装Docker
    init <project>            初始化项目
    up                      启动服务
    down                     停止服务
    scale <service> <n>      扩缩容
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) init myapp
    $(basename $0) scale web 3
EOF
    exit 1
}

install_docker() {
    echo "=== 安装 Docker ${COMPOSE_VERSION} ==="
    
    if command -v docker >/dev/null 2>&1; then
        echo "Docker已安装: $(docker --version)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif command -v yum >/dev/null 2>&1; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    systemctl enable docker
    systemctl start docker
    
    echo "Docker安装完成"
}

init_project() {
    local name="$1"
    local template="${2:-lnmp}"
    
    mkdir -p "$name"
    cd "$name"
    
    cat > docker-compose.yml << EOF
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
    depends_on:
      - php
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

  redis:
    image: redis:7-alpine
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
    
    echo "项目初始化完成: $name"
    echo "启动命令: cd $name && docker compose up -d"
}

start_services() {
    docker compose up -d
    echo "服务启动完成"
}

stop_services() {
    docker compose down
    echo "服务已停止"
}

scale_service() {
    local service="$1"
    local replicas="$2"
    
    docker compose up -d --scale "${service}=${replicas}"
    echo "${service} 扩展到 ${replicas} 副本"
}

show_status() {
    echo "=== 服务状态 ==="
    docker compose ps
    
    echo ""
    echo "=== 资源使用 ==="
    docker stats --no-stream 2>/dev/null | head -15 || echo "无资源数据"
}

case "${1:-}" in
    install)
        install_docker
        ;;
    init)
        init_project "${2:-myapp}" "${3:-}"
        ;;
    up)
        start_services
        ;;
    down)
        stop_services
        ;;
    scale)
        scale_service "$2" "$3"
        ;;
    status)
        show_status
        ;;
    *)
        usage
        ;;
esac