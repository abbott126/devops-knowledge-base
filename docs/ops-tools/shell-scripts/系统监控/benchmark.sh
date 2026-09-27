#!/bin/bash

# 服务性能基准测试工具

set -euo pipefail

ITERATIONS="${ITERATIONS:-10}"
CONCURRENT="${CONCURRENT:-1}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [参数]

命令:
    cpu                      CPU基准测试
    mem                      内存基准测试
    disk [path]               磁盘IO测试
    network [port]            网络延迟测试
    mysql [host] [user]      MySQL性能测试
    redis [host]             Redis性能测试
    full                    完整基准测试

示例:
    $(basename $0) cpu
    $(basename $0) disk /data
    $(basename $0) full
EOF
    exit 1
}

benchmark_cpu() {
    echo "=== CPU基准测试 ==="
    
    local start end duration
    start=$(date +%s%N)
    
    for ((i=0; i<ITERATIONS; i++)); do
        math=0
        for ((j=0; j<10000; j++)); do
            math=$((math + i * j / (i + 1)))
        done
    done
    
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    
    echo "执行时间: ${duration}ms"
    echo "迭代次数: $ITERATIONS"
    echo "平均: $((duration / ITERATIONS))ms/次"
}

benchmark_memory() {
    echo "=== 内存基准测试 ==="
    
    local size=$((100 * 1024 * 1024))
    local start end duration
    
    start=$(date +%s%N)
    
    for ((i=0; i<ITERATIONS; i++)); do
        dd if=/dev/zero bs=1M count=100 2>/dev/null | md5sum >/dev/null
    done
    
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    
    local total=$((size * ITERATIONS / 1024 / 1024))
    echo "总写入: ${total}MB"
    echo "执行时间: ${duration}ms"
    echo "速度: $((total * 1000 / duration))MB/s"
}

benchmark_disk() {
    local path="${1:-/tmp}"
    local size=10
    local start end duration
    
    echo "=== 磁盘IO测试 ==="
    echo "路径: $path"
    
    start=$(date +%s%N)
    
    for ((i=0; i<ITERATIONS; i++)); do
        dd if=/dev/zero of="${path}/test_${i}" bs=1M count="$size" 2>/dev/null
    done
    
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    
    local total=$((size * ITERATIONS))
    echo "总写入: ${total}MB"
    echo "写速度: $((total * 1000 / duration))MB/s"
    
    start=$(date +%s%N)
    for ((i=0; i<ITERATIONS; i++)); do
        cat "${path}/test_${i}" >/dev/null
    done
    
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    echo "读速度: $((total * 1000 / duration))MB/s"
    
    rm -f "${path}"/test_*
}

benchmark_network() {
    local host="${1:-localhost}"
    local port="${2:-80}"
    local times=10
    
    echo "=== 网络延迟测试 ==="
    echo "目标: $host:$port"
    
    for ((i=0; i<times; i++)); do
        timeout 1 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null && \
            echo "连接: 成功" || echo "连接: 失败"
    done
}

benchmark_mysql() {
    local host="${1:-localhost}"
    local user="${2:-root}"
    
    echo "=== MySQL性能测试 ==="
    echo "连接: $user@$host"
    
    command -v mysql >/dev/null 2>&1 || echo "MySQL客户端未安装" || return
    
    local start end duration
    
    start=$(date +%s%N)
    for ((i=0; i<ITERATIONS; i++)); do
        mysql -h "$host" -u "$user" -e "SELECT 1" 2>/dev/null
    done
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    
    echo "执行时间: ${duration}ms"
    echo "平均: $((duration / ITERATIONS))ms/次"
}

benchmark_redis() {
    local host="${1:-localhost}"
    
    echo "=== Redis性能测试 ==="
    echo "连接: $host"
    
    command -v redis-cli >/dev/null 2>&1 || echo "Redis客户端未安装" || return
    
    local start end duration
    
    start=$(date +%s%N)
    for ((i=0; i<ITERATIONS; i++)); do
        redis-cli -h "$host" PING 2>/dev/null
    done
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    
    echo "执行时间: ${duration}ms"
    echo "QPS: $((ITERATIONS * 1000 / duration))"
}

full_benchmark() {
    echo "=== 完整基准测试 ==="
    echo "迭代: $ITERATIONS"
    echo ""
    
    echo "--- CPU ---"
    benchmark_cpu
    echo ""
    
    echo "--- Memory ---"
    benchmark_memory
    echo ""
    
    echo "--- Disk IO ---"
    benchmark_disk /tmp
}

case "${1:-}" in
    cpu)
        benchmark_cpu
        ;;
    mem)
        benchmark_memory
        ;;
    disk)
        benchmark_disk "${2:-/tmp}"
        ;;
    network)
        benchmark_network "${2:-localhost}" "${3:-80}"
        ;;
    mysql)
        benchmark_mysql "${2:-localhost}" "${3:-root}"
        ;;
    redis)
        benchmark_redis "${2:-localhost}"
        ;;
    full)
        full_benchmark
        ;;
    *)
        usage
        ;;
esac