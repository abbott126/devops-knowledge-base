#!/bin/bash

# 跨平台Python生产环境部署

set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.11}"

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

install_python_ubuntu() {
    echo "=== 安装 Python $PYTHON_VERSION (Ubuntu) ==="
    
    if command -v python"$PYTHON_VERSION" >/dev/null 2>&1; then
        echo "Python已安装: $(python"$PYTHON_VERSION" --version)"
        return 0
    fi
    
    apt-get update -qq
    apt-get install -y -qq software-properties-common
    
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update -qq
    
    apt-get install -y -qq "python$PYTHON_VERSION" "python$PYTHON_VERSION"-venv "python$PYTHON_VERSION"-dev \
        "python$PYTHON_VERSION"-distutils
    
    update-alternatives --install /usr/bin/python python "python$PYTHON_VERSION" 1
    
    python"$PYTHON_VERSION" -m pip install --upgrade pip
    python"$PYTHON_VERSION" -m pip install gunicorn flask django
    
    echo "Python安装完成: $(python"$PYTHON_VERSION" --version)"
}

install_python_centos() {
    echo "=== 安装 Python $PYTHON_VERSION (CentOS) ==="
    
    if command -v python"$PYTHON_VERSION" >/dev/null 2>&1; then
        echo "Python已安装: $(python"$PYTHON_VERSION" --version)"
        return 0
    fi
    
    yum install -y -q gcc openssl-devel bzip2-devel libffi-devel zlib-devel
    
    cd /tmp
    curl -sO "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    tar -xzf "Python-$PYTHON_VERSION.tgz"
    cd "Python-$PYTHON_VERSION"
    ./configure --enable-optimizations
    make -j$(nproc)
    make altinstall
    
    python"$PYTHON_VERSION" -m pip install --upgrade pip
    python"$PYTHON_VERSION" -m pip install gunicorn flask
    
    echo "Python安装完成: $(python"$PYTHON_VERSION" --version)"
}

install_python_debian() {
    echo "=== 安装 Python $PYTHON_VERSION (Debian) ==="
    
    if command -v python"$PYTHON_VERSION" >/dev/null 2>&1; then
        echo "Python已安装: $(python"$PYTHON_VERSION" --version)"
        return 0
    fi
    
    apt-get update -qq
    apt-get install -y -qq build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev curl libncurseswget-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
    
    cd /tmp
    curl -sO "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    tar -xzf "Python-$PYTHON_VERSION.tgz"
    cd "Python-$PYTHON_VERSION"
    ./configure --enable-optimizations
    make -j$(nproc)
    make altinstall
    
    echo "Python安装完成: $(python"$PYTHON_VERSION" --version)"
}

install_python() {
    local os
    os=$(detect_os)
    
    case "$os" in
        ubuntu|linuxmint)
            install_python_ubuntu
            ;;
        centos|rhel|rocky|alma)
            install_python_centos
            ;;
        debian)
            install_python_debian
            ;;
        *)
            echo "尝试Ubuntu方式..."
            install_python_ubuntu
            ;;
    esac
}

create_venv() {
    local name="${1:-venv}"
    local py="${2:-$PYTHON_VERSION}"
    
    python"$py" -m venv "$name"
    source "$name"/bin/activate
    
    pip install --upgrade pip
    pip install gunicorn flask django
    
    echo "虚拟环境创建完成: $name"
}

deploy_app() {
    local app="${1:-app}"
    local port="${2:-8000}"
    
    cd "$app"
    
    if [[ -f requirements.txt ]]; then
        pip install -r requirements.txt
    elif [[ -f pyproject.toml ]]; then
        pip install -e .
    fi
    
    if [[ -f app.py ]]; then
        gunicorn -w 4 -b 0.0.0.0:"$port" --daemon app:app
    elif [[ -f main.py ]]; then
        gunicorn -w 4 -b 0.0.0.0:"$port" --daemon main:app
    elif [[ -f "$app.py" ]]; then
        gunicorn -w 4 -b 0.0.0.0:"$port" --daemon "$app":app
    fi
    
    echo "应用部署完成: $app (端口: $port)"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install [版本]            安装Python (默认3.11)
    venv <name> [py版本]     创建虚拟环境
    deploy <app> [port]      部署Django/Flask应用
    status                   查看Gunicorn状态

示例:
    $(basename $0) install 3.10
    $(basename $0) venv myenv
    $(basename $0) deploy myapp 8000
EOF
    exit 1
}

case "${1:-}" in
    install)
        PYTHON_VERSION="${2:-3.11}"
        install_python
        ;;
    venv)
        create_venv "${2:-venv}" "${3:-}"
        ;;
    deploy)
        deploy_app "${2:-app}" "${3:-8000}"
        ;;
    status)
        ps aux | grep gunicorn | grep -v grep
        ;;
    *)
        usage
        ;;
esac