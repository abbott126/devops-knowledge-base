#!/bin/bash

# Docker容器管理工具箱

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    ls                          列出容器
    start <name/id>              启动容器
    stop <name/id>               停止容器
    restart <name/id>            重启容器
    remove <name/id>              删除容器
    logs <name/id>                 查看日志
    stats <name/id>               查看资源使用
    exec <name/id> <cmd>          在容器执行命令
    clean                       清理停止的容器
    prune                       清理未使用的镜像
    backup <name> <path>        备份容器
    restore <name> <path>       恢复容器

示例:
    $(basename $0) ls
    $(basename $0) restart myapp
    $(basename $0) clean
EOF
    exit 1
}

cmd_exists() {
    command -v docker >/dev/null 2>&1
}

if ! cmd_exists; then
    echo "Docker未安装"
    exit 1
fi

list_containers() {
    echo "=== 容器列表 ==="
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
}

start_container() {
    local name="$1"
    docker start "$name"
    echo "已启动: $name"
}

stop_container() {
    local name="$1"
    docker stop "$name"
    echo "已停止: $name"
}

restart_container() {
    local name="$1"
    docker restart "$name"
    echo "已重启: $name"
}

remove_container() {
    local name="$1"
    docker rm -f "$name"
    echo "已删除: $name"
}

show_logs() {
    local name="$1"
    local lines="${2:-100}"
    docker logs --tail "$lines" -f "$name"
}

show_stats() {
    local name="$1"
    docker stats "$name" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

exec_cmd() {
    local name="$1"
    shift
    docker exec -it "$name" "$@"
}

clean_containers() {
    local count
    count=$(docker ps -aq -f status=exited | wc -l)
    [[ "$count" -gt 0 ]] && docker rm -f $(docker ps -aq -f status=exited)
    echo "已清理 $count 个停止的容器"
}

prune_images() {
    local size
    size=$(docker images -f dangling=true -q | wc -l)
    [[ "$size" -gt 0 ]] && docker rmi $(docker images -f dangling=true -q)
    echo "已清理 $size 个未使用的镜像"
}

backup_container() {
    local name="$1"
    local path="$2"
    
    docker commit "$name" "${name}:backup"
    docker save "${name}:backup" -o "${path}/${name}.tar"
    gzip "${path}/${name}.tar"
    
    echo "备份完成: ${path}/${name}.tar.gz"
}

restore_container() {
    local name="$1"
    local path="$2"
    
    gunzip -c "${path}/${name}.tar.gz" | docker load
    docker run -d --name "$name" "${name}:backup"
    
    echo "恢复完成: $name"
}

case "${1:-}" in
    ls)
        list_containers
        ;;
    start)
        start_container "$2"
        ;;
    stop)
        stop_container "$2"
        ;;
    restart)
        restart_container "$2"
        ;;
    remove)
        remove_container "$2"
        ;;
    logs)
        show_logs "${2:-}" "${3:-100}"
        ;;
    stats)
        show_stats "$2"
        ;;
    exec)
        shift
        exec_cmd "$@"
        ;;
    clean)
        clean_containers
        ;;
    prune)
        prune_images
        ;;
    backup)
        backup_container "$2" "$3"
        ;;
    restore)
        restore_container "$2" "$3"
        ;;
    *)
        usage
        ;;
esac