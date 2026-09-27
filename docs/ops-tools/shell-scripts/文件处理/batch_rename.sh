#!/bin/bash

# 批量重命名工具 - 支持多种重命名模式

usage() {
    cat << EOF
用法: $(basename $0) [选项] <目录>

选项:
    -d, --date          添加日期前缀 (YYYYMMDD)
    -s, --seq           添加序号 (001, 002...)
    -t, --time          添加时间前缀 (HHMMSS)
    -p, --prefix <str>  添加自定义前缀
    -r, --replace <old>:<new>  替换文件名中的字符
    -u, --upper         转为大写
    -l, --lower         转为小写
    -e, --ext <ext>     更改扩展名
    -n, --dry-run       模拟运行(不实际修改)
    -h, --help          显示帮助

示例:
    $(basename $0) -d /path/to/files      # 添加日期前缀
    $(basename $0) -s /path/to/files      # 添加序号
    $(basename $0) -r ".txt:.md" /path     # .txt改为.md
    $(basename $0) -u /path              # 转为大写
EOF
    exit 1
}

DRY_RUN=false
RENAME_MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--date)
            RENAME_MODE="date"
            shift
            ;;
        -s|--seq)
            RENAME_MODE="seq"
            shift
            ;;
        -t|--time)
            RENAME_MODE="time"
            shift
            ;;
        -p|--prefix)
            RENAME_MODE="prefix"
            PREFIX_STR="$2"
            shift 2
            ;;
        -r|--replace)
            RENAME_MODE="replace"
            OLD="${2%%:*}"
            NEW="${2##*:}"
            shift 2
            ;;
        -u|--upper)
            RENAME_MODE="upper"
            shift
            ;;
        -l|--lower)
            RENAME_MODE="lower"
            shift
            ;;
        -e|--ext)
            RENAME_MODE="ext"
            NEW_EXT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            usage
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

[[ -z "$TARGET_DIR" ]] && usage
[[ ! -d "$TARGET_DIR" ]] && echo "错误: 目录不存在" && exit 1

cd "$TARGET_DIR" || exit 1

counter=1
for file in *; do
    [[ "$file" == "*" ]] && continue
    [[ -d "$file" ]] && continue
    
    newname=""
    base="${file%.*}"
    ext="${file##*.}"
    [[ "$base" == "$ext" ]] && ext=""
    
    case $RENAME_MODE in
        date)
            newname="$(date +%Y%m%d)_$file"
            ;;
        seq)
            printf -v newname "%03d_%s" "$counter" "$file"
            ((counter++))
            ;;
        time)
            newname="$(date +%H%M%S)_$file"
            ;;
        prefix)
            newname="${PREFIX_STR}${file}"
            ;;
        replace)
            newname="${file//$OLD/$NEW}"
            ;;
        upper)
            newname="${file^^}"
            ;;
        lower)
            newname="${file,,}"
            ;;
        ext)
            if [[ -n "$ext" ]]; then
                newname="${base}.${NEW_EXT}"
            else
                newname="${file}.${NEW_EXT}"
            fi
            ;;
        *)
            echo "错误: 请指定重命名模式"
            exit 1
            ;;
    esac
    
    if [[ "$file" != "$newname" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY-RUN] $file -> $newname"
        else
            mv -n "$file" "$newname" 2>/dev/null || echo "已存在或跳过: $file"
        fi
    fi
done

echo "完成!"