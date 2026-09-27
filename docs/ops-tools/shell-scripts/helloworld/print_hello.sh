#!/bin/bash

echo "echo 的输出"
echo  "hello \n world"





echo "printf 的输出"
printf "hello \nworld \n  "



a=1

echo  $a 

echo "输出a的值为:" $a
# %d 是数字类型占位符
printf "输出a的为: %d \n" $a

# %s 是字符串数据类型的占位符

printf "你是 %s 不？\n" 小李 



#制表符

echo  -e  "hello\tworld"

printf "hello\tworld\n"

#转译

echo  "\$PATH"
echo -e  "hello'world"


echo  "1*1"


