#!/bin/bash

# URL编码解码工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    encode <text>            URL编码
    decode <text>            URL解码
    base64-encode <text>    Base64编码
    base64-decode <text>    Base64解码
    hash <text>             哈希值
    uuid                    生成UUID

示例:
    $(basename $0) encode "hello world"
    $(basename $0) base64-encode "test"
EOF
    exit 1
}

url_encode() {
    local text="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('''$text'''))" 2>/dev/null || \
        echo "$text" | sed 's/ /%20/g;s/!/%21/g;s/"/%22/g'
}

url_decode() {
    local text="$1"
    python3 -c "import urllib.parse; print(urllib.parse.unquote('''$text'''))" 2>/dev/null || \
        echo "$text" | sed 's/%20/ /g'
}

base64_encode() {
    local text="$1"
    echo -n "$text" | base64
}

base64_decode() {
    local text="$1"
    echo "$text" | base64 -d
}

hash_text() {
    local text="$1"
    echo "=== $text ==="
    echo -n "$text" | md5sum
    echo -n "$text" | sha1sum
    echo -n "$text" | sha256sum
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    elif python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

case "${1:-}" in
    encode)
        url_encode "$2"
        ;;
    decode)
        url_decode "$2"
        ;;
    base64-encode)
        base64_encode "$2"
        ;;
    base64-decode)
        base64_decode "$2"
        ;;
    hash)
        hash_text "$2"
        ;;
    uuid)
        generate_uuid
        ;;
    *)
        usage
        ;;
esac