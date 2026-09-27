#!/bin/bash

# 文本批量替换工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) [选项] <文件>

选项:
    -s, --search <pattern>   搜索模式
    -r, --replace <text>     替换文本
    -w, --word              整词匹配
    -i, --ignore-case      忽略大小写
    -g, --global           全局替换
    -n, --line-number      显示行号
    -l, --list             仅列出匹配
    -v, --invert           反向匹配
    -e, --ext <ext>        文件扩展名
    -d, --dry-run          模拟运行
    -h, --help             显示帮助

示例:
    $(basename $0) -s "old" -r "new" file.txt
    $(basename $0) -w -s "error" -r "Error" *.log
    $(basename $0) -l -s "exception" /var/log/*.log
EOF
    exit 1
}

SEARCH=""
REPLACE=""
EXT="*"
DRY_RUN=false
LIST_ONLY=false
WORD=false
GLOBAL=true
IGNORE_CASE=false
LINE_NUMBER=false
INVERT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--search)
            SEARCH="$2"
            shift 2
            ;;
        -r|--replace)
            REPLACE="$2"
            shift 2
            ;;
        -w|--word)
            WORD=true
            shift
            ;;
        -i|--ignore-case)
            IGNORE_CASE=true
            shift
            ;;
        -g|--global)
            GLOBAL=true
            shift
            ;;
        -n|--line-number)
            LINE_NUMBER=true
            shift
            ;;
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        -v|--invert)
            INVERT=true
            shift
            ;;
        -e|--ext)
            EXT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            shift
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

[[ -z "$SEARCH" ]] && usage
[[ -z "$TARGET" ]] && usage

OPTIONS=()
[[ "$WORD" == "true" ]] && OPTIONS+=("-w")
[[ "$IGNORE_CASE" == "true" ]] && OPTIONS+=("-i")
[[ "$GLOBAL" == "true" ]] && OPTIONS+=("-g")
[[ "$LINE_NUMBER" == "true" ]] && OPTIONS+=("-n")
[[ "$INVERT" == "true" ]] && OPTIONS+=("-v")

if [[ "$LIST_ONLY" == "true" ]]; then
    grep -r "${OPTIONS[@]}" "$SEARCH" "$TARGET" --include="$EXT" 2>/dev/null || \
        grep -r "${OPTIONS[@]}" "$SEARCH" "$TARGET" 2>/dev/null
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    find . -name "$EXT" -type f 2>/dev/null | while read -r file; do
        result=$(grep -l "${OPTIONS[@]}" "$SEARCH" "$file" 2>/dev/null || true)
        [[ -n "$result" ]] && echo "匹配: $file"
    done
    exit 0
fi

if [[ -n "$REPLACE" ]]; then
    find . -name "$EXT" -type f 2>/dev/null | while read -r file; do
        sed -i "${OPTIONS[@]//-n/}" "s/$SEARCH/$REPLACE/g" "$file" 2>/dev/null || true
    done
    echo "替换完成"
else
    grep "${OPTIONS[@]}" "$SEARCH" "$TARGET" || true
fi