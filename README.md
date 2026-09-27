# DevOps 知识库

系统化整理 Linux 运维、容器化、数据库、自动化部署等核心技术文档。

## 在线文档

在线访问：[DevOps 知识库](https://abbott126.github.io/devops-knowledge-base/)

## 技术栈

- 纯静态 HTML/CSS/JavaScript
- 亮色/暗色主题切换
- 响应式设计（支持移动端）
- Kubernetes、Docker、Ansible、Jenkins 等技术文档

## 项目结构

```
docs/           # 技术文档页面
  overview/     # 概述（云计算、网络架构）
  databases/    # 数据库（MySQL、Redis、ProxySQL）
  containers/   # 容器与编排（Docker、Docker Compose）
  Kubernetes/   # K8s 集群管理
  automation/   # 自动化与 DevOps（Ansible、Jenkins）
  ops-tools/    # 运维工具（Shell、LVS、Ceph）
  web-services/ # Web 服务（Nginx、Tomcat）
  others/       # 其他资源（OpenStack）
css/            # 样式表
js/             # JavaScript 交互
assets/         # 配置文件和示例（docker-compose.yml, k8s yaml）
images/         # 配图资源
```

## 本地运行

直接打开 `index.html` 即可，或使用任意静态服务器：

```bash
# Python
python -m http.server 8000

# Node.js
npx serve .
```

## 部署

本项目使用 GitHub Pages 自动部署。每次推送到 `main` 分支会自动更新在线文档。
