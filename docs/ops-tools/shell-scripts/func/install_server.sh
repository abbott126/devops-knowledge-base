#!/bin/bash
# 1. web service    
# 2. data service

# yum 源管理

# web service

# 1. install server
# 2. start
# 3. yum  

# data service
# 1. install server
# 2. start
# 3. yum  


manager_yum(){
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
}


manager_web(){
    echo "+++++++++ web 服务的管理 +++++++++"
    echo "1. httpd"
    echo "2. nginx"
    echo "3. tomcat"
    echo "4. weblogic"
    echo "+++++++++ web 服务的管理 +++++++++"
    read  -p  "请输入需要管理的服务:" num
    case $num in
    1) 
    httpd_server 
    ;;
    2) 
    nginx_server
    ;;
    3) 
    tomcat_server
    ;;
    4) 
    weblogic_server
    ;;
    *) 
    printf "退出"
    ;;
    esac
}
nginx_server(){
    echo  "install  nginx"
    echo  "install  nginx"
    echo  "install  nginx"
    echo  "install  nginx"
    echo  "install  nginx"
}

httpd_server(){
    echo  "install httpd"
}

tomcat_server(){
    echo  "tomcat管理"
}

weblogic_server(){
    echo "weblogic 服务"
}
manager_data(){
    echo  "数据库"
}

meun(){
    echo "###################"
    echo "1. yum 源的管理"
    echo "2. web server管理"
    echo "3. 数据库管理"
    echo "###################"
}

while true
do
    meun
    read  -p "请按照列表中；输入数字:"  num
    case  ${num} in 
        1)
        clear
        manager_yum 
        ;;
        2)
        manager_web
        ;;
        3)
        manager_data
        ;;
    esac
done

  