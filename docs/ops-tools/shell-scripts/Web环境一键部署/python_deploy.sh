#!/bin/bash

# Python生产环境一键部署

set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.11}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    部署Python
    venv <name>              创建虚拟环境
    deploy <app>            部署应用
    gunicorn <app>           配置Gunicorn

示例:
    $(basename $0) install
    $(basename $0) install 3.10
EOF
    exit 1
}

install_python() {
    echo "=== 部署 Python ${PYTHON_VERSION} ==="
    
    if command -v python"$PYTHON_VERSION" >/dev/null 2>&1; then
        echo "Python已安装: $(python"$PYTHON_VERSION" --version)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y software-properties-common
        add-apt-repository -y ppa:deadsnakes/ppa
        apt-get update
        apt-get install -y python"$PYTHON_VERSION" python"$PYTHON_VERSION"-venv python"$PYTHON_VERSION"-dev
        update-alternatives --install /usr/bin/python python "$PYTHON_VERSION" 1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y python"$PYTHON_VERSION"
    fi
    
    python"$PYTHON_VERSION" -m pip install --upgrade pip
    python"$PYTHON_VERSION" -m pip install gunicorn flask django
    
    echo "Python安装完成: $(python"$PYTHON_VERSION" --version)"
}

create_venv() {
    local name="$1"
    
    python -m venv "$name"
    source "$name"/bin/activate
    
    pip install --upgrade pip
    pip install gunicorn
    
    echo "虚拟环境创建完成: $name"
}

deploy_app() {
    local app="$1"
    local port="${2:-8000}"
    
    cd "$app"
    
    if [[ -f requirements.txt ]]; then
        pip install -r requirements.txt
    elif [[ -f pyproject.toml ]]; then
        pip install -e .
    fi
    
    if [[ -f app.py ]]; then
        gunicorn -w 4 -b 0.0.0.0:"$port" --daemon app:app
    elif [[ -f manage.py ]]; then
        gunicorn -w 4 -b 0.0.0.0:"$port" --daemon "${app}.wsgi:application"
    fi
    
    echo "应用部署完成: $app (端口: $port)"
}

config_gunicorn() {
    local app="$1"
    local workers="${2:-4}"
    local port="${3:-8000}"
    
    cat > gunicorn.conf.py << EOF
bind = "0.0.0.0:$port"
workers = $workers
worker_class = "sync"
timeout = 120
accesslog = "-"
errorlog = "-"
daemon = True
EOF
    
    gunicorn -c gunicorn.conf.py "${app}.wsgi:application"
    echo "Gunicorn配置完成"
}

case "${1:-}" in
    install)
        install_python
        ;;
    venv)
        create_venv "${2:-venv}"
        ;;
    deploy)
        deploy_app "${2:-app}" "${3:-8000}"
        ;;
    gunicorn)
        config_gunicorn "${2:-app}" "${3:-4}" "${4:-8000}"
        ;;
    *)
        usage
        ;;
esac