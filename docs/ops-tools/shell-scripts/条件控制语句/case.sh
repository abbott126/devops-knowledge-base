#!/bin/bash

#case i  in
#	匹配模式
#	代码块
#esac



read  -p  "请输入数字:[1-4]:" i
case  ${i}  in
	1)
		echo 1 
		;;
	2)
		echo 2
		;;
	3)
		echo 3
		;;
	4)
		echo 4
		;;
	*)
		echo "输入错误！！！"
		;;	
esac
