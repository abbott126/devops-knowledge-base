#!/bin/bash

# Docker镜像管理和加速器配置

set -euo pipefail

REGISTRY="${REGISTRY:-docker.io}"
MIRROR="${MIRROR:-mirror.gcr.io}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    mirror                    配置镜像加速器
    pull <image>            拉取镜像
    push <image>            推送镜像
    prune                     清理镜像
    list                     列出镜像

示例:
    $(basename $0) mirror
    $(basename $0) pull nginx:latest
EOF
    exit 1
}

config_mirror() {
    echo "=== 配置镜像加速器 ==="
    
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": [
        "https://$MIRROR",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ],
    "insecure-registries": [],
    "experimental": false,
    "debug": false
}
EOF
    
    systemctl daemon-reload
    systemctl restart docker
    
    echo "镜像加速器配置完成"
}

pull_image() {
    local image="$1"
    
    docker pull "$image"
    echo "镜像拉取完成: $image"
}

push_image() {
    local image="$1"
    local tag="${2:-}"
    
    if [[ -n "$tag" ]]; then
        docker tag "$image" "$tag"
        image="$tag"
    fi
    
    docker push "$image"
    echo "镜像推送完成: $image"
}

prune_images() {
    echo "=== 清理未使用镜像 ==="
    
    local before
    before=$(docker images -q | wc -l)
    
    docker image prune -a -f
    
    local after
    after=$(docker images -q | wc -l)
    
    echo "清理前: $before | 清理后: $after"
}

list_images() {
    echo "=== Docker镜像列表 ==="
    docker images | head -20
}

case "${1:-}" in
    mirror)
        config_mirror
        ;;
    pull)
        pull_image "$2"
        ;;
    push)
        push_image "$2" "${3:-}"
        ;;
    prune)
        prune_images
        ;;
    list)
        list_images
        ;;
    *)
        usage
        ;;
esac