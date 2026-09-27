#!/bin/bash

a=1
b=2

c=`echo $a + $b |bc -l`
d=`echo $a - $b |bc -l`
e=`echo $a \* $b |bc -l`
f=`echo $a / $b |bc -l`
g=`echo $a % $b |bc -l`

echo  "$a+$b=$c" 
echo  "$a-$b=$d" 
echo  "$a*$b=$e" 
echo  "$a/$b=$f" 
echo  "$a%$b=$g" 


h=`expr $a + $b`
printf "$a + $b = %d \n"  $h

#比较运算符

[ $a  == $b ] && echo "True"  ||  echo "false"
[ $a  != $b ] && echo "True"  ||  echo "false"


[ $a -eq  $b ] && echo "相等 True" ||  echo  " 不相等 false"
[ $a -ne  $b ] && echo "不相等 True" ||  echo  "相等false"
[ $a -gt  $b ] && echo "大于True" ||  echo  "小于false"
[ $a -lt  $b ] && echo "小于True" ||  echo  "大于false"
[ $a -ge  $b ] && echo "大于等于 True" ||  echo  "小于等于false"
[ $a -le  $b ] && echo "小于等于True" ||  echo  "大于等于false"
