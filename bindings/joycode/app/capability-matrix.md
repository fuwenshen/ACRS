# JoyCode Capability Matrix（能力矩阵 — 所有 Binding 的事实基础）

> **Layer**: JoyCode Binding 事实基础页。**Status**: Frozen facts v0.1（平台真实能力快照）。
> **用途**: 所有 JoyCode Binding（app / cli）**MUST** 以本表为事实前提。
> **禁止**: 把 CLI 没有的能力写进 CLI Binding，或把 APP 的原生 Runtime 当成 Core Spec。

## 1. 能力矩阵（用户 2026-07-30 提供，冻结为事实）

| 能力 | CLI | APP | ACRS 是否依赖 |
| --- | --- | --- | --- |
| 默认入口 | 一个原生对话 | 一个 Agent | — |
| Agent | ❌ 默认没有 | ✅ 有 | 是 |
| Agent → SubAgent | ❌ | ✅ 支持 | 是（APP）|
| SubAgent → SubAgent（递归）| ❌ | ✅ 支持 | 是 |
| SubAgent 完成 → 返回父 Agent 继续 | ❌ | ✅ | 是 |
| SubAgent 卡死 | — | ⚠️ 父 Agent 一直等待，需人工恢复 | 需 Binding 级约定兜底（见 §3）|
| 父 Agent Resume | ❌ | ✅ | 是 |
| Handoff | Prompt 模拟 | 原生 Agent 传参 | 是 |
| 多 Context | ❌ 单聊天 Context | ✅ 每 Agent 一个 Context | 是（APP）|
| Tool / MCP | ✅ | ✅ | 是 |
| Skill | ✅ | ✅ | 是 |

> 注：CLI 入口无预置 Agent，但 P2 Agent **工具**在 CLI 会话内可调用（RI-BUGFIX-001 实证）。
> 上表"CLI Agent ❌"指的是**入口默认形态**，不是"CLI 完全无法 Spawn"。
> CLI 的 Spawn 走 Agent 工具，行为等价、但仍在同一根聊天 Context 的调度下（详见 ../cli/root-prompt.md）。

## 2. 最重要的一条推论：ACRS 不实现 Multi-Agent Runtime

JoyCode APP **已经提供** spawn / wait / resume / 递归子 Agent 这套 Runtime。因此：

> **ACRS MUST NOT 定义 `spawn() / wait() / resume()` 的实现机制。**
> **ACRS 只定义**：WHEN Spawn、Spawn 哪个 agent_type、Handoff 什么、返回后怎么 Continue。

```
JoyCode Runtime  →  负责：创建 SubAgent、等待、恢复父 Agent、递归
ACRS Convention  →  负责：Route(何时/派谁)、Handoff Package、Done Gate、返回后续跑
```

这就是"ACRS 是 Specification 不是 Runtime"的最强落地证据：Runtime = JoyCode，ACRS = Convention。

## 3. 平台风险 → Binding 级约定（不进 Core）

矩阵里的 ⚠️「SubAgent 卡死 → 父 Agent 无限等待」是**平台等待机制的风险**，
因此对策属 **APP Binding**，见 [conventions.md](./conventions.md) 的「SubAgent Timeout Convention」。
**Core RFC 不写超时**——超时依赖平台的等待语义，是 HOW，不是 WHAT。

## 4. 路由能力（回答显式 vs 自动）

父 Agent 调子 Agent 时**可显式指定 agent_type**（Agent 工具的 `subagent_type` 参数，RI-001 实证）。
ACRS Binding **MUST 采用显式路由**，不采用"只描述任务、平台自动选 agent"（即使平台支持后者）。
理由见 [conventions.md](./conventions.md) 的「Explicit Routing」。
