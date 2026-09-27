#!/bin/bash

#检查有没有源

[ ! -f  /etc/yum.repos.d/local.repo ]  &&  touch /etc/yum.repos.d/local.repo 

#检查本地是否镜像以挂载

[ ! -e /mnt/Packages ]  &&  echo "需要挂载本地的ISO文件"

#yum 是否可用


#config_path=/etc/yum.repos.d/
[ -z ${config_path} ]  &&  config_path=/etc/yum.repos.d/ || echo  "不为空"
echo  ${config_path}
