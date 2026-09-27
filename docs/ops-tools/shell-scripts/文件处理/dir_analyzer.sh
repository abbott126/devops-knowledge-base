#!/bin/bash

# 文件夹大小分析器 - 递归统计目录占用

set -euo pipefail

TARGET_DIR="${1:-.}"
DEPTH="${2:-1}"
SORT_BY="${3:-size}"

usage() {
    cat << EOF
用法: $(basename $0) [目录] [深度] [排序方式]

深度: 1=直接子目录, 2=二级子目录, ...
排序: size(大小), count(文件数), name(名称)

示例:
    $(basename $0) /home 2 size
    $(basename $0) /var 1 count
EOF
    exit 1
}

[[ ! -d "$TARGET_DIR" ]] && echo "目录不存在: $TARGET_DIR" && exit 1

declare -A dir_sizes
declare -A file_counts

scan_dir() {
    local dir="$1"
    local depth="$2"
    
    if [[ $depth -le 0 ]]; then
        return
    fi
    
    local total_size=0
    local file_count=0
    
    while IFS= read -r -d '' file; do
        if [[ -d "$file" ]]; then
            scan_dir "$file" $((depth - 1))
        else
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
            total_size=$((total_size + size))
            ((file_count++))
        fi
    done < <(find "$dir" -maxdepth 1 -print0 2>/dev/null)
    
    dir_sizes["$dir"]=$total_size
    file_counts["$dir"]=$file_count
}

echo "=== 目录占用分析 ==="
echo "目录: $TARGET_DIR"
echo "深度: $DEPTH"
echo ""

scan_dir "$TARGET_DIR" "$DEPTH"

case "$SORT_BY" in
    size)
        for dir in "${!dir_sizes[@]}"; do
            echo "${dir_sizes[$dir]} $dir ${file_counts[$dir]}"
        done | sort -rn | head -20 | while read -r size dir count; do
            printf "%s %s (%d files)\n" "$(numfmt --to=iec-i --suffix=B $size)" "$dir" "$count"
        done
        ;;
    count)
        for dir in "${!file_counts[@]}"; do
            echo "${file_counts[$dir]} $dir ${dir_sizes[$dir]}"
        done | sort -rn | head -20 | while read -r count dir size; do
            printf "%d files %s (%s)\n" "$count" "$dir" "$(numfmt --to=iec-i --suffix=B $size)"
        done
        ;;
    *)
        for dir in "${!dir_sizes[@]}"; do
            printf "%s %s (%d files)\n" "$(numfmt --to=iec-i --suffix=B ${dir_sizes[$dir]:-0})" "$dir" "${file_counts[$dir]:-0}"
        done | sort
        ;;
esac