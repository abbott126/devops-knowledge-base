#!/bin/bash

# 跨平台Node.js生产环境部署

set -euo pipefail

NODE_VERSION="${NODE_VERSION:-20}"

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

install_node_ubuntu() {
    echo "=== 安装 Node.js $NODE_VERSION (Ubuntu) ==="
    
    if command -v node >/dev/null 2>&1; then
        echo "Node.js已安装: $(node -v)"
        return 0
    fi
    
    apt-get update -qq
    apt-get install -y -qq curl
    
    curl -fsSL "https://deb.nodesource.com/setup_$NODE_VERSION.x" | bash -
    apt-get install -y -qq nodejs
    
    npm install -g pm2 yarn
    
    echo "Node.js安装完成: $(node -v)"
}

install_node_centos() {
    echo "=== 安装 Node.js $NODE_VERSION (CentOS) ==="
    
    if command -v node >/dev/null 2>&1; then
        echo "Node.js已安装: $(node -v)"
        return 0
    fi
    
    yum install -y -q curl
    
    curl -fsSL "https://rpm.nodesource.com/setup_$NODE_VERSION.x" | bash -
    yum install -y -q nodejs
    
    npm install -g pm2 yarn
    
    echo "Node.js安装完成: $(node -v)"
}

install_node_debian() {
    echo "=== 安装 Node.js $NODE_VERSION (Debian) ==="
    
    if command -v node >/dev/null 2>&1; then
        echo "Node.js已安装: $(node -v)"
        return 0
    fi
    
    apt-get update -qq
    apt-get install -y -qq curl gnupg
    
    curl -fsSL "https://deb.nodesource.com/setup_$NODE_VERSION.x" | bash -
    apt-get install -y -q nodejs
    
    npm install -g pm2 yarn
    
    echo "Node.js安装完成: $(node -v)"
}

install_node() {
    local os
    os=$(detect_os)
    
    case "$os" in
        ubuntu)
            install_node_ubuntu
            ;;
        centos|rhel|rocky|alma)
            install_node_centos
            ;;
        debian)
            install_node_debian
            ;;
        *)
            echo "尝试Ubuntu方式..."
            install_node_ubuntu
            ;;
    esac
}

deploy_app() {
    local app="${1:-app}"
    local port="${2:-3000}"
    
    npm install --production
    
    if [[ -f package.json ]]; then
        pm2 delete "$app" 2>/dev/null || true
        
        if [[ -f index.js ]]; then
            pm2 start index.js --name "$app" -- "$port"
        elif [[ -f server.js ]]; then
            pm2 start server.js --name "$app" -- "$port"
        elif [[ -f app.js ]]; then
            pm2 start app.js --name "$app" -- "$port"
        else
            pm2 start npm --name "$app" -- start
        fi
        
        pm2 save
        pm2 startup 2>/dev/null | tail -1 | bash - 2>/dev/null || true
    fi
    
    echo "应用部署完成: $app (端口: $port)"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install [版本]           安装Node.js (默认20)
    deploy <app> [port]      部署应用
    status                   查看状态
    logs                     查看日志

示例:
    $(basename $0) install 18
    $(basename $0) deploy myapp 3000
EOF
    exit 1
}

case "${1:-}" in
    install)
        NODE_VERSION="${2:-20}"
        install_node
        ;;
    deploy)
        deploy_app "${2:-app}" "${3:-3000}"
        ;;
    status)
        pm2 list
        ;;
    logs)
        pm2 logs --lines 50 --nostream
        ;;
    *)
        usage
        ;;
esac