#!/bin/bash

# 重复文件查找器 - 使用MD5和inode去重

set -euo pipefail

TARGET_DIR="${1:-.}"
MIN_SIZE="${2:-1024}"

usage() {
    cat << EOF
用法: $(basename $0) [目录] [最小文件大小]

示例:
    $(basename $0) /home/user 10240    # 查找大于10KB的重复文件
    $(basename $0) /var/log      # 查找/var/log中的重复文件
EOF
    exit 1
}

[[ -z "$TARGET_DIR" ]] && usage
[[ ! -d "$TARGET_DIR" ]] && echo "目录不存在: $TARGET_DIR" && exit 1

echo "=== 重复文件查找器 ==="
echo "扫描目录: $TARGET_DIR"
echo "最小文件: $MIN_SIZE bytes"
echo ""

declare -A hash_map
declare -A file_info

mapfile -t files < <(find "$TARGET_DIR" -type f -size +${MIN_SIZE}c -exec stat -c '%n %s %i' {} + 2>/dev/null | \
    sort -k2 -n | \
    while read -r name size inode; do
        echo "$size:$inode:$name"
    done | sort -u -t: -k1,1n)

total_dups=0
total_waste=0

for entry in "${files[@]}"; do
    size="${entry%%:*}"
    rest="${entry#*:}"
    inode="${rest%%:*}"
    file="${rest##*:}"
    
    [[ -z "$file" ]] && continue
    
    hash=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1) || continue
    
    key="${size}:${hash}"
    
    if [[ -z "${hash_map[$key]:-}" ]]; then
        hash_map[$key]="$file"
        file_info[$key]="$inode:$size"
    else
        original="${hash_map[$key]}"
        orig_inode="${file_info[$key]%%:*}"
        
        if [[ "$inode" != "$orig_inode" ]]; then
            if [[ "$total_dups" -eq 0 ]]; then
                echo "发现重复文件:"
                echo "--- (原始) ${original}"
                echo "    大小: ${size} bytes"
            fi
            
            echo "--- (重复) ${file}"
            ((total_waste+=size))
            ((total_dups++))
        fi
    fi
done

echo ""
echo "=== 统计 ==="
echo "重复文件数: $total_dups"
echo "浪费空间: $(numfmt --to=iec-i --suffix=B $total_waste 2>/dev/null || echo "${total_waste} bytes")"