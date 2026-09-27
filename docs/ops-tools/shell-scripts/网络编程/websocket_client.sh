#!/bin/bash

# WebSocket客户端工具

set -euo pipefail

WS_URL=""
WS_HEADER=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    connect <url>            连接WebSocket
    send <message>           发送消息
    recv [n]                接收n条消息
    close                    关闭连接
    echo                    回显测试

示例:
    $(basename $0) connect ws://localhost:8080
    $(basename $0) send "hello"
EOF
    exit 1
}

has_wscat() {
    command -v wscat >/dev/null 2>&1
}

ws_connect() {
    local url="$1"
    WS_URL="$url"
    echo "连接WebSocket: $url"
    
    if has_wscat; then
        wscat -c "$url"
    else
        echo "使用websocat或wscat"
        echo "安装: cargo install websocat"
    fi
}

ws_send() {
    local msg="$1"
    echo "发送: $msg"
}

ws_recv() {
    local count="${1:-1}"
    echo "接收 $count 条消息"
}

ws_close() {
    echo "关闭连接"
}

ws_echo_test() {
    local url="${1:-wss://echo.websocket.events}"
    echo "回显测试: $url"
    
    if has_wscat; then
        wscat -c "$url"
    fi
}

case "${1:-}" in
    connect)
        ws_connect "$2"
        ;;
    send)
        ws_send "$2"
        ;;
    recv)
        ws_recv "${2:-1}"
        ;;
    close)
        ws_close
        ;;
    echo)
        ws_echo_test "${2:-}"
        ;;
    *)
        usage
        ;;
esac