#!/bin/bash

# Keepalived + Nginx 高可用集群

set -euo pipefail

VRRP_VIP="${VRRP_VIP:-192.168.1.100}"
VRRP_PASSWORD="${VRRP_PASSWORD:-123456}"
PRIORITY_1="${PRIORITY_1:-100}"
PRIORITY_2="${PRIORITY_2:-90}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    master                    配置为主节点
    backup                   配置为备节点
    start                    启动 Keepalived
    status                   查看状态
    stop                     停止

示例:
    $(basename $0) master 192.168.1.101
EOF
    exit 1
}

install_keepalived() {
    echo "=== 安装 Keepalived ==="
    
    if command -v keepalived >/dev/null 2>&1; then
        echo "Keepalived已安装"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y keepalived
    elif command -v yum >/dev/null 2>&1; then
        yum install -y keepalived
    fi
    
    echo "Keepalived安装完成"
}

config_master() {
    local node_ip="$1"
    local priority="${2:-$PRIORITY_1}"
    
    cat > /etc/keepalived/keepalived.conf << EOF
! Configuration File for keepalived

global_defs {
   router_id LB1
   vrrp_garp_interval 3
   vrrp_gna_interval 3
}

vrrp_instance VI_1 {
    state MASTER
    interface $(ip route get 1.1.1.1 | grep -oP 'dev \K[^ ]+')
    virtual_router_id 51
    priority $priority
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass $VRRP_PASSWORD
    }
    
    virtual_ipaddress {
        $VRRP_VIP dev $(ip route get 1.1.1.1 | grep -oP 'dev \K[^ ]+')
    }
    
    track_script {
        chk_nginx
    }
}

vrrp_script chk_nginx {
    script "/usr/bin/pkill -0 nginx"
    interval 3
    weight -30
    fall 2
    rise 2
}
EOF
    
    echo "主节点配置完成: $node_ip"
}

config_backup() {
    local node_ip="$1"
    local priority="${2:-$PRIORITY_2}"
    
    cat > /etc/keepalived/keepalived.conf << EOF
! Configuration File for keepalived

global_defs {
   router_id LB2
   vrrp_garp_interval 3
}

vrrp_instance VI_1 {
    state BACKUP
    interface $(ip route get 1.1.1.1 | grep -oP 'dev \K[^ ]+')
    virtual_router_id 51
    priority $priority
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass $VRRP_PASSWORD
    }
    
    virtual_ipaddress {
        $VRRP_VIP dev $(ip route get 1.1.1.1 | grep -oP 'dev \K[^ ]+')
    }
    
    track_script {
        chk_nginx
    }
}

vrrp_script chk_nginx {
    script "/usr/bin/pkill -0 nginx"
    interval 3
    weight -30
}
EOF
    
    echo "备节点配置完成: $node_ip"
}

start_keepalived() {
    systemctl enable keepalived
    systemctl start keepalived
    echo "Keepalived已启动"
}

check_status() {
    echo "=== Keepalived状态 ==="
    systemctl status keepalived --no-pager || true
    echo ""
    echo "=== VIP状态 ==="
    ip addr show | grep "$VRRP_VIP" && echo "VIP在线" || echo "VIP离线"
    echo ""
    echo "=== VRRP组播 ==="
    tcpdump -i any -c 3 vrrp 2>/dev/null | head -10 || echo "需要tcpdump权限"
}

case "${1:-}" in
    master)
        install_keepalived
        config_master "${2:-192.168.1.101}" "${3:-}"
        start_keepalived
        ;;
    backup)
        install_keepalived
        config_backup "${2:-192.168.1.102}" "${3:-}"
        start_keepalived
        ;;
    start)
        start_keepalived
        ;;
    status)
        check_status
        ;;
    stop)
        systemctl stop keepalived
        echo "已停止"
        ;;
    *)
        usage
        ;;
esac