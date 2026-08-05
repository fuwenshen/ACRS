# JoyCode Binding — APP 入口

> **Layer**: JoyCode Binding。**Status**: Draft v0.1。
> **绑定对象**: JoyCode **APP**（基于所选 Agent 对话；Agent 可调用其他 Agent）。
> **关系**: 与 CLI 是**同一套 Core，不同入口**。Core 概念一行不改，只换 Binding。
> **配套**: 事实前提见 [capability-matrix.md](./capability-matrix.md)；APP 专属约定（显式路由 /
> Agent Tree / SubAgent 超时）见 [conventions.md](./conventions.md)。
>
> **核心前提（先读）**：JoyCode APP 已原生提供 spawn / wait / resume / 递归子 Agent 的
> **Multi-Agent Runtime**。因此本 Binding **不实现** spawn/wait/resume——它们是平台的。
> 本 Binding 只把 Core 的 `Route / Spawn / Handoff / Done Gate` **映射**到平台原生动作。

## 1. APP 入口的事实

```
User
  │
  ▼
所选 Agent（例：Backend Agent）  ← 平台提供 Agent Runtime
  │
  ├── 调 Tool / MCP
  ├── 调 Skill
  └── 调 Agent（Agent-to-Agent，平台原生支持）
```

与 CLI 的唯一区别：**入口就是一个 Agent**，且 Agent 调 Agent 是平台原生动作——
不需要 CLI 那样"用 Root Prompt 模拟 Orchestrator"。

## 2. Binding 映射

| ACRS Core 概念 | JoyCode APP 落法 |
| --- | --- |
| Spawn(agent_type) | **Agent Call**（当前 Agent 调用另一个 Agent，平台原生）|
| Continue | 在当前 Agent 的 Context 内继续 Worker Loop，不发起 Agent Call |
| Handoff Package | Agent Call 传入的结构化输入（承 core/agent-contract §2 input）|
| Context 隔离 | 被调 Agent 是独立 Context，不继承主叫方对话（P2）|
| Orchestrator（Route） | 可由一个专门的 Coordinator Agent 承担，或由入口 Agent 内联 Route 决策 |

> **核心等式**：`Spawn ≈ Agent Call`。Core 永远只写 `Spawn`；
> 平台是 `Agent Call`（APP）还是 `新开 CLI 会话`（CLI）是 Binding 细节。
> 换平台（Claude Code / Cursor）时，Core 不动，只改这张映射表。

## 3. INV-VERIFY 在 APP 的落法

独立验证者不变量（core/agent-contract §3）在 APP 上落成：

```
Backend Agent（产出补丁）
  │  Agent Call → Reviewer Agent（传 Evidence 引用 + 验收判据）
  ▼
Reviewer Agent（独立 Context，独立重跑测试）
  │  返回 verdict + 自己的退出码
  ▼
Backend / Coordinator 据 verdict Route
```

MUST：Reviewer Agent 是**独立实例**，不得读到 Backend 的对话自述——APP 的 Agent Call
天然隔离上下文，这条不变量因此是"平台事实"，规范只是把它写成 MUST。

## 4. Context 溢出：同类实例续接（APP 体验优于 CLI）

APP 有原生 Agent Call，溢出续接对用户几乎无感：

```
Backend#1（开发中，Context 达阈值）
  │  冻结产出 → 写 handoff.json（进度 + Evidence 引用 + 下一步）
  │  Agent Call → Backend（同一 Agent Type，新实例）
  ▼
Backend#2（全新 Context，从 handoff.json 恢复，继续开发）
```

- 主叫方 **MUST NOT** 期待 Backend#2 记得 Backend#1 说过的话——只走 handoff.json（P-9）。
- Backend#1 与 Backend#2 是**同一 Agent Type 的不同 Instance**；连续的是 **Task**。
- 这正是 RFC-000A「无 Context Refresh，只有 Spawn+Handoff」在 APP 上的自然形态。

## 5. Agent 定义与 Prompt 的分工（回应"先定义 Agent，不先写 Prompt"）

- APP 里每个 Agent 的**契约**（Responsibilities/Boundary/Input/Output/Handoff）
  = 直接引用 `core/agent-catalog.md`，**跨平台一致**。
- APP 里每个 Agent 的**Prompt 全文 + Skill 加载策略 + 可调用关系**
  = 本 Binding 目录下的实现细节，**平台相关**。

> 用户在 APP 看到的是 `Backend Agent`（一个壳），不是 `Java Skill`——
> Skill 由 Agent 按需加载，不再是用户直接使用的对象。

## 6. 未验证（诚实缺口）

- ◻ APP 上的 Agent-to-Agent Call 尚未在本项目内实跑（RI-BUGFIX-001 跑在 CLI）。
  §3/§4 的 APP 时序目前是从"CLI 已验证 + APP 平台事实"推导，未直接实测。
- ◻ 溢出续接（§4）在任一入口都未实跑（RI-001 D-2）。
