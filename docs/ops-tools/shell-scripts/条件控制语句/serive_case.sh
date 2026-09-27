#!/bin/bash

read  -p  "对服务的操作: start |stop |reload|restart|enable: "  com


case ${com} in
	start)
		systemctl  start httpd
		;;
	stop)
		systemctl  stop  httpd
		;;
	reload)
		systemctl  reload  httpd
		;;
	restart)
		systemctl  restart httpd
		;;
	enable)
		systemctl  enable --now httpd
		;;
	status)
		systemctl  status  httpd
		;;
	*)
		echo  "no found command ${com}"
		;;
esac
