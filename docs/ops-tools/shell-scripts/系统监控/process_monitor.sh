#!/bin/bash

# 进程监控和告警工具

set -euo pipefail

CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
MAX_CPU="${MAX_CPU:-80}"
MAX_MEM="${MAX_MEM:-80}"
ALERT_SCRIPT=""

usage() {
    cat << EOF
用法: $(basename $0) [选项]

选项:
    -p, --process <name>       监控进程名
    -c, --cpu <percent>       CPU告警阈值(默认80%)
    -m, --mem <percent>       内存告警阈值(默认80%)
    -i, --interval <sec>      检查间隔(默认60秒)
    -a, --alert <script>     告警脚本
    -h, --help             显示帮助

示例:
    $(basename $0) -p nginx -c 70 -m 90
    $(basename $0) -p java -i 30 -a /path/to/alert.sh
EOF
    exit 1
}

PROCESS_NAME=""
ALERT_SCRIPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--process)
            PROCESS_NAME="$2"
            shift 2
            ;;
        -c|--cpu)
            MAX_CPU="$2"
            shift 2
            ;;
        -m|--mem)
            MAX_MEM="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -a|--alert)
            ALERT_SCRIPT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            usage
            ;;
    esac
done

[[ -z "$PROCESS_NAME" ]] && usage

alert() {
    local message="$1"
    echo "[$(date)] $message"
    
    if [[ -n "$ALERT_SCRIPT" ]] && [[ -x "$ALERT_SCRIPT" ]]; then
        "$ALERT_SCRIPT" "$message"
    fi
    
    [[ -w /var/log ]] && echo "[$(date)] $message" >> /var/log/process_alert.log
}

check_process() {
    local pids
    pids=$(pgrep -f "$PROCESS_NAME")
    
    if [[ -z "$pids" ]]; then
        alert "进程未运行: $PROCESS_NAME"
        return 1
    fi
    
    for pid in $pids; do
        local cpu mem
        cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null || echo 0)
        mem=$(ps -p "$pid" -o %mem= 2>/dev/null || echo 0)
        
        cpu=${cpu%.*} 
        mem=${mem%.*}
        
        if [[ $cpu -gt $MAX_CPU ]]; then
            alert "CPU过高: $PROCESS_NAME (PID:$pid) CPU=${cpu}%"
        fi
        
        if [[ $mem -gt $MAX_MEM ]]; then
            alert "内存过高: $PROCESS_NAME (PID:$pid) MEM=${mem}%"
        fi
    done
}

monitor_loop() {
    echo "开始监控进程: $PROCESS_NAME"
    echo "CPU阈值: ${MAX_CPU}% | 内存阈值: ${MAX_MEM}% | 间隔: ${CHECK_INTERVAL}秒"
    echo ""
    
    while true; do
        check_process
        sleep "$CHECK_INTERVAL"
    done
}

case "${1:-monitor}" in
    monitor)
        monitor_loop
        ;;
    check)
        check_process
        ;;
    list)
        pgrep -f "$PROCESS_NAME" | while read -r pid; do
            ps -p "$pid" -o pid,ppid,%cpu,%mem,etime,cmd
        done
        ;;
    *)
        usage
        ;;
esac