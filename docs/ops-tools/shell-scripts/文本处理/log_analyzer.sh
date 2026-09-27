#!/bin/bash

# 日志分析工具

set -euo pipefail

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    error <log>              查看错误日志
    warn <log>               查看警告日志  
    ip <log>                 提取IP地址统计
    request <log>             请求统计
    response <log>            响应时间统计
    ua <log>                 User-Agent统计
    status <log>             HTTP状态码统计
    top <log> [n]            请求量Top N
    timeline <log>           时间线分析

示例:
    $(basename $0) error access.log
    $(basename $0) ip access.log
    $(basename $0) top access.log 20
EOF
    exit 1
}

extract_errors() {
    local log="$1"
    
    grep -i "error\|exception\|fail" "$log" | \
        grep -v "404\|500" | \
        tail -50
}

extract_warnings() {
    local log="$1"
    
    grep -i "warn\|warning" "$log" | tail -50
}

extract_ips() {
    local log="$1"
    
    awk '{print $1}' "$log" | \
        sort | uniq -c | sort -rn | head -20
}

request_stats() {
    local log="$1"
    
    echo "=== 请求统计 ==="
    echo "总请求数: $(wc -l < "$log")"
    echo "独立IP数: $(awk '{print $1}' "$log" | sort -u | wc -l)"
    echo ""
    echo "请求方法:"
    awk -F'"' '{print $2}' "$log" | cut -d' ' -f1 | sort | uniq -c | sort -rn
    echo ""
    echo "请求URL Top 10:"
    awk -F'"' '{print $2}' "$log" | cut -d' ' -f2 | sort | uniq -c | sort -rn | head -10
}

response_time_stats() {
    local log="$1"
    
    echo "=== 响应时间统计 ==="
    
    awk -F'"' '{print $(NF-1)}' "$log" | \
        awk '{print $NF}' | \
        grep -oE '[0-9.]+' | \
        awk '{
            sum+=$1; count++; 
            if($1>max) max=$1; 
            if($1<min || min=="") min=$1
        } END {
            print "请求数: " count
            print "平均: " sum/count "ms"
            print "最大: " max "ms"
            print "最小: " min "ms"
        }'
}

user_agent_stats() {
    local log="$1"
    
    echo "=== User-Agent统计 ==="
    grep -oE '"Mozilla/[^"]*"' "$log" | \
        sort | uniq -c | sort -rn | head -15
}

status_code_stats() {
    local log="$1"
    
    echo "=== HTTP状态码统计 ==="
    awk -F'"' '{print $2}' "$log" | \
        awk '{print $1}' | sort | uniq -c | sort -rn
}

top_requests() {
    local log="$1"
    local n="${2:-10}"
    
    echo "=== 请求量 Top $n ==="
    awk '{print $1}' "$log" | \
        sort | uniq -c | sort -rn | head -"$n"
}

timeline_analysis() {
    local log="$1"
    
    echo "=== 时间线分析 ==="
    
    awk '{print $4}' "$log" | \
        sed 's/\[//;s/\]//' | \
        sed 's/\// /g' | \
        awk '{print $2 " " $3}' | \
        sort | uniq -c | head -24
}

case "${1:-}" in
    error)
        extract_errors "$2"
        ;;
    warn)
        extract_warnings "$2"
        ;;
    ip)
        extract_ips "$2"
        ;;
    request)
        request_stats "$2"
        ;;
    response)
        response_time_stats "$2"
        ;;
    ua)
        user_agent_stats "$2"
        ;;
    status)
        status_code_stats "$2"
        ;;
    top)
        top_requests "$2" "${3:-10}"
        ;;
    timeline)
        timeline_analysis "$2"
        ;;
    *)
        usage
        ;;
esac