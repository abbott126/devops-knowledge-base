#!/bin/bash

# GitLab CI runner自动部署

set -euo pipefail

GITLAB_VERSION="${GITLAB_VERSION:-16.5}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装GitLab Runner
    register                  注册Runner
    unregister                注销Runner
    status                   查看状态
    run                      运行构建

示例:
    $(basename $0) install
    $(basename $0) register
EOF
    exit 1
}

install_runner() {
    echo "=== 安装 GitLab Runner ==="
    
    if command -v gitlab-runner >/dev/null 2>&1; then
        echo "GitLab Runner已安装: $(gitlab-runner --version)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/gpgkey | tee /etc/apt/trusted.gpg.d/gitlab-runner.asc
        echo "deb https://packages.gitlab.com/install/repositories/runner/gitlab-runner/debian_$(lsb_release -cs) binary/" | \
            tee /etc/apt/sources.list.d/gitlab-runner.list
        apt-get update
        apt-get install -y gitlab-runner
    elif command -v yum >/dev/null 2>&1; then
        curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/gpgkey | tee /etc/pki/rpm-gpg/RPM-GPG-KEY-gitlab-runner
        curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner.repo -o /etc/yum.repos.d/gitlab-runner.repo
        yum install -y gitlab-runner
    fi
    
    gitlab-runner --version
}

register_runner() {
    local gitlab_url="${1:-http://localhost}"
    local token="${2:-}"
    local executor="${3:-docker}"
    local image="${4:-alpine:latest}"
    
    if [[ -z "$token" ]]; then
        echo "请提供注册token"
        echo "使用: $(basename $0) register <gitlab-url> <token>"
        return 1
    fi
    
    gitlab-runner register \
        --non-interactive \
        --url "$gitlab_url" \
        --registration-token "$token" \
        --executor "$executor" \
        --docker-image "$image" \
        --description "runner-$(hostname)" \
        --tag-list "docker,linux" \
        --locked="false" \
        --run-untagged="true"
    
    gitlab-runner start
    
    echo "Runner注册完成"
}

unregister_runner() {
    local executor="${1:-}"
    
    gitlab-runner unregister --name "$executor" 2>/dev/null || \
        gitlab-runner unregister --all-runners 2>/dev/null || \
        echo "无Runner可注销"
}

show_status() {
    echo "=== GitLab Runner状态 ==="
    gitlab-runner verify --delete 2>/dev/null || true
    gitlab-runner list
}

start_build() {
    echo "=== 开始构建 ==="
    gitlab-runner run-single --single-run --url "$1" --token "$2" 2>/dev/null || \
        echo "请配置GitLab CI配置文件"
}

case "${1:-}" in
    install)
        install_runner
        ;;
    register)
        register_runner "${2:-http://gitlab.example.com}" "${3:-}" "${4:-}" "${5:-}"
        ;;
    unregister)
        unregister_runner "${2:-}"
        ;;
    status)
        show_status
        ;;
    run)
        start_build "$2" "$3"
        ;;
    *)
        usage
        ;;
esac