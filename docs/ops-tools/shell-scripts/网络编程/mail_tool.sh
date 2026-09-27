#!/bin/bash

# 邮件发送工具

set -euo pipefail

SMTP_HOST="${SMTP_HOST:-localhost}"
SMTP_PORT="${SMTP_PORT:-25}"
SMTP_USER=""
SMTP_PASS=""
FROM_ADDR=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    send <to> <subject> <body>     发送邮件
    send-file <to> <subject> <file> 发送文件内容
    test                           测试SMTP连接
    config                        显示配置

示例:
    $(basename $0) send admin@example.com "主题" "内容"
    $(basename $0) config
EOF
    exit 1
}

has_sendmail() {
    command -v sendmail >/dev/null 2>&1 || command -v mail >/dev/null 2>&1
}

send_mail() {
    local to="$1"
    local subject="$2"
    local body="$3"
    
    if [[ -n "$SMTP_USER" ]]; then
        echo -e "From: $FROM_ADDR\nTo: $to\nSubject: $subject\n\n$body" | \
            sendmail -f "$FROM_ADDR" -u "$SMTP_USER" -s "$SMTP_HOST:$SMTP_PORT" "$to" 2>/dev/null || \
            echo "发送失败"
    elif command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "$subject" "$to"
    else
        echo "请配置mailx或sendmail"
    fi
    
    echo "邮件已发送: $to"
}

send_file() {
    local to="$1"
    local subject="$2"
    local file="$3"
    
    send_mail "$to" "$subject" "$(cat "$file")"
}

test_smtp() {
    echo "=== SMTP测试 ==="
    echo "主机: $SMTP_HOST:$SMTP_PORT"
    echo "用户: $SMTP_USER"
    
    if command -v nc >/dev/null 2>&1; then
        echo "$SMTP_HOST" | nc -w 5 "$SMTP_HOST" "$SMTP_PORT" 2>/dev/null && \
            echo "连接成功" || echo "连接失败"
    fi
}

show_config() {
    echo "=== 邮件配置 ==="
    echo "SMTP服务器: $SMTP_HOST:$SMTP_PORT"
    echo "发件人: $FROM_ADDR"
    echo "用户: $SMTP_USER"
}

case "${1:-}" in
    send)
        send_mail "$2" "$3" "$4"
        ;;
    send-file)
        send_file "$2" "$3" "$4"
        ;;
    test)
        test_smtp
        ;;
    config)
        show_config
        ;;
    *)
        usage
        ;;
esac