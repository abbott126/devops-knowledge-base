#!/bin/bash

# Kubernetes集群快速部署

set -euo pipefail

K8S_VERSION="${K8S_VERSION:-1.28}"

usage() {
    cat << EOF
用法: $(basename $0) <命令> [选项]

命令:
    install                    安装K8S组件
    init                       初始化集群
    join <token>             加入集群
    deploy <yaml>            部署应用
    status                   查看状态

示例:
    $(basename $0) install
    $(basename $0) init
    $(basename $0) deploy app.yaml
EOF
    exit 1
}

install_k8s() {
    echo "=== 安装 Kubernetes ${K8S_VERSION} ==="
    
    if command -v kubectl >/dev/null 2>&1; then
        echo "kubectl已安装: $(kubectl version --client 2>&1 | head -1)"
        return 0
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl
        curl -fsSL https://pkgs.k8s.io/debian10/Release.key | apt-key add -
        echo "deb https://pkgs.k8s.io/debian10/ kubernetes-$K8S_VERSION main" | \
            tee /etc/apt/sources.list.d/kubernetes.list
        apt-get update
        apt-get install -y kubelet kubeadm kubectl
        apt-mark hold kubelet kubeadm kubectl
    elif command -v yum >/dev/null 2>&1; then
        cat > /etc/yum.repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
        yum install -y kubeadm kubectl kubelet
        systemctl enable kubelet
    fi
    
    echo "Kubernetes组件安装完成"
}

init_cluster() {
    local pod_cidr="${1:-10.244.0.0/16}"
    
    echo "=== 初始化 Kubernetes 集群 ==="
    
    kubeadm init --pod-network-cidr="$pod_cidr" 2>/dev/null || \
        kubeadm init
    
    mkdir -p "$HOME/.kube"
    cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
    chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    
    echo ""
    echo "集群初始化完成"
    echo ""
    echo "加入命令:"
    kubeadm token create --print-join-command
}

join_cluster() {
    local token="$1"
    
    eval "$token"
    echo "已加入集群"
}

deploy_app() {
    local yaml="$1"
    
    kubectl apply -f "$yaml"
    echo "应用部署完成: $yaml"
}

show_status() {
    echo "=== Kubernetes 状态 ==="
    kubectl get nodes
    
    echo ""
    kubectl get pods --all-namespaces
    
    echo ""
    kubectl get svc
}

case "${1:-}" in
    install)
        install_k8s
        ;;
    init)
        init_cluster "${2:-10.244.0.0/16}"
        ;;
    join)
        join_cluster "$2"
        ;;
    deploy)
        deploy_app "$2"
        ;;
    status)
        show_status
        *)
        usage
        ;;
esac