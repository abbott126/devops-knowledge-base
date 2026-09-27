#!/bin/bash

# Java/Tomcat生产环境一键部署

set -euo pipefail

JAVA_VERSION="${JAVA_VERSION:-17}"
TOMCAT_VERSION="${TOMCAT_VERSION:-10.1}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    部署Java+Tomcat
    config                    配置Tomcat
    deploy <war>             部署WAR包
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) deploy app.war
EOF
    exit 1
}

install_java() {
    echo "=== 部署 Java ${JAVA_VERSION} + Tomcat ${TOMCAT_VERSION} ==="
    
    if command -v java >/dev/null 2>&1; then
        echo "Java已安装: $(java -version 2>&1 | head -1)"
    else
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y openjdk-"$JAVA_VERSION"-jdk
        elif command -v yum >/dev/null 2>&1; then
            yum install -y java-17-openjdk
        fi
    fi
    
    if ! command -v catalina.sh >/dev/null 2>&1; then
        cd /tmp
        wget -q https://archive.apache.org/dist/tomcat/tomcat-"${TOMCAT_VERSION:0:1}"/v"$TOMCAT_VERSION"/bin/apache-tomcat-"$TOMCAT_VERSION".tar.gz
        tar -xzf apache-tomcat-"$TOMCAT_VERSION".tar.gz -C /opt/
        ln -sf /opt/apache-tomcat-"$TOMCAT_VERSION" /opt/tomcat
        rm apache-tomcat-"$TOMCAT_VERSION".tar.gz
    fi
    
    cat > /opt/tomcat/conf/server.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Service name="Catalina">
    <Connector port="8080" protocol="HTTP/1.1" 
               connectionTimeout="20000" 
               redirectPort="8443" 
               maxThreads="200"
               minSpareThreads="10"/>
    <Engine name="Catalina" defaultHost="localhost">
      <Host name="localhost" appBase="webapps" unpackWARs="true" autoDeploy="true"/>
    </Engine>
  </Service>
</Server>
EOF
    
    /opt/tomcat/bin/startup.sh
    
    echo ""
    echo "=== 部署完成 ==="
    echo " Java: $(java -version 2>&1 | head -1)"
    echo " Tomcat: http://localhost:8080"
}

config_tomcat() {
    local mem="${1:-512m}"
    local port="${2:-8080}"
    
    cat > /opt/tomcat/bin/setenv.sh << EOF
JAVA_OPTS="-Xms256m -Xmx$mem -XX:+UseG1GC"
CATALINA_OPTS="-server -Djava.security.egd=file:/dev/./urandom"
EOF
    
    sed -i "s/port=\"8080\"/port=\"$port\"/" /opt/tomcat/conf/server.xml
    
    /opt/tomcat/bin/shutdown.sh 2>/dev/null || true
    sleep 2
    /opt/tomcat/bin/startup.sh
    
    echo "Tomcat配置完成: 内存=$mem 端口=$port"
}

deploy_war() {
    local war="$1"
    
    cp "$war" /opt/tomcat/webapps/ROOT.war
    
    sleep 5
    
    ls -la /opt/tomcat/webapps/
    
    echo "应用部署完成: $war"
}

show_status() {
    echo "=== Tomcat状态 ==="
    /opt/tomcat/bin/catalina.sh version
    
    echo ""
    echo "=== 应用列表 ==="
    ls -la /opt/tomcat/webapps/ | head -10
    
    echo ""
    echo "=== 进程状态 ==="
    ps aux | grep tomcat | grep -v grep | head -5
}

case "${1:-}" in
    install)
        install_java
        ;;
    config)
        config_tomcat "${2:-512m}" "${3:-8080}"
        ;;
    deploy)
        deploy_war "$2"
        ;;
    status)
        show_status
        ;;
    *)
        usage
        ;;
esac