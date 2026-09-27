#!/bin/bash

# 加密解密工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    encrypt <file> <pass>      加密文件
    decrypt <file> <pass>      解密文件
    hash <string>              字符串哈希
    salt-hash <string>        添加盐哈希
    random-pass [length]     生成随机密码
    random-str [length]      生成随机字符串

示例:
    $(basename $0) encrypt file.zip mypass
    $(basename $0) hash "password"
    $(basename $0) random-pass 16
EOF
    exit 1
}

encrypt_file() {
    local file="$1"
    local pass="$2"
    
    [[ ! -f "$file" ]] && echo "文件不存在" && return 1
    
    local output="${file}.enc"
    openssl enc -aes-256-cbc -salt -in "$file" -out "$output" -pass "pass:$pass"
    echo "已加密: $output"
}

decrypt_file() {
    local file="$1"
    local pass="$2"
    local output="${file%.enc}"
    
    openssl enc -aes-256-cbc -d -in "$file" -out "$output" -pass "pass:$pass" 2>/dev/null || \
        echo "解密失败"
    echo "已解密: $output"
}

hash_string() {
    local text="$1"
    echo "===哈希结果==="
    echo -n "$text" | md5sum | cut -d' ' -f1
    echo -n "$text" | sha1sum | cut -d' ' -f1
    echo -n "$text" | sha256sum | cut -d' ' -f1
}

salt_hash() {
    local text="$1"
    local salt
    salt=$(openssl rand -hex 8)
    echo "盐: $salt"
    echo -n "$text$salt" | sha256sum | cut -d' ' -f1
}

random_password() {
    local length="${1:-16}"
    openssl rand -base64 "$length" | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c "$length"
}

random_string() {
    local length="${1:-32}"
    openssl rand -hex "$length" | head -c "$length"
}

case "${1:-}" in
    encrypt)
        encrypt_file "$2" "$3"
        ;;
    decrypt)
        decrypt_file "$2" "$3"
        ;;
    hash)
        hash_string "$2"
        ;;
    salt-hash)
        salt_hash "$2"
        ;;
    random-pass)
        random_password "${2:-16}"
        ;;
    random-str)
        random_string "${2:-32}"
        ;;
    *)
        usage
        ;;
esac