# JoyCode Binding — CLI 入口

> **Layer**: JoyCode Binding。**Status**: Draft v0.1。
> **绑定对象**: JoyCode **CLI**（默认原生对话，入口处无预置 Agent）。
> **验证依据**: RI-BUGFIX-001 就是在 CLI 上、用本 Binding 的思路跑通的（findings A/B 全绿）。
>
> **CLI 与 APP 的本质区别**：CLI 是**行为模拟（Behavior Simulation）**——用 Root Prompt
> 让单个聊天 Context 表现出 Backend→Review→… 的多 Agent 行为；APP 是**原生 Runtime（Native
> Runtime）**——平台真的创建多个 Agent/Context。两者**行为一致，Runtime 不一致**。
> 能力差异见 [../app/capability-matrix.md](../app/capability-matrix.md)。

## 1. CLI 入口的事实

```
User
  │
  ▼
LLM（原生对话，入口无 Agent、无 Orchestrator）
```

CLI **入口**没有预置 Agent——但**平台原语 P2（Agent 工具）依然可用**。
RI-BUGFIX-001 实测：根 LLM 通过 **Agent 工具** Spawn 出隔离的 Worker 和独立的 Reviewer。

> 关键澄清：**"CLI 没有 Agent" 指入口形态，不指能力缺失。** Spawn 通道在 CLI 上存在。

## 2. Binding 映射

| ACRS Core 概念 | JoyCode CLI 落法 |
| --- | --- |
| Orchestrator（Route） | 由 **Root Prompt** 让根 LLM 扮演；它只 Route，不实现 |
| Spawn(agent_type) | 调 **Agent 工具**，把该 agent 的 Handoff Package 作为 prompt 传入 |
| Handoff Package | Agent 工具调用的 prompt 正文（结构化）+ 共享文件系统落盘引用 |
| Evidence Index | 文件（如 `evidence/ledger.jsonl`）或 MCP ledger（**载体是 Binding**，见 RI findings C-1）|
| Boundary / Done Gate | Root Prompt 内的 Finish 判据 + 独立 Reviewer 的重跑退出码 |
| Context 隔离 | Agent 工具天然提供：子 Agent 不继承父对话（P2 / RI findings B-1）|

> ⚠️ 合规缺口（登记于 RFC-006）：本环境 MCP ledger 调用 600s 超时不可用，
> 故 Evidence Index 载体回退为文件型 `ledger.jsonl`。两者都满足 Core 的"只持引用"WHAT。

## 3. Root Prompt（让根 LLM 成为 Orchestrator）

> 这是一段**可直接贴进 CLI 首轮**的引导。它是 Core `agent-contract` / RFC-001 的**渲染**，
> 不新增任何 Core 概念。

```
你是 ACRS Root Orchestrator，运行在 JoyCode CLI 上。

【你的唯一职责：Route】
按 Orchestrator Cycle 运转：Observe → Route → Collect → Next。
你 MUST NOT 自己读源码、改代码、跑测试——那是被 Spawn 的 Worker 的事。
你 MUST NOT 把下游日志/diff 正文读进自己上下文，只登记引用（路径+退出码+一行摘要）。

【怎么 Spawn】
需要执行时，调用 Agent 工具创建一个隔离实例，把该 agent 的 Handoff Package
（见 core/agent-contract §2 的 input 段）作为 prompt 传入。子实例看不到本对话，
它拥有的全部输入 = 你传给它的 Handoff Package + 共享文件系统 + MCP。

【独立验证者不变量（MUST，INV-VERIFY）】
产出改动的实例，绝不能是验收它的实例。验证必须 Spawn 另一个隔离实例，
且该验证者独立重取客观信号（如自己重跑 failing_cmd 拿退出码）。

【Done Gate — 全部成立才 Finish】
- Evidence Index 中有可解引用的测试日志，exit code == 0；
- 有与"改 bug"相称的 diff / 补丁引用（非大范围重写）；
- 独立 Reviewer 实例判定 PASS。
任一不成立 → 不得 Finish。一个永远说不出 REJECT 的 Boundary 不合规。

【Context 溢出（无 Context Refresh）】
你或任何子实例接近上下文上限时，MUST NOT 原地续跑。
生成 Handoff Package 落盘，Spawn 一个同类新实例接续（RFC-001 §6）。
```

## 4. Context 溢出在 CLI 的落法

CLI 根对话本身也会满。因为**无 Context Refresh**，唯一出路是 Spawn + Handoff：

```
Root#1（对话渐满）
  │  写 handoff.json（Task 进度 + Evidence Index 引用 + 下一步）
  ▼
（新开一段 CLI 会话，首轮贴 Root Prompt + handoff.json）
  │
  ▼
Root#2 —— 从 handoff.json 恢复，Task 连续，Context 全新
```

连续的是 **Task**，不是 Root 实例（RFC-000A 分层不变量）。

## 5. 已验证 / 未验证

- ✅ 根 LLM 经 Agent 工具 Spawn 隔离 Worker + 独立 Reviewer（RI-001 A-1/A-2/B-1）。
- ✅ Orchestrator Context 未随 worker 数增长（RI-001 B-2）。
- ◻ REJECT 回环（Reviewer 拒 → Spawn Worker#2）在 CLI 上未实跑（RI-001 D-1）。
- ◻ Root 溢出续接（§4）未实跑（RI-001 D-2）。
