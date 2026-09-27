#!/bin/bash

# while loop 
#while (条件)
#do
#	代码块
#done



#死循环

#while  true
#do
#	printf "hello while \n"
#done

#echo  "第一个值" $1
#yd="$1"
#######################################
#read  -p  "请输入开始s" yd
#if [ ! -z ${yd} ];then
#
#	while  ${yd} true
#	do
#		printf  "hello start"
#	done
#fi
########################################


#a=true

#while  $a
#do
#	echo  "hello world"
#done




read  -p  "请输入开始s" yd
while [ ! -z ${yd} ]
do
        printf  "hello start"
done











