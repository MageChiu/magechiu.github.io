---
title: 初学 Operator
date: 2026-03-28
section: kubernetes
summary: 从控制器模式、CRD、Reconcile 循环三个角度快速理解 Operator 的入门心智模型。
tags:
  - kubernetes
  - operator
  - controller
hero_image: /resources/images/operator-cover.jpg
---

Operator 本质上是把“人肉运维流程”变成可重复执行的控制器逻辑，让应用能够像 Kubernetes 原生资源一样被声明式管理。

* TOC
{:toc}

## 为什么需要 Operator

当一个系统的生命周期不仅包含部署，还包含扩容、备份、升级、故障恢复与版本迁移时，只靠 Deployment、StatefulSet 往往不够。

> Operator 解决的是“复杂应用的持续运维自动化”问题，而不是单纯的资源编排。

## 核心概念

### 1. CRD

CRD（CustomResourceDefinition）允许我们给 Kubernetes 扩展出新的资源类型，比如 `AppCluster`、`RedisFailover`。

### 2. Controller

Controller 会监听自定义资源对象的变化，然后不断把“实际状态”拉回“期望状态”。

### 3. Reconcile Loop

最重要的就是 Reconcile 循环：

```go
func (r *AppClusterReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 1. 读取资源
    // 2. 比对期望状态与当前状态
    // 3. 创建或更新依赖资源
    // 4. 返回下一次调谐策略
    return ctrl.Result{}, nil
}
```

## 一张示意图

下面这张图来自站点资源目录，演示了笔记中图片应当如何统一放置和引用：

![Operator 入门配图]({{ '/resources/images/operator-cover.jpg' | relative_url }})

## 常见工作流

| 阶段 | 关注点 | 典型动作 |
| --- | --- | --- |
| 建模 | 自定义资源设计 | 定义 Spec / Status |
| 调谐 | 状态收敛 | 创建 Deployment、Service、PVC |
| 运维 | 升级与修复 | 滚动升级、回滚、告警恢复 |

## 入门建议

- 先理解 Kubernetes 控制器模式，而不是一上来背 Operator SDK 命令。
- 先做一个单资源、单控制器的最小案例。
- 先把状态机和异常路径想清楚，再开始写 Reconcile。
- 把观测性做好，包括日志、事件和状态字段。

## Markdown 渲染能力验证

- [x] 任务列表
- [x] 表格
- [x] 代码块
- [x] 图片
- [x] 引用

如果你后续继续写笔记，建议保持如下路径规范：

```text
note/
  kubernetes/
    operator.md
resources/
  images/
    operator-cover.jpg
```
