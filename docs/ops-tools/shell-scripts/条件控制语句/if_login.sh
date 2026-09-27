#!/bin/bash
UserName="abbott"
Password="123456"

successful=`echo -e "\x1b[32;1m successful \x1b[0m"`

error=`echo -e "\x1b[31;1m error \x1b[0m"`
read -p "请输入用户名:" user


if [ ${user} == ${UserName} ];then
	read -t 5 -s -p "请输入密码:"   pass

	if  [ ${pass} == ${Password} ];then
		echo  "login ${successful}"
	else
	  echo "密码输入错误"
	fi
else
   echo "用户名输入错误！！！ 请重试"
fi


