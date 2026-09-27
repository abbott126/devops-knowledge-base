#!/bin/bash

#1. 检查有没有有没有此服务
#2. 准备安装服务 
#3. 源 --> 网络源 & 本地源
#4. 安装服务
#5. 基本配置修改监听地址
#6. 修改首页
#7. 启动服务
#8. 防火墙设置
#9. Selinux 设置


#1. 检查有没有此服务
#1.1 检查端口是否存在
#1.2 检查有没有此服务（yum）

prot=`sudo  ss -luntp | grep httpd | awk  '{print $5}' |awk  -F: '{print $2}'`
RepoPath="/etc/yum.repos.d"



if [ -z ${prot} ];then
	echo "端口没有找到；正在查询关于配置文件，确定有没有此服务"
fi

echo "1"
if  [ ! -e /etc/httpd ];then
	echo  "配置文件没有"
fi

#2. 准备安装服务

if  [ -f ${RepoPath}/local.repo ];then
    echo  "有yum 源"

else
cat > ${RepoPath}/local.repo <<EOF
[local]
name=redhat local repo
baseurl=file:///mnt
gpgcheck=0
EOF
fi 


if  [ -d /mnt/Packages ];then
	echo "有"
else
    echo  "正在挂载"
    if  [ -b /dev/sr0 ];then 
	mount  /dev/sr0 /mnt
	if [ ! $? -eq 0 ];then
           exit 1
	fi 
    fi
fi 


# test yum 

yum repolist 

if [ ! $? -eq 0 ];then
echo  "执行失败"
exit 1
fi


yum -y  install  httpd

if  [ ! $? -eq 0 ];then
 echo  "执行失败"
fi 


#修改配置文件
sed -i  's/^Listen 80/Listen 0.0.0.0:80/g' /etc/httpd/conf/httpd.conf
#启动服务
systemctl  start httpd
#检查端口
ss -luntp | grep 80

#add firewalld
firewall-cmd --add-port=80/tcp



#modify page 

cat  >  /var/www/html/index.html  <<EOF
<h1>hello world</h1>
EOF
