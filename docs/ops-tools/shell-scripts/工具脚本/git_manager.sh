#!/bin/bash

# Git仓库管理工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    init <dir>                初始化仓库
    clone <url> [dir]         克隆仓库
    branch [name]            管理分支
    tag <name> [msg]         管理标签
    log [n]                  查看提交日志
    stash                    管理暂存
    submodule                管理子模块
    cleanup                  清理仓库

示例:
    $(basename $0) branch feature
    $(basename $0) log 10
    $(basename $0) cleanup
EOF
    exit 1
}

has_git() {
    command -v git >/dev/null 2>&1
}

init_repo() {
    local dir="${1:-.}"
    mkdir -p "$dir"
    cd "$dir"
    git init
    git commit --allow-empty -m "Initial commit"
    echo "仓库已初始化: $dir"
}

clone_repo() {
    local url="$1"
    local dir="${2:-.}"
    git clone "$url" "$dir"
    echo "克隆完成: $dir"
}

manage_branch() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        git branch -a
    else
        git checkout -b "$name"
    fi
}

manage_tag() {
    local name="$1"
    local msg="${2:-}"
    
    git tag -a "$name" -m "$msg"
    echo "标签已创建: $name"
}

show_log() {
    local n="${1:-10}"
    git log --oneline --graph --decorate -n "$n"
}

manage_stash() {
    local action="${1:-}"
    
    case "$action" in
        save)
            git stash save "${2:-}"
            ;;
        pop)
            git stash pop
            ;;
        list)
            git stash list
            ;;
        drop)
            git stash drop
            ;;
        *)
            git stash list
            ;;
    esac
}

manage_submodule() {
    local action="$1"
    local url="$2"
    local path="${3:-}"
    
    case "$action" in
        add)
            git submodule add "$url" "$path"
            ;;
        update)
            git submodule update --init --recursive
            ;;
        status)
            git submodule status
            ;;
    esac
}

cleanup_repo() {
    echo "=== 仓库清理 ==="
    echo "1. 清理未跟踪文件"
    git clean -fd
    echo "2. 清理未合并的分支"
    git branch | grep -v "main\|master" | xargs -r git branch -d
    echo "3. 清理标签"
    git tag | xargs -r git tag -d
    echo "清理完成"
}

check_status() {
    echo "=== 仓库状态 ==="
    echo "分支: $(git branch --show-current)"
    echo "提交: $(git rev-parse --short HEAD)"
    echo "状态:"
    git status --short
}

case "${1:-}" in
    init)
        init_repo "$2"
        ;;
    clone)
        clone_repo "$2" "${3:-.}"
        ;;
    branch)
        manage_branch "$2"
        ;;
    tag)
        manage_tag "$2" "${3:-}"
        ;;
    log)
        show_log "${2:-10}"
        ;;
    stash)
        manage_stash "$2" "${3:-}"
        ;;
    submodule)
        manage_submodule "$2" "$3" "${4:-}"
        ;;
    cleanup)
        cleanup_repo
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac