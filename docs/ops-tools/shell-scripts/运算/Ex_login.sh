#!/bin/bash
UserName="abbott"
Password="123456"

successful=`echo -e "\x1b[32;1m successful \x1b[0m"`

error=`echo -e "\x1b[31;1m error \x1b[0m"`




read -p "请输入用户名:" user
read -p "请输入密码:"   pass

#[ $UserName ==  $user ] && echo  "用户名正确 ${successful}" || echo  "用户名输入错误!!!请重试 ${error}"
#[ $Password ==  $pass ] && echo  "密码输入正确 ${successful}"  || echo  "密码输入错误！！！！${error}"



#and  or  ! 

#[ 用户 ] and [密码]   两者条件都为真；
#[ 用户 ] or  [密码]   两者条件都为真；


[ ${UserName} ==  ${user}  -a  $Password ==  $pass ] && echo  ${successful}  || echo ${error}
[ ${UserName} ==  ${user}  -o  $Password ==  $pass ] && echo  ${successful}  || echo ${error}


