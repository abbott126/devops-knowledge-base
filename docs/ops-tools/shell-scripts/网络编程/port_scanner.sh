#!/bin/bash

# 网络端口扫描工具

set -euo pipefail

TIMEOUT=2

usage() {
    cat << EOF
用法: $(basename $0) [选项] <目标>

选项:
    -h, --host <ip>        目标IP
    -p, --port <port>       端口或范围
    -t, --timeout <sec>    超时时间
    -c, --common          常用端口
    -a, --all            1-1024端口
    -v, --verbose        详细输出

示例:
    $(basename $0) -h 192.168.1.1 -p 80
    $(basename $0) -h 192.168.1.1 -p 1-1000 -c
EOF
    exit 1
}

scan_port() {
    local host="$1"
    local port="$2"
    
    (echo > /dev/tcp/"$host"/"$port") >/dev/null 2>&1 && echo "$port open" || echo "$port closed"
}

scan_ports() {
    local host="$1"
    local ports="$2"
    
    for port in $(eval echo {$ports}); do
        scan_port "$host" "$port" &
    done
    wait
}

common_ports() {
    local host="$1"
    local ports="21 22 23 25 53 80 110 143 443 465 587 993 995 3306 3389 5432 6379 8080 8443"
    
    for port in $ports; do
        scan_port "$host" "$port" &
    done
    wait
}

scan_range() {
    local host="$1"
    local start="$2"
    local end="$3"
    
    for ((port=start; port<=end; port++)); do
        scan_port "$host" "$port" &
    done
    wait
}

case "${1:-}" in
    scan)
        scan_port "$2" "$3"
        ;;
    ports)
        scan_ports "$2" "$3"
        ;;
    common)
        common_ports "$2"
        ;;
    range)
        scan_range "$2" "$3" "$4"
        ;;
    *)
        scan_port "${HOST:-localhost}" "${PORT:-80}"
        ;;
esac