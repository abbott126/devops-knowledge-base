#!/bin/bash

# JSON数据处理工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    get <json> <path>           获取值
    set <json> <path> <value>  设置值
    keys <json>                 列出所有key
    values <json>               列出所有value
    has <json> <key>           检查key存在
    del <json> <path>          删除字段
    merge <json1> <json2>      合并JSON
    pretty <json>               格式化输出
    compact <json>             压缩输出

示例:
    $(basename $0) get data.json "user.name"
    $(basename $0) keys config.json
EOF
    exit 1
}

has_python_json() {
    python3 -c "import json" 2>/dev/null
}

get_value() {
    local json_file="$1"
    local path="$2"
    
    if has_python_json; then
        python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
path = '$path'.split('.')
obj = data
for p in path:
    if p:
        obj = obj.get(p, {})
print(obj)
"
    else
        echo "需要Python3"
        exit 1
    fi
}

set_value() {
    local json_file="$1"
    local path="$2"
    local value="$3"
    
    if has_python_json; then
        python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
path = '$path'.split('.')
obj = data
for p in path[:-1]:
    if p:
        obj = obj.setdefault(p, {})
obj[path[-1]] = $value
print(json.dumps(data, indent=2))
"
    fi
}

list_keys() {
    local json_file="$1"
    
    if has_python_json; then
        python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
def get_keys(d, prefix=''):
    if isinstance(d, dict):
        for k, v in d.items():
            print(prefix + k)
            if isinstance(v, dict):
                get_keys(v, prefix + k + '.')
    elif isinstance(d, list):
        pass
get_keys(data)
"
    fi
}

list_values() {
    local json_file="$1"
    
    if has_python_json; then
        python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
def get_values(d):
    if isinstance(d, dict):
        for k, v in d.items():
            get_values(v)
    elif isinstance(d, list):
        for v in d:
            get_values(v)
    else:
        print(d)
get_values(data)
"
    fi
}

check_key() {
    local json_file="$1"
    local key="$2"
    
    if has_python_json; then
        python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
result = '$key' in data
sys.exit(0 if result else 1)
" && echo "存在" || echo "不存在"
    fi
}

delete_key() {
    local json_file="$1"
    local path="$2"
    
    if has_python_json; then
        python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
path = '$path'.split('.')
obj = data
for p in path[:-1]:
    obj = obj.get(p, {})
del obj[path[-1]]
print(json.dumps(data, indent=2))
"
    fi
}

merge_json() {
    local file1="$1"
    local file2="$2"
    
    if has_python_json; then
        python3 -c "
import json
with open('$file1') as f:
    data1 = json.load(f)
with open('$file2') as f:
    data2 = json.load(f)
data1.update(data2)
print(json.dumps(data1, indent=2))
"
    fi
}

pretty_print() {
    local json_file="$1"
    
    if has_python_json; then
        python3 -m json.tool "$json_file"
    fi
}

compact_print() {
    local json_file="$1"
    
    if has_python_json; then
        python3 -c "import json; print(json.dumps(json.load(open('$json_file'))))"
    fi
}

case "${1:-}" in
    get)
        get_value "$2" "$3"
        ;;
    set)
        set_value "$2" "$3" "$4"
        ;;
    keys)
        list_keys "$2"
        ;;
    values)
        list_values "$2"
        ;;
    has)
        check_key "$2" "$3"
        ;;
    del)
        delete_key "$2" "$3"
        ;;
    merge)
        merge_json "$2" "$3"
        ;;
    pretty)
        pretty_print "$2"
        ;;
    compact)
        compact_print "$2"
        ;;
    *)
        usage
        ;;
esac