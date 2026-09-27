#!/bin/bash

# 代码片段收集工具

set -euo pipefail

SNIPPET_DIR="${HOME}/.snippets"

init_snippets() {
    mkdir -p "$SNIPPET_DIR"
    echo "代码片段目录: $SNIPPET_DIR"
}

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    add <name>                添加代码片段
    get <name>                获取代码片段
    list                     列出所有片段
    del <name>                删除片段
    edit <name>               编辑片段
    search <keyword>          搜索片段

示例:
    $(basename $0) add nginx
    $(basename $0) get nginx
    $(basename $0) list
EOF
    exit 1
}

add_snippet() {
    local name="$1"
    local file="${SNIPPET_DIR}/${name}.sh"
    
    [[ -f "$file" ]] && echo "片段已存在" && return
    
    echo "# 代码片段: $name" > "$file"
    echo "# 按Ctrl+D保存" >> "$file"
    echo "" >> "$file"
    
    cat >> "$file"
    
    echo "已保存: $name"
}

get_snippet() {
    local name="$1"
    local file="${SNIPPET_DIR}/${name}.sh"
    
    [[ -f "$file" ]] && cat "$file" || echo "片段不存在: $name"
}

list_snippets() {
    echo "=== 代码片段 ==="
    for f in "$SNIPPET_DIR"/*.sh; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .sh)
        local lines
        lines=$(wc -l < "$f")
        echo "$name ($lines行)"
    done
}

delete_snippet() {
    local name="$1"
    local file="${SNIPPET_DIR}/${name}.sh"
    
    [[ -f "$file" ]] && rm -f "$file" && echo "已删除: $name" || echo "片段不存在: $name"
}

edit_snippet() {
    local name="$1"
    local file="${SNIPPET_DIR}/${name}.sh"
    
    ${EDITOR:-vi} "$file"
}

search_snippets() {
    local keyword="$1"
    
    echo "=== 搜索结果: $keyword ==="
    grep -l "$keyword" "$SNIPPET_DIR"/*.sh 2>/dev/null | while read -r file; do
        echo "--- $(basename "$file") ---"
        grep -n "$keyword" "$file" | head -3
    done
}

[[ ! -d "$SNIPPET_DIR" ]] && init_snippets

case "${1:-}" in
    add)
        shift
        add_snippet "$@"
        ;;
    get)
        get_snippet "$2"
        ;;
    list)
        list_snippets
        ;;
    del)
        delete_snippet "$2"
        ;;
    edit)
        edit_snippet "$2"
        ;;
    search)
        search_snippets "$2"
        ;;
    *)
        usage
        ;;
esac