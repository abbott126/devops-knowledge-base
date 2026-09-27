#!/bin/bash

# 系统初始化配置脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat << EOF
用法: $(basename $0) [选项]

选项:
    -b, --basic           基础配置
    -s, --security       安全加固
    -p, --performance    性能优化
    -n, --network        网络配置
    -m, --monitor        监控配置
    -a, --all            全部配置
    -h, --help           显示帮助
EOF
    exit 1
}

configure_basic() {
    echo "=== 基础配置 ==="
    
    echo "设置时区..."
    timedatectl set-timezone Asia/Shanghai 2>/dev/null || true
    
    echo "配置DNS..."
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 114.114.114.114" >> /etc/resolv.conf
    
    echo "更新yum源..."
    yum clean all 2>/dev/null || true
    yum makecache 2>/dev/null || true
    
    echo "基础配置完成"
}

configure_security() {
    echo "=== 安全加固 ==="
    
    echo "配置防火墙..."
    systemctl enable firewalld 2>/dev/null || true
    systemctl start firewalld 2>/dev/null || true
    
    echo "开放SSH端口..."
    firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    
    echo "禁用root登录..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null || true
    
    echo "禁用密码认证..."
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || true
    
    echo "配置SELinux..."
    setenforce 1 2>/dev/null || true
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true
    
    echo "安全加固完成"
}

configure_performance() {
    echo "=== 性能优化 ==="
    
    echo "配置内核参数..."
    cat >> /etc/sysctl.conf << 'EOF'
net.core.somaxconn = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_max_syn_backlog = 65535
EOF
    
    sysctl -p 2>/dev/null || true
    
    echo "配置limits..."
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    echo "性能优化完成"
}

configure_network() {
    echo "=== 网络配置 ==="
    
    echo "配置主机名..."
    hostnamectl set-hostname "$(hostname)"
    
    echo "配置hosts..."
    local ip
    ip=$(hostname -I | awk '{print $1}')
    echo "${ip} $(hostname)" >> /etc/hosts
    
    echo "网络配置完成"
}

configure_monitor() {
    echo "=== 监控配置 ==="
    
    echo "安装监控工具..."
    yum install -y sysstat htop iotop iftop 2>/dev/null || \
        apt install -y sysstat htop iotop iftop 2>/dev/null || true
    
    echo "配置日志轮转..."
    cat > /etc/logrotate.d/syslog << 'EOF'
/var/log/syslog {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 syslog adm
}
EOF
    
    echo "监控配置完成"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--basic)
            configure_basic
            shift
            ;;
        -s|--security)
            configure_security
            shift
            ;;
        -p|--performance)
            configure_performance
            shift
            ;;
        -n|--network)
            configure_network
            shift
            ;;
        -m|--monitor)
            configure_monitor
            shift
            ;;
        -a|--all)
            configure_basic
            configure_security
            configure_performance
            configure_network
            configure_monitor
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            usage
            ;;
    esac
done

[[ $# -eq 0 ]] && usage