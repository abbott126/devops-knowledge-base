#!/bin/bash
# 死循环
#for ((;;))
#do
# 	echo  "hello for"
#done

UserName="abbott"
Password="123456"
successful=`echo -e "\x1b[32;1m successful \x1b[0m"`
error=`echo -e "\x1b[31;1m error \x1b[0m"`

for ((i=3;i>0;i--))
do
	echo  "你还有${i}机会"
	read -p "请输入用户名:" user
	if [ ${user} == ${UserName} ];then
		read -p "请输入密码:"   pass
		if  [ ${pass} == ${Password} ];then
			echo  "login ${successful}"
			break
		else
	  		echo "密码输入错误"
		fi
	else
   	   echo "用户名输入错误！！！ 请重试;"
	fi
done
