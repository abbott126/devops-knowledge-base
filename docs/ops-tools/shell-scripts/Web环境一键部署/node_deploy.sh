#!/bin/bash

# Node.js生产环境一键部署

set -euo pipefail

NODE_VERSION="${NODE_VERSION:-20}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    部署Node.js
    pm2 <app>               配置PM2
    deploy <app>            部署应用
    status                  查看状态

示例:
    $(basename $0) install
    $(basename $0) install 18
EOF
    exit 1
}

install_node() {
    echo "=== 部署 Node.js ${NODE_VERSION} ==="
    
    if command -v node >/dev/null 2>&1; then
        echo "Node.js已安装: $(node -v)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl
        curl -fsSL https://deb.nodesource.com/setup_"$NODE_VERSION".x | bash -
        apt-get install -y nodejs
    elif command -v yum >/dev/null 2>&1; then
        curl -fsSL https://rpm.nodesource.com/setup_"$NODE_VERSION".x | bash -
        yum install -y nodejs
    fi
    
    npm install -g pm2 yarn
    
    echo "Node.js安装完成: $(node -v)"
}

config_pm2() {
    local app="$1"
    
    if [[ -f package.json ]]; then
        pm2 start npm --name "$app" -- start
    elif [[ -f index.js ]]; then
        pm2 start index.js --name "$app"
    elif [[ -f server.js ]]; then
        pm2 start server.js --name "$app"
    fi
    
    pm2 save
    pm2 startup 2>/dev/null | tail -1 | bash -
    
    echo "PM2配置完成: $app"
}

deploy_app() {
    local app="$1"
    local repo="${2:-.}"
    
    cd "$repo"
    
    npm install --production
    
    pm2 stop "$app" 2>/dev/null || true
    pm2 delete "$app" 2>/dev/null || true
    
    config_pm2 "$app"
    
    pm2 logs --lines 20 --nostream
}

show_status() {
    echo "=== PM2状态 ==="
    pm2 list
    
    echo ""
    echo "=== 资源使用 ==="
    pm2 monit 2>/dev/null | head -20 || pm2 status
}

case "${1:-}" in
    install)
        install_node
        ;;
    pm2)
        config_pm2 "${2:-app}"
        ;;
    deploy)
        deploy_app "${2:-app}" "${3:-.}"
        ;;
    status)
        show_status
        ;;
    *)
        usage
        ;;
esac