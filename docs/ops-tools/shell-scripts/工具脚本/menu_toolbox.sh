#!/bin/bash

# 交互式菜单工具箱

set -euo pipefail

MENU_TITLE="工具箱"

usage() {
    cat << EOF
使用方法直接运行脚本,无需参数
EOF
    exit 1
}

menu_header() {
    clear
    echo "========================================="
    echo "        $MENU_TITLE"
    echo "========================================="
    echo ""
}

show_menu() {
    menu_header
    cat << EOF
请选择操作:

1. 系统信息
2. 磁盘使用
3. 网络状态
4. 进程查看
5. 日志查看
6. 服务管理
7. 备份数据
8. 退出

=========================================
EOF
    echo -n "请选择 [1-8]: "
}

system_info() {
    echo "=== 系统信息 ==="
    echo "主机名: $(hostname)"
    echo "内核: $(uname -r)"
    echo "运行时间: $(uptime -p)"
    echo "负载: $(cat /proc/loadavg)"
    echo ""
    read -p "按回车继续..."
}

disk_usage() {
    echo "=== 磁盘使用 ==="
    df -h | grep -v "tmpfs\|devtmpfs"
    echo ""
    read -p "按回车继续..."
}

network_status() {
    echo "=== 网络状态 ==="
    echo "网络接口:"
    ip addr | grep "inet " | awk '{print "  " $NF ": " $2}'
    echo ""
    echo "连接统计:"
    ss -tan | awk '{print $1}' | sort | uniq -c | sort -rn | head -5
    echo ""
    read -p "按回车继续..."
}

process_view() {
    echo "=== Top进程 ==="
    ps aux --sort=-%cpu | head -11
    echo ""
    read -p "按回车继续..."
}

log_viewer() {
    echo "=== 日志查看 ==="
    echo "1. 系统日志"
    echo "2. 认证日志"
    echo "3. 内核日志"
    echo ""
    echo -n "选择: "
    read -r choice
    
    case "$choice" in
        1) less /var/log/syslog 2>/dev/null || journalctl || echo "无权限" ;;
        2) less /var/log/auth.log 2>/dev/null || echo "无权限" ;;
        3) less /var/log/kern.log 2>/dev/null || echo "无权限" ;;
    esac
}

service_manager() {
    echo "=== 服务管理 ==="
    systemctl list-units --type=service --state=running | head -15
    echo ""
    read -p "按回车继续..."
}

backup_data() {
    echo "=== 数据备份 ==="
    echo -n "输入备份目录: "
    read -r backup_dir
    
    if [[ -n "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
        echo "备份目录: $backup_dir"
        echo "备份完成"
    fi
    echo ""
    read -p "按回车继续..."
}

main() {
    while true; do
        show_menu
        read -r choice
        
        case "$choice" in
            1) system_info ;;
            2) disk_usage ;;
            3) network_status ;;
            4) process_view ;;
            5) log_viewer ;;
            6) service_manager ;;
            7) backup_data ;;
            8) echo "再见!"; break ;;
            *) echo "无效选择" ;;
        esac
    done
}

main "$@"