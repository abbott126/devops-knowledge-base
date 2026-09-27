#!/bin/bash

# SSH远程执行工具

set -euo pipefail

SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    exec <host> <cmd>        执行命令
    copy <host> <src> <dst>  复制文件
    sync <host> <src> <dir>  同步目录
    tunnel <host> <port>     建立隧道
    batch <hosts> <cmd>      批量执行

示例:
    $(basename $0) exec 192.168.1.100 "df -h"
    $(basename $0) copy 192.168.1.100 /tmp/file /root/
EOF
    exit 1
}

ssh_exec() {
    local host="$1"
    local cmd="$2"
    
    ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" ${SSH_KEY:+-i "$SSH_KEY"} "$SSH_USER@$host" "$cmd"
}

scp_copy() {
    local host="$1"
    local src="$2"
    local dst="$3"
    
    scp -o StrictHostKeyChecking=no -P "$SSH_PORT" ${SSH_KEY:+-i "$SSH_KEY"} "$src" "$SSH_USER@$host:$dst"
}

rsync_sync() {
    local host="$1"
    local src="$2"
    local dst="$3"
    
    rsync -avz -e "ssh -p $SSH_PORT ${SSH_KEY:+-i $SSH_KEY}" "$src" "$SSH_USER@$host:$dst"
}

ssh_tunnel() {
    local host="$1"
    local local_port="$2"
    local remote_port="$3"
    local remote_host="${4:-localhost}"
    
    ssh -o StrictHostKeyChecking=no -N -L "$local_port":"$remote_host":"$remote_port" \
        -p "$SSH_PORT" ${SSH_KEY:+-i "$SSH_KEY"} "$SSH_USER@$host" &
    echo "隧道已建立: localhost:$local_port -> $host:$remote_port"
}

batch_exec() {
    local hosts_file="$1"
    local cmd="$2"
    
    while read -r host; do
        echo "=== $host ==="
        ssh_exec "$host" "$cmd" &
    done < "$hosts_file"
    wait
}

case "${1:-}" in
    exec)
        ssh_exec "$2" "$3"
        ;;
    copy)
        scp_copy "$2" "$3" "$4"
        ;;
    sync)
        rsync_sync "$2" "$3" "$4"
        ;;
    tunnel)
        ssh_tunnel "$2" "$3" "${4:-}"
        ;;
    batch)
        batch_exec "$2" "$3"
        ;;
    *)
        usage
        ;;
esac