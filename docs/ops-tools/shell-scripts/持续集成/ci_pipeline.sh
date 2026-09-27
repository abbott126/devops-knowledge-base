#!/bin/bash

# CI/CD Pipeline自动构建脚本

set -euo pipefail

BUILD_DIR="${BUILD_DIR:-/opt/builds}"
GIT_REPO=""
ARTIFACT_DIR="/opt/artifacts"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    init <git_repo>          初始化项目
    build                   执行构建
    test                    执行测试
    deploy                  部署应用
    full                    完整Pipeline

示例:
    $(basename $0) init https://github.com/user/repo
    $(basename $0) build
EOF
    exit 1
}

init_project() {
    local repo="$1"
    local name
    name=$(basename "$repo" .git)
    
    mkdir -p "$BUILD_DIR/$name"
    cd "$BUILD_DIR/$name"
    
    git clone "$repo" . 2>/dev/null || \
        echo "仓库已存在"
    
    cat > .gitlab-ci.yml << EOF
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - echo "Building..."
  artifacts:
    paths:
      - build/
    expire_in: 1 hour

test:
  stage: test
  script:
    - echo "Testing..."

deploy:
  stage: deploy
  script:
    - echo "Deploying..."
  only:
    - main
EOF
    
    cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing...'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
            }
        }
    }
}
EOF
    
    echo "Pipeline配置完成: $name"
}

run_build() {
    echo "=== 执行构建 ==="
    
    if [[ -f package.json ]]; then
        npm install
        npm run build 2>/dev/null || npm build
    elif [[ -f pom.xml ]]; then
        mvn clean package
    elif [[ -f go.mod ]]; then
        go build -o app .
    elif [[ -f Makefile ]]; then
        make
    fi
    
    mkdir -p "$ARTIFACT_DIR"
    cp -r build/* "$ARTIFACT_DIR"/ 2>/dev/null || true
    
    echo "构建完成"
}

run_test() {
    echo "=== 执行测试 ==="
    
    if [[ -f package.json ]]; then
        npm test
    elif [[ -f pom.xml ]]; then
        mvn test
    elif [[ -f go.mod ]]; then
        go test ./...
    fi
    
    echo "测试完成"
}

run_deploy() {
    echo "=== 部署应用 ==="
    
    if command -v docker >/dev/null 2>&1; then
        docker build -t myapp:latest .
        docker run -d --name myapp myapp:latest
    fi
    
    echo "部署完成"
}

run_full_pipeline() {
    echo "=== 执行完整Pipeline ==="
    
    run_build
    run_test
    run_deploy
    
    echo "Pipeline完成"
}

case "${1:-}" in
    init)
        init_project "$2"
        ;;
    build)
        run_build
        ;;
    test)
        run_test
        ;;
    deploy)
        run_deploy
        ;;
    full)
        run_full_pipeline
        ;;
    *)
        usage
        ;;
esac