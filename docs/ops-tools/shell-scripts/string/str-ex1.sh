#!/bin/bash

#双引号和单引号

a="abc"
b='abc'

c='a\\*bc'
d="a\\*bc"

echo  -e   ${a} ${b} ${c} ${d}
printf  ${a} ${b} ${c} ${d}

# 


str1='i'
str2='love'
str3='you'
echo $str1 $str2 $str3
echo $str1$str2$str3
echo $str1,$str2,$str3


#read -p "你叫什么？" name
#read -p  "你几岁?" age
#read -p  "你爱好什么?" a

#echo  "我叫:$name年龄:$age 爱好:$a"

#echo "name值的长度为：${#name}"


str='1 2 3 4 5 6'
echo ${str:1} # 从第1个截取到末尾。注意从0开始。
echo ${str:2:3} # 从第2个截取2个。
echo ${str:0} # 全部截取
echo ${str:1:1}



str="i love you"
echo `expr index "$str" l`
echo `expr index "$str" love` 
echo `expr index "$str" o`
echo `expr length "$str"`
echo `expr substr "$str" 1 6`

