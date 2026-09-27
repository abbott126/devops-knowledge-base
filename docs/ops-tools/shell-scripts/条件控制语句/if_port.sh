#!/bin/bash

# 检测httpd service
#

#判断是否使用YUM install httpd
if  [ -d  /etc/httpd ];then
	echo "使用YUM安装服务"
elif [ -d /usr/local/httpd ];then
	echo  "使用源码安装"
else
    echo "未安装服务"
fi


#判断服务是否在运行

#1. 判断端口
#2. 获取服务状态

prot=`sudo  ss -luntp | grep httpd | awk  '{print $5}' |awk  -F: '{print $2}'`

if [ -z ${prot} ];then
	echo "正在启动服务... 请稍等"
	systemctl  start httpd
else
	echo  "服务正在运行"
fi
