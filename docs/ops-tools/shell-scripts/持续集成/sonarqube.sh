#!/bin/bash

# 代码质量检查工具集成

set -euo pipefail

SONAR_URL="${SONAR_URL:-http://localhost:9000}"
SONAR_TOKEN=""

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装SonarQube
    scan                      代码扫描
    report                    生成报告
    quality                   质量门禁

示例:
    $(basename $0) install
    $(basename $0) scan
EOF
    exit 1
}

install_sonar() {
    echo "=== 安装 SonarQube ==="
    
    if command -v sonar-scanner >/dev/null 2>&1; then
        echo "SonarQube Scanner已安装"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y wget openjdk-17-jdk
        wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.zip -O /tmp/sonar.zip
        unzip -o /tmp/sonar.zip -d /opt/
        ln -sf /opt/sonar-scanner-*/bin/sonar-scanner /usr/local/bin/sonar-scanner
    elif command -v yum >/dev/null 2>&1; then
        yum install -y wget java-17-openjdk
        wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.zip -O /tmp/sonar.zip
        unzip -o /tmp/sonar.zip -d /opt/
        ln -sf /opt/sonar-scanner-*/bin/sonar-scanner /usr/local/bin/sonar-scanner
    fi
    
    echo "SonarQube Scanner安装完成"
}

scan_code() {
    local project="${1:-myproject}"
    local key="${2:-myproject}"
    
    cat > sonar-project.properties << EOF
sonar.projectKey=$key
sonar.projectName=$project
sonar.sources=.
sonar.language=java
sonar.sourceEncoding=UTF-8
sonar.host.url=$SONAR_URL
sonar.login=$SONAR_TOKEN
EOF
    
    sonar-scanner
    
    echo "扫描完成"
    echo "报告: $SONAR_URL/dashboard?id=$key"
}

generate_report() {
    local project="$1"
    
    curl -s -u "$SONAR_TOKEN:" "$SONAR_URL/api/measures/component?componentKey=$project&metricKeys=bugs,vulnerabilities,code_smells" | \
        python3 -m json.tool 2>/dev/null || \
        echo "报告生成需要配置SonarQube"
}

quality_gate() {
    local project="$1"
    
    echo "=== 质量门禁检查 ==="
    
    local bugs
    bugs=$(curl -s -u "$SONAR_TOKEN:" "$SONAR_URL/api/measures/component?componentKey=$project&metricKeys=bugs" | \
        grep -oP '"value":\K[0-9]+' || echo 0)
    
    echo "Bug数量: $bugs"
    
    if [[ $bugs -gt 0 ]]; then
        echo "质量门禁: 失败 (发现 $bugs 个Bug)"
        exit 1
    else
        echo "质量门禁: 通过"
    fi
}

case "${1:-}" in
    install)
        install_sonar
        ;;
    scan)
        scan_code "${2:-myproject}" "${3:-}"
        ;;
    report)
        generate_report "${2:-myproject}"
        ;;
    quality)
        quality_gate "${2:-myproject}"
        ;;
    *)
        usage
        ;;
esac