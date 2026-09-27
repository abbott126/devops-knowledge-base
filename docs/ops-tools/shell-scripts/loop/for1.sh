#!/bin/bash

# 语法：
#for 变量名 in
#do
#	代码块
#done	


for i  in 1 2 3 4 5 
do
	echo  $i
done


# 数组
#
#name=("小黄" "小白" "小红" "小李")

#for n in ${name}
#do
#	echo ${n[0]}
#done





#循环判断IP地址

sub="192.168.1."

for  num in  {1..100}
do
	ping  -c 1  $sub${num} >  /dev/null
	if [  $? -eq 0 ];then
		echo  "${sub}${num}" >>  ip.txt
	fi
done










