#!/bin/bash

# 用户和权限管理工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    add <username> <shell> [home]     添加用户
    del <username>                   删除用户
    mod <username> <shell>           修改用户shell
    pass <username>                  强制修改密码
    sudoers <username>               添加sudo权限
    groups <username> <group>        添加到组
    locks <username>                  锁定账户
    unlocks <username>                解锁账户
    list                             列出所有用户
    audit                            审计账户安全

示例:
    $(basename $0) add john /bin/bash /home/john
    $(basename $0) sudoers john
    $(basename $0) audit
EOF
    exit 1
}

add_user() {
    local username="$1"
    local shell="${2:-/bin/bash}"
    local home="${3:-/home/$username}"
    
    if id "$username" >/dev/null 2>&1; then
        echo "用户已存在: $username"
        return 1
    fi
    
    useradd -m -s "$shell" -d "$home" "$username"
    mkdir -p "$home"
    chmod 755 "$home"
    
    echo "用户已创建: $username (shell: $shell, home: $home)"
    
    passwd -d "$username" 2>/dev/null || true
    
    echo "请设置密码: passwd $username"
}

delete_user() {
    local username="$1"
    
    if ! id "$username" >/dev/null 2>&1; then
        echo "用户不存在: $username"
        return 1
    fi
    
    userdel -r "$username" 2>/dev/null || userdel "$username"
    
    echo "用户已删除: $username"
}

modify_user() {
    local username="$1"
    local shell="$2"
    
    chsh -s "$shell" "$username" 2>/dev/null || usermod -s "$shell" "$username"
    
    echo "用户shell已修改: $username -> $shell"
}

force_password() {
    local username="$1"
    
    passwd -e "$username"
    
    echo "已强制 $username 下次登录修改密码"
}

add_sudo() {
    local username="$1"
    local sudoers_file="/etc/sudoers.d/${username}"
    
    if id "$username" >/dev/null 2>&1; then
        echo "$username ALL=(ALL) ALL" > "$sudoers_file"
        chmod 440 "$sudoers_file"
        
        echo "已添加sudo权限: $username"
    else
        echo "用户不存在: $username"
    fi
}

add_to_group() {
    local username="$1"
    local group="$2"
    
    usermod -aG "$group" "$username"
    
    echo "已添加 $username 到组: $group"
}

lock_user() {
    local username="$1"
    
    passwd -l "$username"
    
    echo "账户已锁定: $username"
}

unlock_user() {
    local username="$1"
    
    passwd -u "$username"
    
    echo "账户已解锁: $username"
}

list_users() {
    echo "=== 用户列表 ==="
    echo "用户名:UID:GID:Shell:主目录"
    echo "---"
    
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1":"$3":"$4":"$7":"$6}' /etc/passwd
}

audit_users() {
    echo "=== 账户安全审计 ==="
    echo ""
    
    echo "1. 无密码账户:"
    awk -F: 'length($2)==1 || $2=="!" {print "  " $1}' /etc/shadow
    
    echo ""
    echo "2. 可登录账户:"
    awk -F: '$7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false" {print "  " $1 " (" $7 ")"}' /etc/passwd
    
    echo ""
    echo "3. sudo权限:"
    for f in /etc/sudoers.d/*; do
        [[ -f "$f" ]] && echo "  $(basename $f): $(head -1 "$f")"
    done
    
    echo ""
    echo "4. 最近创建的用户:"
    ls -lt /home/ 2>/dev/null | head -5
    
    echo ""
    echo "5. 锁定状态:"
    grep -L '!' /etc/shadow 2>/dev/null | awk -F: '{print "  " $1 " (未锁定)"}' || true
}

case "${1:-}" in
    add)
        add_user "$2" "${3:-/bin/bash}" "${4:-}"
        ;;
    del)
        delete_user "$2"
        ;;
    mod)
        modify_user "$2" "$3"
        ;;
    pass)
        force_password "$2"
        ;;
    sudoers)
        add_sudo "$2"
        ;;
    groups)
        add_to_group "$2" "$3"
        ;;
    locks)
        lock_user "$2"
        ;;
    unlocks)
        unlock_user "$2"
        ;;
    list)
        list_users
        ;;
    audit)
        audit_users
        ;;
    *)
        usage
        ;;
esac