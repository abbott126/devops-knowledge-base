#!/bin/bash

# API测试和文档生成工具

set -euo pipefail

API_BASE="${API_BASE:-}"
API_TOKEN=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    call <method> <path> [data]  调用API
    list                        列出可用端点
    gen-doc                     生成API文档
    auth <token>                设置认证token
    header <key> <value>       设置自定义头

示例:
    $(basename $0) call GET /users
    $(basename $0) call POST /users '{"name":"test"}'
EOF
    exit 1
}

has_jq() {
    command -v jq >/dev/null 2>&1
}

make_call() {
    local method="$1"
    local path="$2"
    local data="$3"
    
    local url="${API_BASE}${path}"
    
    local args=(-s -X "$method")
    [[ -n "$API_TOKEN" ]] && args+=(-H "Authorization: Bearer $API_TOKEN")
    [[ -n "$data" ]] && args+=(-H "Content-Type: application/json" -d "$data")
    
    local response
    response=$(curl "${args[@]}" "$url")
    
    if has_jq; then
        echo "$response" | jq .
    else
        echo "$response"
    fi
}

list_endpoints() {
    echo "=== API端点 ==="
    echo "GET    /api/users     - 用户列表"
    echo "GET    /api/users/:id - 用户详情"
    echo "POST   /api/users     - 创建用户"
    echo "PUT    /api/users/:id - 更新用户"
    echo "DELETE /api/users/:id - 删除用户"
}

generate_doc() {
    cat << 'EOF'
# API文档

## 认证
- Bearer Token: Authorization: Bearer <token>

## 端点

### 用户
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /api/users | 用户列表 |
| GET | /api/users/:id | 用户详情 |
| POST | /api/users | 创建用户 |
| PUT | /api/users/:id | 更新用户 |
| DELETE | /api/users/:id | 删除用户 |

### 示例
```bash
# 获取用户列表
curl -X GET /api/users

# 创建用户
curl -X POST /api/users -d '{"name":"test"}'
```
EOF
}

set_auth() {
    local token="$1"
    API_TOKEN="$token"
    echo "认证token已设置"
}

set_header() {
    local key="$1"
    local value="$2"
    echo "自定义头: $key=$value"
}

case "${1:-}" in
    call)
        make_call "$2" "$3" "${4:-}"
        ;;
    list)
        list_endpoints
        ;;
    gen-doc)
        generate_doc
        ;;
    auth)
        set_auth "$2"
        ;;
    header)
        set_header "$2" "$3"
        ;;
    *)
        usage
        ;;
esac