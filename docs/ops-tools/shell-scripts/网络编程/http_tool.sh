#!/bin/bash

# HTTP请求工具

set -euo pipefail

DEFAULT_TIMEOUT=10

usage() {
    cat << EOF
用法: $(basename $0) <命令> [URL]

命令:
    get <url>                GET请求
    post <url> [data]        POST请求
    put <url> [data]         PUT请求
    delete <url>             DELETE请求
    head <url>               HEAD请求
    options <url>            OPTIONS请求
    download <url> <file>   下载文件
    upload <file> <url>     上传文件
    status <url>            检查状态码
    headers <url>            查看响应头

示例:
    $(basename $0) get https://api.github.com
    $(basename $0) post https://httpbin.org/post "name=test"
EOF
    exit 1
}

has_curl() {
    command -v curl >/dev/null 2>&1
}

http_get() {
    local url="$1"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m "$DEFAULT_TIMEOUT" "$url"
}

http_post() {
    local url="$1"
    local data="$2"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m "$DEFAULT_TIMEOUT" -X POST -d "$data" "$url"
}

http_put() {
    local url="$1"
    local data="$2"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m "$DEFAULT_TIMEOUT" -X PUT -d "$data" "$url"
}

http_delete() {
    local url="$1"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m "$DEFAULT_TIMEOUT" -X DELETE "$url"
}

http_head() {
    local url="$1"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m "$DEFAULT_TIMEOUT" -I "$url"
}

http_options() {
    local url="$1"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m "$DEFAULT_TIMEOUT" -X OPTIONS "$url"
}

download_file() {
    local url="$1"
    local output="$2"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -m 300 -o "$output" "$url"
    echo "下载完成: $output"
}

upload_file() {
    local file="$1"
    local url="$2"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -X POST -F "file=@$file" "$url"
}

check_status() {
    local url="$1"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -o /dev/null -w "%{http_code}" "$url"
}

show_headers() {
    local url="$1"
    has_curl || echo "curl未安装" && exit 1
    
    curl -s -I "$url"
}

case "${1:-}" in
    get)
        http_get "$2"
        ;;
    post)
        http_post "$2" "${3:-}"
        ;;
    put)
        http_put "$2" "${3:-}"
        ;;
    delete)
        http_delete "$2"
        ;;
    head)
        http_head "$2"
        ;;
    options)
        http_options "$2"
        ;;
    download)
        download_file "$2" "$3"
        ;;
    upload)
        upload_file "$2" "$3"
        ;;
    status)
        check_status "$2"
        ;;
    headers)
        show_headers "$2"
        ;;
    *)
        usage
        ;;
esac