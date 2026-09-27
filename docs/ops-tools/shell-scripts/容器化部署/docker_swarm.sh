#!/bin/bash

# Docker Swarm集群一键部署

set -euo pipefail

MANAGER_IP="${MANAGER_IP:-}"
WORKER_HOSTS=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    init                       初始化Swarm
    join-worker <token>        加入工作节点
    join-manager <token>    加入管理节点
    deploy <yml>             部署服务
    status                   查看状态
    scale <service> <n>      扩缩容

示例:
    $(basename $0) init 192.168.1.10
    $(basename $0) deploy docker-compose.yml
EOF
    exit 1
}

init_swarm() {
    local advertise="$1"
    
    echo "=== 初始化 Docker Swarm ==="
    
    docker swarm init --advertise-addr "$advertise" 2>/dev/null || \
        docker swarm init
    
    echo ""
    echo "Swarm已初始化"
    echo "管理节点: $(docker info 2>/dev/null | grep "Swarm" | head -2)"
    
    local join_token
    join_token=$(docker swarm join-token -q worker)
    echo ""
    echo "工作节点加入命令:"
    echo "  docker swarm join --token $join_token <manager-ip>:2377"
}

join_worker() {
    local token="$1"
    local manager="$2"
    
    docker swarm join --token "$token" "$manager:2377"
    echo "已加入Swarm作为工作节点"
}

join_manager() {
    local token="$1"
    local manager="$2"
    
    docker swarm join --token "$token" "$manager:2377"
    echo "已加入Swarm作为管理节点"
}

deploy_service() {
    local compose_file="$1"
    
    docker stack deploy -c "$compose_file" myapp
    echo "服务部署完成: myapp"
}

show_status() {
    echo "=== Swarm状态 ==="
    docker node ls
    
    echo ""
    echo "=== 服务列表 ==="
    docker service ls
    
    echo ""
    echo "=== 任务状态 ==="
    docker service ps myapp 2>/dev/null | head -10 || echo "无服务"
}

scale_service() {
    local service="$1"
    local replicas="$2"
    
    docker service scale "${service}=${replicas}"
    echo "${service} 扩展到 ${replicas} 副本"
}

case "${1:-}" in
    init)
        init_swarm "${2:-192.168.1.10}"
        ;;
    join-worker)
        echo "token: $2"
        echo "manager: $3"
        join_worker "$2" "$3"
        ;;
    join-manager)
        join_manager "$2" "$3"
        ;;
    deploy)
        deploy_service "${2:-docker-compose.yml}"
        ;;
    status)
        show_status
        ;;
    scale)
        scale_service "$2" "$3"
        ;;
    *)
        usage
        ;;
esac