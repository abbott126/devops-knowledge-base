#!/bin/bash

# CSV数据处理工具

set -euo pipefail

INPUT_FILE=""
OUTPUT_FILE=""
DELIMITER=","
QUOTE='"'

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    head <file> [n]              显示前n行
    tail <file> [n]               显示后n行
    stats <file>                  统计信息
    filter <file> <col> <value>  过滤数据
    sort <file> <col> [order]    排序
    join <file1> <file2> <col>   合并两个CSV
    transpose <file>             转置行列
    sum <file> <col>             求和列
    avg <file> <col>             平均列
    unique <file> <col>          去重
    split <file> [n]             分割文件

示例:
    $(basename $0) head data.csv 10
    $(basename $0) filter data.csv 3 "active"
    $(basename $0) sort data.csv 1 desc
EOF
    exit 1
}

get_col() {
    local file="$1"
    local col="$2"
    
    awk -F"$DELIMITER" -v col="$col" 'NR==1 {print $col; exit}BEGIN{FS="'$DELIMITER'"}' "$file"
}

show_head() {
    local file="$1"
    local n="${2:-10}"
    
    head -n "$n" "$file"
}

show_tail() {
    local file="$1"
    local n="${2:-10}"
    
    tail -n "$n" "$file"
}

show_stats() {
    local file="$1"
    
    echo "=== CSV统计 ==="
    echo "行数: $(wc -l < "$file")"
    echo "列数: $(head -1 "$file" | awk -F"$DELIMITER" '{print NF}')"
    echo "文件大小: $(du -h "$file" | cut -f1)"
    echo ""
    echo "列名:"
    head -1 "$file" | tr "$DELIMITER" '\n' | nl
}

filter_data() {
    local file="$1"
    local col="$2"
    local value="$3"
    local output="${4:-}"
    
    local cmd="awk -F'$DELIMITER' -v col=$col -v value='$value' '\$$col == value'"
    
    if [[ -n "$output" ]]; then
        eval "$cmd" "$file" > "$output"
    else
        eval "$cmd" "$file"
    fi
}

sort_data() {
    local file="$1"
    local col="$2"
    local order="${3:-asc}"
    
    local sort_flag="-n"
    [[ "$order" == "desc" ]] && sort_flag="-rn"
    
    sort -t"$DELIMITER" -k"$col$sort_flag" "$file"
}

join_files() {
    local file1="$1"
    local file2="$2"
    local col="$3"
    
    join -t"$DELIMITER" -1 "$col" -2 "$col" "$file1" "$file2"
}

transpose_data() {
    local file="$1"
    
    awk -F"$DELIMITER" '{
        for (i=1;i<=NF;i++) a[NR,i]=$i
        max=(max<NF?NF:max)
    } END {
        for (j=1;j<=max;j++) {
            line=""
            for (i=1;i<=NR;i++) {
                line=line (i==1?"":FS) a[i,j]
            }
            print line
        }
    }' "$file"
}

sum_col() {
    local file="$1"
    local col="$2"
    
    awk -F"$DELIMITER" -v col="$col" '{
        sum+=$(col)
    } END {
        print sum
    }' "$file"
}

avg_col() {
    local file="$1"
    local col="$2"
    
    awk -F"$DELIMITER" -v col="$col" '{
        sum+=$(col); count++
    } END {
        print sum/count
    }' "$file"
}

unique_col() {
    local file="$1"
    local col="$2"
    
    cut -d"$DELIMITER" -f"$col" "$file" | sort -u
}

split_file() {
    local file="$1"
    local n="${2:-1000}"
    local prefix="${3:-split}"
    
    split -l "$n" -d -a 3 "$file" "${prefix}_"
    
    ls -la "${prefix}_"*
}

case "${1:-}" in
    head)
        show_head "$2" "${3:-10}"
        ;;
    tail)
        show_tail "$2" "${3:-10}"
        ;;
    stats)
        show_stats "$2"
        ;;
    filter)
        filter_data "$2" "$3" "$4" "${5:-}"
        ;;
    sort)
        sort_data "$2" "$3" "${4:-asc}"
        ;;
    join)
        join_files "$2" "$3" "$4"
        ;;
    transpose)
        transpose_data "$2"
        ;;
    sum)
        sum_col "$2" "$3"
        ;;
    avg)
        avg_col "$2" "$3"
        ;;
    unique)
        unique_col "$2" "$3"
        ;;
    split)
        split_file "$2" "${3:-1000}" "${4:-}"
        ;;
    *)
        usage
        ;;
esac