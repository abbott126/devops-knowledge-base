# Pod 基本管理命令

## 创建 Pod
```bash
kubectl apply -f nginx.yaml
```

## 查看 Pod 列表
```bash
kubectl get pods
```

## 查看 Pod 详细信息
```bash
kubectl describe pod <pod名称>
```

## 查看 Pod 日志
```bash
kubectl logs <pod名称>
```

## 删除 Pod
```bash
kubectl delete pod <pod名