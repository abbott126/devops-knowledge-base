#!/bin/bash

url="https://www.sunshijz.cn"
printf "个人blog地址为%s\n" $url


#定义install PATH 


#mysql_path=
#MysqlPath=



#定义变量重复性修改变量的的值
MysqlPath=/usr/local/mysql
printf "mysql 的安装目录%s \n" $MysqlPath

MysqlPath=/usr/local/mysql8


#定义只读变量
readonly  MysqlPath=/usr/local/mysql
printf "mysql 的安装目录%s \n" $MysqlPath

MysqlPath=/usr/local/mysql8

printf "mysql 的安装目录%s \n" $MysqlPath


