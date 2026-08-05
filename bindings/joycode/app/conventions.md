# JoyCode APP Binding — Conventions（APP 专属约定）

> **Layer**: JoyCode **APP** Binding。**Status**: Draft v0.1。
> **事实前提**: [capability-matrix.md](./capability-matrix.md)。
> **边界**: 本文件的约定**依赖 APP 的原生 Agent Runtime**，因此**不进 Core RFC**。

## 1. Explicit Routing（显式路由）— MUST

父 Agent 发起 Spawn 时，**MUST 显式指定 `agent_type`**（如 `worker` / `reviewer`），
不得依赖"只描述任务、由平台自动选 SubAgent"。

- **平台事实**：Agent 工具支持 `subagent_type` 显式选择（RI-BUGFIX-001 实证）。
- **为什么强制显式**：Route 是 Orchestrator 唯一的决策动作（RFC-000A）。若把"派谁"
  交给平台隐式自动选，架构里就多了一个**看不见的决策者**，Runtime Sequence Diagram
  里 `Route → Spawn(?)` 那根箭头无法确定终点——违反术语准入铁律"新词/新箭头必须能画进时序图"。
- **结论**：`Route → Spawn(agent_type)` 中的 `agent_type` **由 ACRS 决策显式给出**；
  平台自动路由（若存在）是 ACRS **明确不采用**的能力。

## 2. Agent Tree — 局部管理原则（Local Management）

APP 支持 `SubAgent → SubAgent` 递归，因此 Agent 关系是一棵树，而非"一个总控管全部"。

> **CONV-TREE**：一个 Agent **只管理自己直接 Spawn 的子 Agent**，
> **MUST NOT** 跨层管理孙子及以下节点。

```
Root
 ├── Backend          ← Root 只管 Backend / Review 这一层
 │     └── Reviewer   ← Reviewer 由 Backend 管，不由 Root 管
 └── Review
```

- 每一级只 Collect 自己直接子节点回传的 Handoff Package。
- 这与 RFC-001 §5「Orchestrator MUST NOT accumulate execution history」一致：
  管理范围越窄，父 Context 累积越少。**不存在一个"全知总控"节点。**
- 递归层级 ACRS **不设上限**——平台支持多深就多深；ACRS 只约束"每级管好自己的孩子"。

## 3. SubAgent Timeout Convention（子 Agent 超时兜底）

对应能力矩阵的 ⚠️「SubAgent 卡死 → 父 Agent 无限等待」。这是**平台等待机制的风险**，
对策属 Binding，不属 Core（Core 不写超时——那是 HOW）。

约定（SHOULD，具体阈值由项目配置）：

1. 子 Agent 超过 `N` 分钟无进展信号 → 父 Agent **SHOULD** 停止无限等待。
2. 触发后，父 Agent **MUST** 二选一，且**MUST NOT** 静默吞掉：
   - **提示用户**：暴露"子 Agent 无响应"，交人工决定终止 / 恢复；或
   - **重新 Spawn**：终止卡死实例，带**同一份 Handoff Package** Spawn 一个新同类实例
     （因无 Context Refresh，恢复只能靠 Handoff，见 RFC-001 §6）。
3. 超时导致的重 Spawn **MUST NOT** 让父 Agent 把卡死实例的半成品自述并入自己 Context——
   只认落盘 Evidence 引用（P-9）。

> 说明：本约定是"平台风险的护栏"，不是 Core 行为。换一个不会卡死的平台，这条可整节删除，Core 不受影响。

## 4. 与 Core 的对照（这份文件哪些能上移、哪些永远留在 Binding）

| 条目 | 归属 | 理由 |
| --- | --- | --- |
| 显式路由决策（Route 给出 agent_type）| Core 已含（Route 语义）| 是架构决策 |
| "不采用平台自动路由" | Binding | 是对平台某能力的取舍 |
| Agent Tree 局部管理（CONV-TREE）| **候选上移 Core** | 是拓扑不变量，与 orchestrator 不累积一致 |
| SubAgent 超时兜底 | **永远 Binding** | 依赖平台等待语义，是 HOW |
