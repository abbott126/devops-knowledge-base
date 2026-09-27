#!/bin/bash

#查看系统信息

while true
do
	echo  "#########system info#############"
	echo  "1. 查看系统版本"
	echo  "2. 查看IP地址"
	echo  "3. 查看内存"
	echo  "4. 查看磁盘"
	echo  "5. 退出"
	echo  "#########system info#############"


	read -p  "请输入数字[1-5]:" num

	case ${num} in
		1)
		hostnamectl
		;;
		2)
		ip addr
		;;
		3)
		free -h
		;;
		4)
		df -h 
		;;
		5)
		exit 1
		;;
		*)
		echo "请按照提示输入!!!!"
		;;
	esac
done
