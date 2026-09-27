#!/bin/bash

# 文件编码检测和转换工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    detect <file>               检测文件编码
    convert <file> <to>        转换编码
    detect-dir <dir>           批量检测目录
    fix-encoding <file>        尝试修复编码
    to-utf8 <file>           转换为UTF8
    to-gb2312 <file>         转换为GB2312

示例:
    $(basename $0) detect script.sh
    $(basename $0) convert file.txt utf-8 gb2312
    $(basename $0) to-utf8 *.txt
EOF
    exit 1
}

has_iconv() {
    command -v iconv >/dev/null 2>&1
}

has_file_cmd() {
    command -v file >/dev/null 2>&1
}

detect_encoding() {
    local file="$1"
    
    if has_file_cmd; then
        file -bi "$file" | sed 's/.*charset=\(.*\)/\1/'
    elif has_iconv; then
        iconv -l | while read -r enc; do
            iconv -f "$enc" -t "$enc" "$file" >/dev/null 2>&1 && echo "$enc" && break
        done
    else
        echo "UTF-8"
    fi
}

convert_encoding() {
    local file="$1"
    local from_enc="$2"
    local to_enc="$3"
    local output="${4:-}"
    
    if ! has_iconv; then
        echo "iconv未安装"
        exit 1
    fi
    
    if [[ -z "$output" ]]; then
        output="${file}.${to_enc}"
    fi
    
    iconv -f "$from_enc" -t "$to_enc" "$file" > "$output" 2>/dev/null || \
        echo "转换失败"
    
    echo "已转换: $output"
}

detect_dir() {
    local dir="$1"
    
    echo "=== 目录编码检测 ==="
    
    while IFS= read -r -d '' file; do
        encoding=$(detect_encoding "$file")
        echo "$encoding: $file"
    done < <(find "$dir" -type f -print0)
}

fix_encoding() {
    local file="$1"
    local backups
    
    backups="${file}.bak.$(date +%s)"
    cp "$file" "$backups"
    
    for enc in UTF-8 GBK GB2312 ISO-8859-1; do
        if iconv -f "$enc" -t UTF-8 "$file" > "${file}.tmp" 2>/dev/null; then
            mv "${file}.tmp" "$file"
            echo "修复成功: $file ($enc -> UTF-8)"
            return 0
        fi
    done
    
    rm -f "${file}.tmp"
    echo "无法修复: $file"
    return 1
}

to_utf8() {
    local file="$1"
    local output="${2:-}"
    
    local encoding
    encoding=$(detect_encoding "$file")
    
    if [[ "$encoding" == "utf-8" ]]; then
        echo "已是UTF-8: $file"
        return 0
    fi
    
    convert_encoding "$file" "$encoding" "UTF-8" "$output"
}

to_gb2312() {
    local file="$1"
    local output="${2:-}"
    
    convert_encoding "$file" "UTF-8" "GB2312" "$output"
}

case "${1:-}" in
    detect)
        detect_encoding "$2"
        ;;
    convert)
        convert_encoding "$2" "$3" "$4" "${5:-}"
        ;;
    detect-dir)
        detect_dir "$2"
        ;;
    fix-encoding)
        fix_encoding "$2"
        ;;
    to-utf8)
        to_utf8 "$2" "${3:-}"
        ;;
    to-gb2312)
        to_gb2312 "$2" "${3:-}"
        ;;
    *)
        usage
        ;;
esac