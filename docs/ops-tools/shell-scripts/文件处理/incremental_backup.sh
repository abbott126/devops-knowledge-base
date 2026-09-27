#!/bin/bash

# 增量备份工具 - 支持差异备份和压缩

set -euo pipefail

SOURCE_DIR=""
BACKUP_DIR=""
EXCLUDE_FILE=""
LOG_FILE=""
MAX_BACKUPS=7

usage() {
    cat << EOF
用法: $(basename $0) [选项]

选项:
    -s, --source <dir>    源目录 (必填)
    -d, --dest <dir>     备份目录 (必填)
    -e, --exclude <file> 排除文件列表
    -m, --max <n>       保留最大备份数(默认7)
    -c, --compress      使用压缩
    -i, --incremental    增量备份模式
    -v, --verbose       详细输出
    -h, --help          显示帮助
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -d|--dest)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_FILE="$2"
            shift 2
            ;;
        -m|--max)
            MAX_BACKUPS="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -i|--incremental)
            INCREMENTAL=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "未知选项: $1"
            usage
            ;;
    esac
done

[[ -z "$SOURCE_DIR" ]] || [[ -z "$BACKUP_DIR" ]] && usage
[[ ! -d "$SOURCE_DIR" ]] && echo "源目录不存在" && exit 1

COMPRESS="${COMPRESS:-false}"
INCREMENTAL="${INCREMENTAL:-false}"
VERBOSE="${VERBOSE:-false}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

log() {
    [[ "$VERBOSE" == "true" ]] && echo "[$(date +%H:%M:%S)] $*"
}

exclude_args=()
if [[ -n "$EXCLUDE_FILE" ]] && [[ -f "$EXCLUDE_FILE" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && exclude_args+=("--exclude" "$line")
    done < "$EXCLUDE_FILE"
fi

log "开始备份 $SOURCE_DIR -> $BACKUP_PATH"

if [[ "$COMPRESS" == "true" ]]; then
    tar -czf "${BACKUP_PATH}.tar.gz" \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")" \
        "${exclude_args[@]}" 2>/dev/null || \
        tar -czf "${BACKUP_PATH}.tar.gz" \
            "${exclude_args[@]}" "$SOURCE_DIR"
else
    mkdir -p "$BACKUP_PATH"
    rsync -a --delete \
        "${exclude_args[@]}" \
        "${SOURCE_DIR}/" "${BACKUP_PATH}/" 2>/dev/null || \
        cp -a "$SOURCE_DIR" "$BACKUP_PATH"
fi

log "备份完成: $BACKUP_PATH"

cd "$BACKUP_DIR" || exit 1
backup_count=$(ls -d backup_* 2>/dev/null | wc -l)

if [[ "$backup_count" -gt "$MAX_BACKUPS" ]]; then
    oldest=$((backup_count - MAX_BACKUPS))
    ls -dt backup_* | tail -n "$oldest" | xargs -r rm -rf
    log "清理旧备份: 删除 $oldest 个"
fi

ls -la "$BACKUP_DIR" | tail -n 5