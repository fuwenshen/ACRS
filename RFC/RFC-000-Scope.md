# RFC-000: Scope（范围与边界）

| 字段 | 值 |
| --- | --- |
| **Status** | Draft — Frozen Candidate |
| **Version** | 1.0 |
| **Created** | 2026-07-29 |
| **Input** | `RFC-000-architecture-manifesto.md`（邀评稿，历史输入，不推翻） |
| **性质** | 定位与边界。本 RFC 冻结"ACRS 是什么、不是什么、遵守什么"，不展开任何具体机制。 |

> **宪法第一句（The Constitution）**
>
> **ACRS defines behavioral conventions rather than runtime implementations.**
>
> ACRS 是一套构建在 **JoyCode APP 与 JoyCode CLI 之上**的 AI Coding **架构规范（Architecture Specification）**。它定义 **WHAT**（行为约束），不定义 **HOW**（实现方式）；它不要求 JoyCode 新增任何平台能力。

---

## 1. What ACRS Is —— ACRS 是什么

ACRS 是一套 **Architecture Specification**：用 RFC 2119 的规范语言（MUST / SHOULD / MAY）定义 AI Coding 系统在 JoyCode 上应遵守的行为约束，并要求每一条约束都能映射到 JoyCode 现有原语。

它的定位介于两者之间，取其严格的一端：

```
Runtime         ❌ 过强——会滑向 Scheduler / DAG / State Machine / Event Bus，无限膨胀
Convention      △ 过弱——听起来像 Coding Style，撑不起 Context 生命周期、Handoff、Boundary 这类契约
Specification   ✅ 恰好——用 MUST/SHOULD/MAY 定义可核验的行为契约，不绑定实现
```

## 2. What ACRS Is NOT —— ACRS 不是什么

ACRS **不是**：

- NOT a Runtime（不是运行时）
- NOT a Framework（不是 AutoGen / CrewAI / LangGraph 式框架）
- NOT an SDK
- NOT an Agent Engine / Scheduler / State Machine Platform
- NOT a replacement of JoyCode（不替代、不修改 JoyCode）

**判据**：一旦把 ACRS 当成 Runtime，讨论就会滑向 Scheduler、DAG、Memory、Event Bus、Router——然后无限膨胀。这正是本规范要避免的失败模式。我们逃离"胖总控"，绝不能一头栽进"胖 Spec"。

### 2.1 State Machine 是 Spec，Runtime 才是实现

ACRS 冻结的术语（Task / Route / Spawn / Archive / Boundary …）已构成一台**生命周期状态机**。这**不违反** "NOT a Runtime"——关键区分：

| | 内容 | 归属 |
| --- | --- | --- |
| **规范做的** | 状态机作为**契约**：规定合法状态与合法转换（`Task MUST 经 Created→Running→Done→Closed`）。类比：TCP 规范里有状态机，但它不是 TCP 实现。 | WHAT，Spec |
| **规范不做的** | 用引擎**强制**这些转换（带 `while` / 事件总线 / 调度器的 Runtime） | HOW，Runtime，禁止 |

> 在 JoyCode 上，这台状态机由 `Orchestrator prompt(P3) + MCP ledger 状态(P4) + Boundary` 承载，**不新增引擎**。RFC-001 起写的是**状态契约**，不是 Prompt，也不是 Scheduler 实现。

## 3. Reality —— JoyCode 平台原语（地基）

ACRS 建立在 JoyCode 当前暴露的四种原语之上，不假设第五种。

| # | Primitive | 说明 |
| --- | --- | --- |
| **P1** | **Conversation / Context** | 多轮上下文，由平台管理。**跨上下文不共享对话历史。** |
| **P2** | **Agent** | prompt + model，经 `Agent` 工具派发，运行在**隔离的独立上下文**中；子 Agent **不继承父对话**，仅共享文件系统 / MCP。 |
| **P3** | **Skill** | 经 `Skill` 工具加载的知识/能力包，支持渐进披露。 |
| **P4** | **Tool / MCP** | 文件操作、命令执行、外部 MCP，以及可作状态存储的 MCP ledger。 |

> **实测事实（决定 Handoff 与 Context 模型的地基）**：CLI `Agent` 工具的契约表明——子 Agent 是近乎全新的上下文，**不继承父对话**，只共享 cwd 文件系统与 MCP ledger，回传是一段**有损摘要**。JoyCode APP 的子任务继承细节尚待 Platform Binding（RFC-006）确认。

## 4. Core Principles —— 核心原则（已冻结）

