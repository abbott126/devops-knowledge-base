#!/bin/bash

# 快速命令启动器

set -euo pipefail

ALIAS_FILE="${HOME}/.quick_commands"

init_aliases() {
    mkdir -p "$(dirname "$ALIAS_FILE")"
    cat > "$ALIAS_FILE" << 'EOF'
# 快速命令配置
# 格式: alias|命令|描述
gs|git status|Git状态
ga|git add .|Git添加
gc|git commit -m |Git提交
gp|git push|Git推送
ll|ls -lah|详细列表
la|ls -A|显示隐藏
eg|grep -E |正则grep
nf|find . -name |查找文件
EOF
    echo "配置已创建: $ALIAS_FILE"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    run <alias> [args]      运行快速命令
    add <alias> <cmd> <desc> 添加命令
    list                    列出所有命令
    edit                    编辑配置
    search <keyword>       搜索命令

示例:
    $(basename $0) run gs
    $(basename $0) add tk "tail -f /var/log/syslog" "查看系统日志"
EOF
    exit 1
}

run_alias() {
    local alias="$1"
    shift
    local args="$@"
    
    local cmd
    cmd=$(grep "^${alias}|" "$ALIAS_FILE" | cut -d'|' -f2)
    
    [[ -z "$cmd" ]] && echo "命令不存在: $alias" && return 1
    
    echo "执行: $cmd $args"
    eval "$cmd $args"
}

add_alias() {
    local alias="$1"
    local cmd="$2"
    local desc="${3:-}"
    
    echo "$alias|$cmd|$desc" >> "$ALIAS_FILE"
    echo "已添加: $alias -> $cmd"
}

list_aliases() {
    echo "=== 快速命令 ==="
    grep -v "^#" "$ALIAS_FILE" | grep -v "^$" | while IFS='|' read -r alias cmd desc; do
        [[ -z "$alias" ]] && continue
        printf "%-10s %-40s %s\n" "$alias" "$cmd" "$desc"
    done
}

search_aliases() {
    local keyword="$1"
    
    echo "=== 搜索: $keyword ==="
    grep -i "$keyword" "$ALIAS_FILE" | while IFS='|' read -r alias cmd desc; do
        [[ -z "$alias" ]] && continue
        echo "$alias: $cmd ($desc)"
    done
}

[[ ! -f "$ALIAS_FILE" ]] && init_aliases

case "${1:-}" in
    run)
        shift
        run_alias "$@"
        ;;
    add)
        add_alias "$2" "$3" "${4:-}"
        ;;
    list)
        list_aliases
        ;;
    edit)
        ${EDITOR:-vi} "$ALIAS_FILE"
        ;;
    search)
        search_aliases "$2"
        ;;
    *)
        usage
        ;;
esac