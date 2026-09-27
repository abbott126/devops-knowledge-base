#!/bin/bash

# Cron作业管理器

set -euo pipefail

CRON_DIR="/etc/cron.d"
CRON_USER_DIR="/var/spool/cron/crontabs"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    add <name> <schedule> <command>        添加cron任务
    add-user <user> <name> <schedule> <cmd>  添加用户cron
    del <name>                        删除系统cron
    del-user <user> <name>             删除用户cron
    list                              列出所有cron
    enable <name>                     启用cron
    disable <name>                    禁用cron
    backup                            备份cron配置
    restore <file>                    恢复cron配置

示例:
    $(basename $0) add myjob "0 * * * *" "/path/to/script.sh"
    $(basename $0) add-user root dailyjob "0 2 * * *" "/scripts/backup.sh"
EOF
    exit 1
}

add_cron() {
    local name="$1"
    local schedule="$2"
    local cmd="$3"
    
    local cron_file="${CRON_DIR}/${name}"
    
    cat > "$cron_file" << EOF
# Cron job: $name
# Created: $(date)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

$schedule $cmd
EOF
    
    chmod 644 "$cron_file"
    echo "Cron已添加: $name ($schedule)"
}

add_user_cron() {
    local user="$1"
    local name="$2"
    local schedule="$3"
    local cmd="$4"
    
    local crontab_file="${CRON_USER_DIR}/${user}"
    
    if [[ -f "$crontab_file" ]]; then
        if grep -q "^#.*${name}" "$crontab_file"; then
            echo "任务已存在: $name"
            return 1
        fi
    fi
    
    {
        echo ""
        echo "# ${name} - $(date)"
        echo "${schedule} ${cmd}"
    } >> "$crontab_file"
    
    chmod 600 "$crontab_file"
    chown "$user:" "$crontab_file"
    
    echo "用户cron已添加: $user:$name"
}

delete_cron() {
    local name="$1"
    local cron_file="${CRON_DIR}/${name}"
    
    if [[ -f "$cron_file" ]]; then
        rm -f "$cron_file"
        echo "Cron已删除: $name"
    else
        echo "Cron不存在: $name"
    fi
}

delete_user_cron() {
    local user="$1"
    local name="$2"
    local crontab_file="${CRON_USER_DIR}/${user}"
    
    if [[ -f "$crontab_file" ]]; then
        sed -i "/^#.*${name}/d;/^[^#].*${name}/d" "$crontab_file"
        echo "用户cron已删除: $user:$name"
    else
        echo "用户cron不存在: $user"
    fi
}

list_crons() {
    echo "=== 系统Cron ==="
    for f in "$CRON_DIR"/*; do
        [[ -f "$f" ]] || continue
        echo "--- $(basename "$f") ---"
        grep -v "^#" "$f" | grep -v "^$" | head -3
    done
    
    echo ""
    echo "=== 用户Cron ==="
    for f in "$CRON_USER_DIR"/*; do
        [[ -f "$f" ]] || continue
        echo "--- $(basename "$f") ---"
        grep -v "^#" "$f" | grep -v "^$" | head -5
    done
}

enable_cron() {
    local name="$1"
    local cron_file="${CRON_DIR}/${name}"
    
    if [[ -f "${cron_file}.disabled" ]]; then
        mv "${cron_file}.disabled" "$cron_file"
        echo "Cron已启用: $name"
    else
        echo "Cron未找到或未禁用: $name"
    fi
}

disable_cron() {
    local name="$1"
    local cron_file="${CRON_DIR}/${name}"
    
    if [[ -f "$cron_file" ]]; then
        mv "$cron_file" "${cron_file}.disabled"
        echo "Cron已禁用: $name"
    else
        echo "Cron不存在: $name"
    fi
}

backup_crons() {
    local backup_file="cron_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar -czf "$backup_file" "$CRON_DIR" "$CRON_USER_DIR" 2>/dev/null || \
        tar -czf "$backup_file" "$CRON_DIR"
    
    echo "备份完成: $backup_file"
}

restore_crons() {
    local backup_file="$1"
    
    [[ ! -f "$backup_file" ]] && echo "备份文件不存在" && exit 1
    
    tar -xzf "$backup_file" -C / || echo "恢复失败"
    
    echo "恢复完成"
}

case "${1:-}" in
    add)
        add_cron "$2" "$3" "$4"
        ;;
    add-user)
        add_user_cron "$2" "$3" "$4" "$5"
        ;;
    del)
        delete_cron "$2"
        ;;
    del-user)
        delete_user_cron "$2" "$3"
        ;;
    list)
        list_crons
        ;;
    enable)
        enable_cron "$2"
        ;;
    disable)
        disable_cron "$2"
        ;;
    backup)
        backup_crons
        ;;
    restore)
        restore_crons "$2"
        ;;
    *)
        usage
        ;;
esac