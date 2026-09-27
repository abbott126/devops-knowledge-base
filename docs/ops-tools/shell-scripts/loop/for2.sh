#!/bin/bash

n=0
for i in hello world shell a b c 
do   
#n=`expr $n + 1`
((n++))
  echo "第${n}次的值:"${i}
done 
