#!/bin/bash
echo  "查看磁盘的可用空间"

use_free=$(df -h  | grep home$  |awk '{print $4}')
printf "可用空间为%s \n" $use_free


echo  "查看内存的剩余容量"
Mem_free=$(free   -h  | grep  ^Me  |awk '{print $4}')
printf  "内存的可用空间: %s \n" $Mem_free 


read  -p "请输入你要查询的系统命令:" command
echo $command

a=`df`

echo ${a}

# 获取进程端口
#

http_prot=$(ss  -luntp | grep  80 | awk  -F: '{print $2}' | awk '{print $1}')

printf  "检测到端口http的为：%d \n" ${http_prot}

#echo  "type $a"
