#!/bin/bash

# MongoDB管理工具

set -euo pipefail

MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_USER=""
MONGO_PASS=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    status                    查看状态
    list                     列出数据库
    collections <db>         列出集合
    size <db>                 查看大小
    create <db>               创建数据库
    drop <db>                 删除数据库
    backup <db> [path]      备份
    restore <path> <db>     恢复
    user-add <db> <user> <pass> 添加用户

示例:
    $(basename $0) list
    $(basename $0) collections mydb
    $(basename $0) backup mydb /backup
EOF
    exit 1
}

has_mongo() {
    command -v mongo >/dev/null 2>&1 || command -v mongodump >/dev/null 2>&1
}

mongo_exec() {
    local db="$1"
    local cmd="$2"
    
    if [[ -n "$MONGO_USER" ]]; then
        mongo -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase "$db" "$db" --quiet --eval "$cmd" 2>/dev/null
    else
        mongo "$db" --quiet --eval "$cmd" 2>/dev/null
    fi
}

db_status() {
    echo "=== MongoDB状态 ==="
    mongo_exec "admin" "db.serverStatus()"
}

list_databases() {
    echo "=== 数据库列表 ==="
    mongo_exec "admin" "db.adminCommand('listDatabases').databases.forEach(function(d){print(d.name+' '+d.sizeOnDisk/1024/1024+'MB')})"
}

list_collections() {
    local db="$1"
    echo "=== $db 集合 ==="
    mongo_exec "$db" "db.getCollectionNames().forEach(function(c){print(c)})"
}

db_size() {
    local db="$1"
    echo "=== $db 大小 ==="
    mongo_exec "$db" "var stats=db.stats();print('数据: '+stats.dataSize/1024/1024+'MB 索引: '+stats.indexSize/1024/1024+'MB')"
}

create_database() {
    local db="$1"
    mongo_exec "$db" "db.createCollection('init');"
    echo "数据库已创建: $db"
}

drop_database() {
    local db="$1"
    mongo_exec "$db" "db.dropDatabase();"
    echo "数据库已删除: $db"
}

backup_database() {
    local db="$1"
    local path="${2:-.}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$path"
    
    local opts="-d $db -o $path"
    [[ -n "$MONGO_USER" ]] && opts="-u $MONGO_USER -p $MONGO_PASS $opts"
    
    mongodump $opts 2>/dev/null
    
    tar -czf "${path}/${db}_${timestamp}.tar.gz" -C "$path" .
    rm -rf "$path"/"$db"
    
    echo "备份完成: ${path}/${db}_${timestamp}.tar.gz"
}

restore_database() {
    local path="$1"
    local db="$2"
    
    local opts="-d $db"
    [[ -n "$MONGO_USER" ]] && opts="-u $MONGO_USER -p $MONGO_PASS $opts"
    
    tar -xzf "$path" -C /tmp
    mongorestore $opts /tmp/"$db" 2>/dev/null
    
    echo "恢复完成: $db"
}

add_user() {
    local db="$1"
    local user="$2"
    local pass="$3"
    
    mongo_exec "$db" "db.createUser({user:'$user', pwd:'$pass', roles:['readWrite']})"
    echo "用户已创建: $user"
}

case "${1:-}" in
    status)
        db_status
        ;;
    list)
        list_databases
        ;;
    collections)
        list_collections "$2"
        ;;
    size)
        db_size "$2"
        ;;
    create)
        create_database "$2"
        ;;
    drop)
        drop_database "$2"
        ;;
    backup)
        backup_database "$2" "${3:-.}"
        ;;
    restore)
        restore_database "$2" "$3"
        ;;
    user-add)
        add_user "$2" "$3" "$4"
        ;;
    *)
        usage
        ;;
esac