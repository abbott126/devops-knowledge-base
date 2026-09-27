#!/bin/bash

while true
do
	echo "##################"
	echo  "1. install  httpd"
	echo  "2. manager httpd"
	echo "##################"

	read  -p  "请输入数字: "  num
	case ${num} in
		1)
		clear
			echo "##################"
			echo  "1. yum  httpd"
			echo  "2. 源码 httpd"
			echo "##################"
			read -p  "请选择安装方式:" i
			if  [ $i -eq 1 ];then
				yum -y install httpd
			else
				echo  "使用源码安装"
			fi
			;;
		2)
		clear
			echo  "######服务的管理#########"
			echo  "1. 启动服务"
			echo  "2. 停止服务"
			echo  "3. 重启服务"
			echo  "4. 返回到上一级菜单"
			echo  "##################"
			read -p "请输入按照菜单中的编号输入:" n
			if [ $n -eq 1 ];then
				echo  "start httpd"
			elif [ $n  -eq 2 ];then
				 echo "stop  service"
			elif [ $n  -eq 3 ];then
				echo  "restart serive"
			else
				echo "返回上级"
			fi
		;;
		*)
			echo  "抱歉!! 输入错误；请重试";;

	esac

done
