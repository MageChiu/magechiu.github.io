# Kubernetes 默认调度器 vs Volcano 调度器：系统性对比

> 本文从架构设计、调度模型、核心能力、适用场景等维度，对 Kubernetes 原生调度器（kube-scheduler）和 Volcano 调度器进行系统性对比分析。

---

## 一、项目背景与定位

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **所属项目** | Kubernetes 核心组件 | CNCF 孵化项目（2020 年进入 CNCF） |
| **设计目标** | 通用工作负载调度（微服务、Web 应用等） | 高性能批式计算 / AI 训练 / 大数据任务调度 |
| **核心用户** | 所有 K8s 用户 | AI/ML 工程师、大数据工程师、HPC 用户 |
| **调度哲学** | Pod-by-Pod，服务于在线业务稳定性 | Job-as-a-Unit，服务于批式任务吞吐和资源效率 |
| **社区活跃度** | K8s 核心社区维护 | 华为主导，多家公司参与（腾讯、AWS、字节等） |

---

## 二、架构设计对比

### 2.1 kube-scheduler 架构

```
┌────────────────────────────────────────────────┐
│                kube-scheduler                   │
│                                                 │
│  Scheduling Queue (ActiveQ / BackoffQ / UnschQ) │
│         │                                       │
│         ▼                                       │
│  ┌─ Scheduling Cycle (同步，串行) ──────────┐    │
│  │  Filter → Score → Reserve → Bind         │    │
│  │  (每次只处理一个 Pod)                      │    │
│  └──────────────────────────────────────────┘    │
│                                                 │
│  Scheduling Framework (扩展点/插件机制)          │
│  PreFilter / Filter / PostFilter / PreScore     │
│  Score / Reserve / Permit / PreBind / Bind      │
│  PostBind                                       │
└────────────────────────────────────────────────┘
```

**核心特征**：
- **单 Pod 调度循环**：每个 Scheduling Cycle 只绑定一个 Pod
- **串行决策**：调度线程逐个从队列取 Pod → 过滤 → 打分 → 绑定
- **Scheduling Framework**：v1.19+ 引入插件化框架，提供 ~12 个扩展点
- **无 Job 语义**：调度器不感知 Pod 之间的归属关系

### 2.2 Volcano 架构

```
┌─────────────────────────────────────────────────────┐
│                  Volcano Scheduler                    │
│                                                       │
│  ┌─ Cache ─┐   ┌─ Session（每个调度周期） ─────────┐  │
│  │ Jobs    │──▶│                                    │  │
│  │ Nodes   │   │  Actions (有序执行链)：             │  │
│  │ Queues  │   │  Enqueue → Allocate → Preempt      │  │
│  │ PodGrps │   │  → Reclaim → Backfill → Shuffle    │  │
│  └─────────┘   │                                    │  │
│                │  Plugins (各 Action 内调用)：        │  │
│                │  gang / binpack / drf / proportion  │  │
│                │  nodeorder / predicates / sla / tdm │  │
│                └────────────────────────────────────┘  │
│                                                       │
│  CRDs: vcjob / PodGroup / Queue                       │
└─────────────────────────────────────────────────────┘
```

**核心特征**：
- **Job 级别调度**：调度单元是 PodGroup / vcjob，不是单个 Pod
- **Session 机制**：每个调度周期创建一个 Session，批量处理多个 Job
- **Action + Plugin 双层架构**：Action 定义调度流程，Plugin 提供策略
- **内置 Queue 系统**：支持多租户队列、配额和公平调度

---

## 三、核心能力对比

### 3.1 调度粒度与模型

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **最小调度单元** | Pod | PodGroup（一组 Pod） |
| **调度循环处理量** | 1 Pod / Cycle | N Jobs × M Pods / Session |
| **Job 感知** | ❌ 不感知 Pod 归属关系 | ✅ 原生 Job / PodGroup 抽象 |
| **调度决策范围** | 当前 Pod 是否可放置 | 全局视角：多个 Job 竞争资源如何分配 |

### 3.2 Gang Scheduling（成组调度）

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **All-or-Nothing 语义** | ❌ 不支持 | ✅ `minAvailable` 原生支持 |
| **资源死锁预防** | ❌ 会出现部分 Pod 调度导致死锁 | ✅ 不满足 minAvailable 则整组不调度 |
| **Coscheduling 插件** | ⚠️ scheduler-plugins 提供有限支持 | ✅ 内置完整实现 |

**死锁场景对比**：

