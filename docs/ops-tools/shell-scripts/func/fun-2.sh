#!/bin/bash

#传参

hello(){
    echo  "第一个值: " $1
    return  "100"    
}

hello  abc
echo "函数返回状态：$?"