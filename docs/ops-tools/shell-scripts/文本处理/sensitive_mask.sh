#!/bin/bash

# 敏感信息扫描和脱敏工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    scan <file>              扫描敏感信息
    mask <file>            脱敏文件
    rule-list              列出脱敏规则
    add-rule <pattern> <type> 添加脱敏规则

示例:
    $(basename $0) scan config.ini
    $(basename $0) mask data.csv
EOF
    exit 1
}

RULES_FILE="${HOME}/.mask_rules"

init_rules() {
    mkdir -p "$(dirname "$RULES_FILE")"
    cat > "$RULES_FILE" << 'EOF'
# 脱敏规则: pattern|type|replace
phone|#1[3-9]\d{9}|138****\d{4}
email|\w+@\w+\.\w+|xxx@xxx.com
idcard|[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dXx]|******** ******\d{4}
bankcard|\d{16,19}|**** **** **** \d{4}
ip|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|xxx.xxx.xxx.xxx
password|password\s*=\s*\S+|password=***
EOF
    echo "规则文件已创建: $RULES_FILE"
}

load_rules() {
    [[ ! -f "$RULES_FILE" ]] && init_rules
    cat "$RULES_FILE" | grep -v "^#" | grep -v "^$"
}

scan_sensitive() {
    local file="$1"
    
    echo "=== 敏感信息扫描 ==="
    echo "文件: $file"
    echo ""
    
    while IFS='|' read -r pattern replace; do
        [[ -z "$pattern" ]] && continue
        
        count=$(grep -oE "$pattern" "$file" 2>/dev/null | wc -l)
        [[ "$count" -gt 0 ]] && echo "发现: $pattern ($count处)"
    done < <(load_rules)
}

mask_file() {
    local file="$1"
    local output="${2:-}"
    
    [[ ! -f "$file" ]] && echo "文件不存在" && exit 1
    
    local backup
    backup="${file}.bak.$(date +%s)"
    cp "$file" "$backup"
    
    local temp_file
    temp_file=$(mktemp)
    
    cp "$file" "$temp_file"
    
    while IFS='|' read -r pattern replace; do
        [[ -z "$pattern" ]] && continue
        sed -i -E "s/$pattern/$replace/g" "$temp_file"
    done < <(load_rules)
    
    if [[ -n "$output" ]]; then
        mv "$temp_file" "$output"
    else
        mv "$temp_file" "$file"
    fi
    
    echo "脱敏完成: $file"
}

list_rules() {
    echo "=== 脱敏规则 ==="
    load_rules | while IFS='|' read -r pattern replace; do
        [[ -z "$pattern" ]] && continue
        printf "%-40s -> %s\n" "$pattern" "$replace"
    done
}

add_rule() {
    local pattern="$1"
    local replace="$2"
    
    echo "$pattern|$replace" >> "$RULES_FILE"
    echo "规则已添加: $pattern -> $replace"
}

case "${1:-}" in
    scan)
        scan_sensitive "$2"
        ;;
    mask)
        mask_file "$2" "${3:-}"
        ;;
    rule-list)
        list_rules
        ;;
    add-rule)
        add_rule "$2" "$3"
        ;;
    *)
        usage
        ;;
esac