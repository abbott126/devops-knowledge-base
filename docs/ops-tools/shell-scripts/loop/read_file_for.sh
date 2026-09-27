#!/bin/bash

#n=0
#for i in `cat ip.txt` 
#do
#	((n++))
#	echo "第$n的次数的值:"  $i
#done

n=0
for i in `cat test` 
do
	((n++))
	if [ $i -eq  2 ];then
		#echo  "你个2溜子"
		#break #终止本次循环
		continue
	fi
	echo "第$n的次数的值:"  $i
done
