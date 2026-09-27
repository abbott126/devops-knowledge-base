#!/bin/bash

# SSH密钥批量管理工具

set -euo pipefail

SSH_DIR="${HOME}/.ssh"
KEY_TYPE="${1:-ed25519}"
KEY_LENGTH="${2:-4096}"

usage() {
    cat << EOF
用法: $(basename $0) [密钥类型] [密钥长度]

密钥类型: rsa, ed25519, ecdsa
密钥长度: 2048, 4096, 8192

示例:
    $(basename $0) ed25519
    $(basename $0) rsa 4096
EOF
    exit 1
}

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

generate_key() {
    local name="$1"
    local type="$2"
    local bits="$3"
    
    local key_file="$SSH_DIR/${name}"
    
    if [[ -f "$key_file" ]]; then
        read -p "密钥已存在，是否覆盖? [y/N] " confirm
        [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]] && return 1
    fi
    
    case "$type" in
        rsa)
            ssh-keygen -t rsa -b "$bits" -f "$key_file" -N "" -C "${name}@$(hostname)"
            ;;
        ed25519)
            ssh-keygen -t ed25519 -f "$key_file" -N "" -C "${name}@$(hostname)"
            ;;
        ecdsa)
            ssh-keygen -t ecdsa -b "$bits" -f "$key_file" -N "" -C "${name}@$(hostname)"
            ;;
    esac
    
    chmod 600 "$key_file"
    [[ -f "${key_file}.pub" ]] && chmod 644 "${key_file}.pub"
    
    echo "密钥生成完成: $key_file"
}

list_keys() {
    echo "=== SSH密钥列表 ==="
    
    for key in "$SSH_DIR"/*.pub; do
        [[ -f "$key" ]] || continue
        name=$(basename "$key" .pub)
        fingerprint=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}' || echo "N/A")
        echo "$name: $fingerprint"
    done
}

deploy_key() {
    local key_name="$1"
    local host="$2"
    local port="${3:-22}"
    local user="${4:-root}"
    
    local key_file="$SSH_DIR/${key_name}"
    
    [[ ! -f "$key_file" ]] && echo "密钥不存在: $key_name" && exit 1
    [[ ! -f "${key_file}.pub" ]] && echo "公钥不存在" && exit 1
    
    pub_key=$(cat "${key_file}.pub")
    
    ssh -o StrictHostKeyChecking=no -p "$port" \
        "$user@$host" "echo '$pub_key' >> ~/.ssh/authorized_keys" 2>/dev/null || \
        ssh -o StrictHostKeyChecking=no -p "$port" \
            "$user@$host" "mkdir -p ~/.ssh && echo '$pub_key' >> ~/.ssh/authorized_keys"
    
    echo "密钥已部署到 $user@$host:$port"
}

revoke_key() {
    local key_name="$1"
    local host="$2"
    local port="${3:-22}"
    local user="${4:-root}"
    
    local key_file="$SSH_DIR/${key_name}"
    
    [[ ! -f "$key_file.pub" ]] && echo "公钥不存在" && exit 1
    
    pub_key=$(cat "${key_file}.pub")
    
    ssh -p "$port" "$user@$host" \
        "sed -i '/${pub_key//\//\\&}/d' ~/.ssh/authorized_keys" 2>/dev/null || \
        echo "连接失败或公钥不存在"
    
    echo "密钥已从 $user@$host 撤销"
}

case "${1:-}" in
    gen)
        generate_key "${2:-default}" "${3:-${KEY_TYPE}}" "${4:-${KEY_LENGTH}}"
        ;;
    list)
        list_keys
        ;;
    deploy)
        deploy_key "$2" "$3" "${4:-22}" "${5:-root}"
        ;;
    revoke)
        revoke_key "$2" "$3" "${4:-22}" "${5:-root}"
        ;;
    *)
        cat << EOF
SSH密钥管理工具

用法: $(basename $0) <命令> [参数]

命令:
    gen <名称> [类型] [长度]     ���成新密钥
    list                        列出已有密钥
    deploy <密钥名> <主机> [端口] [用户]  部署密钥
    revoke <密钥名> <主机> [端口] [用户]  撤销密钥

示例:
    $(basename $0) gen mykey ed25519
    $(basename $0) list
    $(basename $0) deploy mykey 192.168.1.100 22 root
    $(basename $0) revoke mykey 192.168.1.100 22 root
EOF
        ;;
esac