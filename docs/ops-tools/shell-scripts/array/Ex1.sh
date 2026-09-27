#!/bin/bash

array1=("xiaobai" "xiaohei" "xiaohuang" "lisi")

echo ${array1[0]}
echo ${array1[1]}
echo ${array1[2]}
echo ${array1[3]}
echo ${array1[4]}

echo ${array1[@]}
echo ${#array1[@]}

# 获取数组中元素的个数
echo ${#array1[@]}

# 获取数组中某个元素的长度
#
echo ${#array1[0]}

array1[0]="xiaoxiao"

echo ${array1[@]}