```
场景：集群有 12 GPU，Job A 需要 8 GPU，Job B 需要 8 GPU

kube-scheduler 行为：
  Job A: 调度 6 个 Pod ✓ (占用 6 GPU)
  Job B: 调度 6 个 Pod ✓ (占用 6 GPU)
  结果：A 和 B 都凑不齐 8 个 → 死锁，12 GPU 全部浪费

Volcano 行为：
  Job A: 检查 → 12 GPU ≥ 8 → 一次性调度 8 个 Pod ✓
  Job B: 检查 → 4 GPU < 8 → 整组不调度，进入 Pending 队列
  结果：A 正常运行，B 等 A 完成后再调度 → 无死锁
```

### 3.3 队列管理与多租户

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **队列抽象** | ❌ 无（只有 Namespace + ResourceQuota） | ✅ Queue CRD，支持层级队列 |
| **资源配额** | Namespace 级别硬配额 | Queue 级别 capability / guarantee / weight |
| **弹性配额** | ❌ 硬性限制，无法借用 | ✅ 支持队列间资源借用与回收（Reclaim） |
| **公平调度** | ❌ 无 | ✅ DRF / Proportion 算法 |
| **优先级排序** | PriorityClass（Pod 级别） | Job 级别优先级 + Queue 级别优先级 |

**Volcano Queue 示例**：

```yaml
apiVersion: scheduling.volcano.sh/v1beta1
kind: Queue
metadata:
  name: training-team-a
spec:
  weight: 3            # 权重占比
  capability:          # 资源上限
    cpu: "100"
    memory: "200Gi"
    nvidia.com/gpu: "32"
  guarantee:           # 资源保底
    resource:
      cpu: "20"
      memory: "40Gi"
      nvidia.com/gpu: "8"
  reclaimable: true    # 允许空闲资源被其他队列借用
```

### 3.4 资源调度策略

| 策略 | kube-scheduler | Volcano |
|------|---------------|---------|
| **节点亲和/反亲和** | ✅ | ✅ |
| **拓扑感知** | ✅ TopologySpreadConstraints | ✅ + 拓扑感知的 Gang 调度 |
| **Binpack（紧凑装箱）** | ⚠️ MostAllocated 策略（弱） | ✅ 专用 binpack 插件，GPU 场景优化 |
| **Spread（分散调度）** | ✅ | ✅ |
| **抢占** | ✅ Pod 级别抢占 | ✅ Job 级别抢占 + Queue 间 Reclaim |
| **资源预留** | ❌ | ✅ Reserve/Pipeline 机制 |
| **回填（Backfill）** | ❌ | ✅ 小任务填充碎片资源 |
| **分时复用（TDM）** | ❌ | ✅ 在线/离线业务分时共享 |

### 3.5 作业生命周期管理

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **Job 状态机** | 仅调度，不管理 Job 生命周期 | ✅ 完整状态机：Pending → Running → Completed/Failed |
| **任务依赖** | ❌ | ✅ Task 间依赖关系 |
| **失败策略** | Pod 级别的 restartPolicy | ✅ Job 级别策略：重试、终止、依赖重启 |
| **SLA 保障** | ❌ | ✅ JobWaitingTime 超时自动处理 |
| **多任务类型** | 需要外部 Operator | ✅ 内置 Task 概念（PS/Worker/Chief 等） |

**Volcano Job 多任务示例**（分布式训练）：

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: ps-worker-training
spec:
  minAvailable: 5
  schedulerName: volcano
  queue: training-team-a
  policies:
    - event: PodEvicted
      action: RestartJob
    - event: PodFailed
      action: AbortJob
  tasks:
    - replicas: 2
      name: ps
      template:
        spec:
          containers:
            - name: ps
              image: training:v1
              command: ["python", "train.py", "--role=ps"]
    - replicas: 4
      name: worker
      template:
        spec:
          containers:
            - name: worker
              image: training:v1
              command: ["python", "train.py", "--role=worker"]
              resources:
                limits:
                  nvidia.com/gpu: "1"
