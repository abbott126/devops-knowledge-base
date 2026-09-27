#!/bin/bash

# Jenkins自动安装和配置

set -euo pipefail

JENKINS_VERSION="${JENKINS_VERSION:-2.426}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装Jenkins
    config                    配置Jenkins
    plugin <name>             安装插件
    job <name> <git>         创建Job
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) plugin git docker
    $(basename $0) job myapp https://github.com/user/repo
EOF
    exit 1
}

install_jenkins() {
    echo "=== 安装 Jenkins ${JENKINS_VERSION} ==="
    
    if command -v jenkins >/dev/null 2>&1; then
        echo "Jenkins已安装"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y openjdk-17-jdk curl
        curl -fsSL https://pkg.jenkins.io/debian/jenkins.io.key | tee /etc/apt/trusted.gpg.d/jenkins.asc
        echo "deb https://pkg.jenkins.io/debian binary/" | tee /etc/apt/sources.list.d/jenkins.list
        apt-get update
        apt-get install -y jenkins
    elif command -v yum >/dev/null 2>&1; then
        yum install -y java-17-openjdk
        curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.io.repo -o /etc/yum.repos.d/jenkins.repo
        yum install -y jenkins
    fi
    
    systemctl enable jenkins
    systemctl start jenkins
    
    local password
    password=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "请查看日志")
    echo ""
    echo "Jenkins安装完成"
    echo "初始密码: $password"
    echo "访问: http://localhost:8080"
}

config_jenkins() {
    cat > /etc/sysconfig/jenkins << 'EOF'
JENKINS_USER=jenkins
JENKINS_PORT=8080
JENKINS_OPTS="-Djava.awt.headless=true"
JENKINS_PREFIX=""
EOF
    
    systemctl restart jenkins
    echo "Jenkins配置重载完成"
}

install_plugin() {
    local plugin="$1"
    
    local jenkins_cli="/var/lib/jenkins/war/WEB-INF/jenkins-cli.jar"
    
    if [[ -f "$jenkins_cli" ]]; then
        java -jar "$jenkins_cli" install-plugin "$plugin" -deploy
    else
        curl -X POST -d "plugin=$plugin" http://localhost:8080/pluginManager/installNecessaryPlugins
    fi
    
    echo "插件安装完成: $plugin"
}

create_job() {
    local name="$1"
    local git="$2"
    
    mkdir -p /var/lib/jenkins/jobs/"$name"
    
    cat > /var/lib/jenkins/jobs/"$name"/config.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>$name Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.plugins.git.GitSCM">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>$git</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>*/main</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
  </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers>
    <hudson.triggers.SCMTrigger>
      <spec>H/5 * * * *</spec>
      <ignorePostCommitHooks>false</ignorePostCommitHooks>
    </hudson.triggers.SCMTrigger>
  </triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>echo "Building $name"</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF
    
    chown -R jenkins:jenkins /var/lib/jenkins/jobs/"$name"
    
    echo "Job创建完成: $name"
}

check_status() {
    echo "=== Jenkins状态 ==="
    systemctl status jenkins --no-pager || true
    echo ""
    echo "=== 运行Jobs ==="
    ls /var/lib/jenkins/jobs/ 2>/dev/null | head -10 || echo "无Jobs"
}

case "${1:-}" in
    install)
        install_jenkins
        ;;
    config)
        config_jenkins
        ;;
    plugin)
        install_plugin "$2"
        ;;
    job)
        create_job "$2" "$3"
        ;;
    status)
        check_status
        ;;
    *)
        usage
        ;;
esac