**P-1 Platform First．** 任何定义先满足 P1–P4 现实；映射不到的显式标 `[Aspirational — 平台不支持]`，且**不得**在其上继续设计下游能力。

**P-2 APP/CLI Compatibility（与 Platform First 同级）．** ACRS 只定义**一套** Convention；APP 与 CLI 是它的**两种 Boundary 配置**。一个定义合法，当且仅当它在两种配置下都有合法实现——**但实现本身可以不同**（这正是 Boundary 的意义，不构成违规）。

**P-3 Specification defines What, not How．** 规范只写 `Evidence MUST be verifiable before Done`，不写 `必须用 Summarizer Skill / 必须用 MCP`。所有具体强制者（MCP / Human / CI / GitHub Action）属于 **Binding**，不进核心规范。

**P-4 Evidence Driven．** 所有状态流转由客观 Evidence（构建/测试退出码、日志、可核验产物）驱动，**不认 Agent 自述**。

**P-5 Context Economy．** Context 是有限资源，必须最小化占用。多 Agent 的**首要目的是 Context 隔离，其次才是专业分工**。

**P-6 Model Agnostic．** 任何约束不得绑定特定模型；阈值必须写成**相对量**（如"接近当前模型窗口的 X%"），不得硬编码绝对 token 数。

**P-7 Agent = Context Container．** Agent 是 Context Boundary 的实现，不是 Role、不是能力。`Agent exists because Context has boundaries.`

**P-8 Orchestrator routes, not implements．** Orchestrator 只做路由决策（Route），不承载任何业务逻辑（Java / SQL / Review 都在被 Route 到的 Agent 里）。

**P-9 Handoff is the only cross-context transfer．** 跨上下文状态传递**只能**经 Handoff Package；**禁止**依赖聊天历史、隐式上下文继承、模型"自己记得"。（此约束是 P1/P2 平台事实的规范编码——它禁止的东西平台本就不支持。）

## 5. 两层文档模型（Portable Core + Platform Binding）

ACRS 分两层，保证"可移植"与"即时可用"兼得：

1. **Core Spec（可移植层）** —— RFC-000 ~ RFC-005。只写平台无关的 WHAT。可搬到 Claude Code / Cline / Cursor 等任意平台。
2. **Platform Binding（RFC-006，随平台演进层）** —— 只做 Mapping，且**兼作"合规缺口登记表"**：凡 JoyCode 满足不了的核心 MUST，必须在此登记（如"APP 人肉 Boundary 无硬拒绝机制"）。核心 RFC **一行不改**即可换平台。

## 6. Conformance —— 合规判据（本规范长牙齿的地方）

> 规范中每一条 `MUST` 都**必须**配一条**可观测的 conformance 判据**，否则它就是"漂亮但没人执行的建议书"。

关键判据（细节见 RFC-005）：

- **Done Gate 判据**：一个合规的 Boundary，**必须存在会被它拒绝的 evidence 状态**。一个永远说不出 NO 的 Boundary 是**不合规**的。
- Boundary 验证时**必须解引用** Evidence Index（打开 `test.log` 看它非空、看 exit code），**拒绝解不开或解开为空的引用**——路径本身不是证据。

## 7. RFC Roadmap —— 规范编排

| RFC | 主题 | 冻结内容 |
| --- | --- | --- |
| **RFC-000** | Scope | 定位、边界、原则（本文） |
| **RFC-000A** | Terminology | 术语冻结（含 `1 Agent Instance = 1 Context`） |
| **RFC-001** | Runtime Lifecycle | Task / Agent Instance / Context 三层生命周期 + Spawn/Continue/Archive + Handoff Trigger（何时交接） |
| **RFC-002** | Handoff Protocol | Handoff Package / Evidence Index / Constraints / Workspace Snapshot |
| **RFC-003** | Loop Convention | 单 Agent 内 Observe → Plan → Act → Verify |
| **RFC-004** | Skill Convention | Skill 组织、加载;Workflow(SOP Convention)的书写与挂载 |
| **RFC-005** | Evidence & Boundary | Done Gate、Evidence Index、conformance 判据 |
| **RFC-006** | Platform Binding | ACRS → JoyCode 映射 + 合规缺口登记表 |

**运行时时序即编排顺序**：先有 Context、有办法把状态灌进去（Handoff），Agent 才在其中 Loop。故 Context → Handoff → Loop。

## 8. Keywords

本规范中 **MUST / MUST NOT / SHOULD / SHOULD NOT / MAY** 按 RFC 2119 解释。

---

*RFC-000 v1.0 — 定位已冻结。后续 RFC 是对已冻结概念的展开，不是重新设计。*