```

### 3.6 扩展性

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **扩展机制** | Scheduling Framework（~12 扩展点） | Action + Plugin 架构 |
| **自定义调度器** | 支持多调度器共存 | 支持自定义 Action / Plugin |
| **生态集成** | 原生集成所有 K8s 工作负载 | 集成 Spark / Flink / MPI / TensorFlow / PyTorch / Ray / Argo / Kubeflow |
| **Webhook 支持** | ❌ 调度器不提供 | ✅ Admission Webhook 自动注入 schedulerName / PodGroup |

---

## 四、性能对比

| 指标 | kube-scheduler | Volcano |
|------|---------------|---------|
| **单 Pod 调度延迟** | 低（~ms 级） | 略高（Session 周期开销） |
| **批量任务吞吐** | 差（逐个调度，O(N) 个调度周期） | 优（批量决策，1 个 Session 处理 N 个 Job） |
| **大规模 Pending Pod** | 队列排序+重试，调度器压力大 | PodGroup 聚合，减少调度器决策次数 |
| **资源利用率（GPU 场景）** | 低（碎片化严重） | 高（Gang + Binpack + Backfill 组合） |
| **死锁概率** | 高（分布式训练场景） | 无（Gang Scheduling 保证） |

**吞吐量参考**：
- kube-scheduler：~100 Pods/s（默认配置）
- Volcano：在批式场景下，因减少无效调度和回退，实际有效调度吞吐更高

---

## 五、部署与运维

| 维度 | kube-scheduler | Volcano |
|------|---------------|---------|
| **安装方式** | K8s 内置，无需额外安装 | Helm Chart / YAML 部署 |
| **组件** | kube-scheduler 单组件 | volcano-scheduler + volcano-controller + volcano-admission |
| **CRD 依赖** | 无 | vcjob / PodGroup / Queue / Command |
| **升级影响** | 随 K8s 版本升级 | 独立版本，需关注与 K8s 版本兼容性 |
| **监控** | scheduler metrics（Prometheus） | 自有 metrics + 调度事件 |
| **调试难度** | 低（社区文档丰富） | 中（需理解 Action/Plugin 执行流程） |
| **HA 部署** | Leader Election 内置 | Leader Election 内置 |

---

## 六、适用场景决策矩阵

| 场景 | 推荐调度器 | 原因 |
|------|-----------|------|
| 微服务 / Web 应用 | kube-scheduler | 无需批式语义，原生调度器即可 |
| 单机 GPU 推理服务 | kube-scheduler | 简单 Pod 调度，无 Gang 需求 |
| **分布式训练（多机多卡）** | **Volcano** | Gang Scheduling 必需，防止死锁 |
| **Spark / Flink on K8s** | **Volcano** | Driver + Executor 成组调度 + 队列管理 |
| **Ray on K8s 分布式任务** | **Volcano** | Head + Worker 需要 Gang 语义 |
| **多团队共享 GPU 集群** | **Volcano** | Queue 公平调度 + 弹性配额 |
| **HPC / MPI 任务** | **Volcano** | 原生 MPI Job 支持 + Gang |
| CI/CD Pipeline | 视规模 | 小规模用原生，大规模排队用 Volcano |
| 混合（在线+离线） | 共存 | 在线业务用 kube-scheduler，离线批式用 Volcano |

---

## 七、与其他批式调度方案对比

除了 Volcano，社区还有其他批式调度方案，简要对比如下：

| 维度 | Volcano | Scheduler Plugins (Coscheduling) | Kueue | Yunikorn |
|------|---------|--------------------------------|-------|----------|
| **Gang Scheduling** | ✅ 完整 | ⚠️ 基础 | ⚠️ 通过 Admission 实现 | ✅ |
| **Queue 管理** | ✅ 强 | ❌ 无 | ✅ 强（LocalQueue/ClusterQueue） | ✅ 层级队列 |
| **Job 生命周期** | ✅ 完整 | ❌ 仅调度 | ✅ Workload 管理 | ⚠️ 有限 |
| **架构方式** | 独立调度器 | kube-scheduler 插件 | Admission + kube-scheduler | 独立调度器 |
| **侵入性** | 中（需指定 schedulerName） | 低（原生扩展） | 低（Admission 拦截） | 中 |
| **成熟度** | 高（CNCF 孵化，生产广泛使用） | 中 | 中（K8s SIG 主推） | 中 |
| **AI/大数据生态** | 最佳（Spark/Flink/MPI/TF/PyTorch/Ray） | 有限 | 逐步完善 | 较好（来自 YARN 经验） |

---

## 八、总结

### 核心差异一句话

> **kube-scheduler 是面向在线服务的 Pod 级别调度器；Volcano 是面向批式计算的 Job 级别调度器。两者的差异不是功能缺失，而是调度模型和抽象层次的根本不同。**

### 选型建议

1. **纯在线业务集群**：使用 kube-scheduler 即可，无需引入额外复杂度
2. **有分布式训练/大数据需求**：强烈建议引入 Volcano，Gang Scheduling 和 Queue 管理是刚需
3. **混合集群**：两者可共存——通过 `schedulerName` 字段区分，在线 Pod 用默认调度器，离线 Job 用 Volcano
4. **轻量级需求**：如果只需要简单的 Coscheduling 且不需要 Queue 管理，可考虑 Kueue 或 scheduler-plugins 作为轻量替代
5. **Ray on K8s**：推荐 Volcano 搭配 KubeRay，通过 PodGroup 保证 Ray Cluster 的 Head + Worker 成组调度

---

*文档生成时间：2026-04-01*
