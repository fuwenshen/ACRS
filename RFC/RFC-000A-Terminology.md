# RFC-000A: Terminology（术语冻结）

| 字段 | 值 |
| --- | --- |
| **Status** | **Frozen (v1.0)** — 经 Runtime Sequence Diagram 验收 |
| **Version** | 1.0 |
| **Created** | 2026-07-29 |
| **Depends on** | RFC-000（Scope） |
| **性质** | 冻结词汇表。定义**名词及其位置（slot）与关系**，**不定义行为**——行为归各自的 home RFC。 |

> **本 RFC 的作用**：让那张一页《Runtime Sequence Diagram》可以**不加任何解释就被所有人看懂**。若画图时某根箭头还需犹豫，说明对应术语未冻结，回到这里补定义。

---

## 0. 术语条目格式

每个术语固定四栏：

- **定义**：它是什么。
- **映射 Primitive**：落到 JoyCode 哪个 P1–P4（接地铁律）。
- **强制者 → Binding**：由谁保证它成立（具体强制者不进核心规范，见 RFC-000 §5，此处只留占位）。
- **关系**：它与其它术语的 owns / consists-of / realizes 关系。

---

## 1. 核心分层不变量（The Layering Invariant）

ACRS 只有**三层 ownership 链**，加一个正交的知识包：

```
Task ── follows ──▶ Workflow          ← Workflow：SOP / 行为 Convention，指导 Orchestrator 的 Route 序列
  │ realized-by（Route 按 Workflow 依次 Spawn + Handoff）
  ├── Agent Instance A ── owns ──▶ Context A   （可 load Skill）
  ├── Agent Instance B ── owns ──▶ Context B
  └── Agent Instance C ── owns ──▶ Context C

Skill                                 ← 正交：加载进单个 Context 的知识包（per-context）
```

**三个角色一句话（贴在图旁，别人读一眼就懂）：**

```
Task     is the lifecycle owner.      —— Task 是生命周期的拥有者
Agent    executes Task.               —— Agent 是执行器（可换，Task 不换）
Context  provides execution memory.   —— Context 是执行内存（1:1 绑定实例）
Workflow prescribes the sequence.     —— Workflow 是 SOP，规定 Route 顺序（Convention，非 primitive）
```

极简纵向关系图：

```
Task
 │ executed by
 ▼
Agent Instance
 │ owns
 ▼
Context
```

> 这张图能解释"为什么 Agent 换了？"——因为 **Task 没换**，换的只是执行它的 Agent Instance（及其 Context）。

**MUST 级不变量：**

> **One Agent Instance owns exactly one Context throughout its lifecycle; a Context is never shared across Agent Instances.**
>
> 一个 Agent Instance 在其整个生命周期内**恰好**绑定一个 Context;Context 不跨 Agent Instance 共享。

**三个概念不许混**（Type ≠ Instance ≠ Context）：

```
Agent (Type)          例：Backend Agent —— 一种 prompt+model+技能配置
   │ create（可并行创建多个）
Agent Instance        例：Backend Agent #1 / #2 / #3
   │ owns（1:1，终生）
Context               例：Context A / B / C
```

**推论（MUST，写入 RFC-001）**：**不存在 Context Refresh。** 当 Context 溢出时，Agent Instance 不能"换一个新 Context 还叫同一个实例"，只能 **Handoff 给一个后继 Agent Instance（新 Context）**。因此：

- 系统只有**一种** Context 切换方式：**Spawn + Handoff**，没有第二种。
- 任务的"连续性"**不在任何 Agent 身上**，而在 **Task + Handoff 链 + Evidence Index** 里。
- 这抬高了 Handoff Protocol（RFC-002）的赌注：它不只承载"换专家"，也承载"同一任务、因溢出换 Context"。

---

## 2. 术语表（Frozen Terms）

### 2.1 上下文与执行

**Task**
- 定义：一个需要被推进到完成的工作单元；系统中**生命周期最长、真正连续**的对象。`Task is the lifecycle owner.`
- 映射：无单一 Primitive；由一串/一树 Agent Instance 经 Spawn+Handoff 实现，其状态落在 Workspace 文件 + MCP ledger（P4）。
- 强制者 → Binding。
- 关系：`Task **follows** Workflow`（SOP）；`Task **realized-by** 多个 Agent Instance`；`Agent executes Task`，Task 本身不换、换的是执行它的 Agent Instance。

**Context**
- 定义：一个 Agent Instance 的运行环境（对话 + 可见文件视图 + 已加载 Skill）。有限资源。
- 映射：**P1 Conversation**。
- 关系：被**恰好一个** Agent Instance owns。

**Agent (Type)**
- 定义：一种可复用的执行器配置 = prompt + model + 默认技能集。
- 映射：**P2 Agent** 的定义侧。
- 关系：可 create 多个 Agent Instance。

**Agent Instance**
- 定义：Agent Type 的一次具体运行；ACRS 里 Agent = **Context Container**，不是 Role、不是能力。
- 映射：**P2 Agent** 的一次派发。
- 关系：owns 恰好一个 Context（终生 1:1）；由 Orchestrator 经 Spawn 创建。

**Orchestrator**
- 定义：只做路由决策的 **Decision Engine**，不承载业务逻辑。职责四件：`Observe → Route → Collect → Finish`。
- 映射：一个特定 Agent Instance（P2）+ 其 prompt（P3，可含 Workflow SOP）+ ledger 读写（P4）。
- 关系：对每个待推进步骤产出一个 Route 结果。
- 约束（MUST，写入 RFC-001）：**`Orchestrator MUST NOT accumulate execution history in its own Context.`** 它**只持 Evidence Index（引用），按需读取**——否则跨 A1→A2→A3 会把全部日志累进自身 Context，多 Agent 省 Context 的收益归零。

### 2.2 决策与流转

**Route**
- 定义：Orchestrator 的核心决策，统一了"选谁"与"是否新起上下文"。返回值三选一：
  - `Continue (Current Context)` —— 留在当前上下文继续；
  - `Spawn <Agent Type>` —— 新起一个专家实例（= 新 Context）；
  - `Finish` —— 任务收敛。
- 映射：Orchestrator prompt（P3）+ ledger 状态（P4）。
- 关系：`Continue` 与 `Spawn` 是 Route 的两个分支，**不是两个独立决策**（避免上一版"Selection 先于 Continue/Spawn"的顺序错位）。

**Spawn**
- 定义：创建一个新 Agent Instance（含新 Context）来承接工作。**每次 Spawn = 一次 Handoff 的发起**。
- 映射：**P2**（`Agent` 工具派发）。
- 触发（MUST 仅一条，其余 SHOULD/MAY，见 RFC-001）：
  - **MUST（正确性驱动）**：需要**独立判断**（如评审）——成本无投票权，再贵也 Spawn。
  - **SHOULD（成本驱动）**：Context 接近窗口上限（相对量，P-6）；或存在**认知冲突的领域**（如 Java + Frontend 同栈污染）。

**Continue**
- 定义：Route 的另一分支——不新起上下文，在当前 Agent Instance 内继续。系统**默认**倾向 Continue（因 Spawn 有重新 brief + 信息断层 + 摘要失真三重成本）。

**Handoff**
- 定义：把状态从一个 Context 转移到另一个 Context 的动作。
- 映射：briefing prompt（P3）+ 共享文件 / ledger（P4）——**永远不能**经继承的对话记忆。
- 关系：由 Handoff Package 承载；是**唯一**合法的跨上下文传递机制（RFC-000 P-9）。

**Handoff Package**
- 定义：一次 Handoff 中显式序列化的状态包。**唯一支持的跨上下文传递载体。**
- 映射：文件 / ledger 条目（P4）+ 注入接收方的 prompt（P3）。
- 结构（骨架，详见 RFC-002）：`task / goal / constraints / workspace snapshot / changed_files / evidence(index) / required_output`。
- 关系：其 `evidence` 字段是 **Evidence Index 的引用**，不是内容内联。

### 2.3 知识与能力

**Skill**
- 定义：加载进某个 Context 的知识/能力包（prompt + knowledge + instruction）。**不是执行上下文**。
- 映射：**P3 Skill**。
- 关系：被 Agent Instance load；Agent 自身即 Skill Router（按类型自带技能集），**不另设全局 Skill Router**。

**Workflow**
- 定义：**一种行为 Convention（SOP）**——描述某类 Task 的期望 **Route 序列**（如 bugfix = `Observe → Backend → Review → Test → Done`；feature = `PRD → Architect → Backend → Review → Test → Done`）。**不是 runtime primitive，不是 worker Skill。**
- 映射：可落地为 **Orchestrator 加载的一个 Skill（P3）**，或直接写在 Orchestrator prompt 里的 Convention。它**不引入执行引擎**（无 Workflow Engine）。
- 强制者 → Binding（Orchestrator 是否严格遵循 SOP，由 Boundary 配置决定）。
- 关系：`Task **follows** Workflow`；Workflow **prescribes** Route 序列，据此 Spawn 出多个 Agent Instance。它**跨多个 Context**（这正是它区别于 Skill 的地方——Skill 是 per-context 的）。
- 边界：具体的 `BugFix Workflow` / `Feature Workflow` 是 Workflow 的**实例**，不是新术语，**不得**为它们扩充词汇表。

**Tool / MCP**
- 定义：外部执行与状态能力（文件、命令、外部 MCP、作状态存储的 ledger）。
- 映射：**P4**。

### 2.4 证据与边界

**Evidence**
- 定义：推进任务的**客观依据**——构建/测试退出码、日志、git diff、可核验产物。系统不认 Agent 自述（RFC-000 P-4）。
- 映射：Workspace / Git / Tool 输出（P4）。

**Evidence Index**
- 定义：Orchestrator 持有的 evidence **引用集合**（如 `test.log`、`git diff`、`review.md` 的路径），**按需读取**，绝不内联内容。取代被删除的 "Evidence Merge"。
- 映射：ledger / 文件路径（P4）。
- 存在理由（MUST 级）：若 Orchestrator 内联 evidence 内容，A1→A2→A3 后其 Context 会累积全部日志——正是多 Agent 想省掉的膨胀，净收益归零。故**只持引用**是多 Agent 真正省 Context 的前提。

**Boundary**
- 定义：负责校验 evidence、决定任务能否推进/收敛的**责任位**。规范只写 Boundary，**不写它是 MCP / Human / CI**（那些是 Binding，RFC-000 P-3）。
- 映射：Binding（RFC-006）。
- 规范语句：`Boundary MUST reject unverifiable evidence.`

**Done Gate**
- 定义：Boundary 在"标记完成"处施加的强制校验点。
- conformance 判据（MUST，RFC-000 §6）：**必须存在会被 Boundary 拒绝的 evidence 状态**；校验时**必须解引用** Evidence Index，拒绝解不开 / 解开为空的引用。一个永不说 NO 的 Done Gate 不合规。

**Archive**
- 定义：Context 生命周期终点——Agent Instance 完成后，其 Context 关闭，产物沉淀为 Evidence（引用留在 Index）。
- 映射：P4（产物落盘 / ledger 记录）。
- 完整生命周期（详见 RFC-001）：`Create → Load Skill → Execute → Evidence → Close → Archive`。

### 2.5 两类循环（作用域不同，禁止混用一个词）

**Worker Loop**
- 定义：单个 Agent Instance 在其 Context 内的**认知循环**：`Observe → Plan → Act → Verify`（→ repeat）。它是 **Prompt Pattern，不是 Engine**——真正循环的是 LLM，不是外部 `while()`。
- 映射：Agent prompt（P3）。
- 关系：在其转换点上可**触发 Route**（是否 Spawn/Handoff）；与 Context 是**正交两轴**（时间轴 vs 空间轴），不分主从。

**Orchestrator Cycle**（别名：Routing Cycle）
- 定义：Orchestrator 的**调度循环**：`Observe → Route → Collect → Next`（→ repeat until Finish）。**它不是认知循环**——Orchestrator 不 Plan、不写代码、不 Verify，只调度。
- 映射：Orchestrator（一个 Agent Instance）的 prompt（P3）+ ledger（P4）。
- 关系：**MUST NOT 叫 Loop**——Loop 在 AI 语境已固定指认知循环，混用会误导。Orchestrator Cycle 的每一圈产出一个 Route 结果。
- 说明：在 Primitive 层 Orchestrator 仍是一个 Agent Instance；在行为层它是 Coordinator-role（跑 Cycle），不是 worker（跑 Loop）。不为此新增 `Coordinator` 原语。

---

## 3. 已删除 / 明确禁止的概念（Deleted & Forbidden — 不得引入）

### 3.1 已删除术语（Deleted）

| 术语 | 删除理由 |
| --- | --- |
| **Capability** | 与 Loop Phase 重复 |
| **Role** | 与 Agent 混淆；Agent 是 Context Container，不是岗位 |
| **Planner / Memory（作为一级原语）** | 前者并入 Loop 的 Plan；后者由 Context + Evidence Index 承担，无需独立原语 |
| **(Skill) Router** | Agent 自身即 Skill Router，另设即两层路由 |
| **Evidence Mart / Store** | 造 Runtime；Evidence 本就在 Workspace/Git/Tool 里 |
| **Evidence Merge** | "Merge 到哪里"无解；改为 Evidence Index（只持引用） |
| **Loop Engine** | Loop 是 Prompt Pattern，无引擎可实现 |
| **Context Refresh** | 违反 `1 Instance = 1 Context`；溢出只走 Spawn+Handoff |
| **Execution Strategy（作为凌驾抽象）** | 收敛为 Route 的分支，不单列 |
| **Workflow Engine** | Workflow 是 Convention/SOP，不引入执行引擎 |

### 3.2 明确禁止的概念（Forbidden — MUST NOT）

> **`Shared Context` / `Global Context` MUST NOT exist.**
>
> 多个 Agent Instance **禁止**共用一个 Context（这是 §1 `1 Instance = 1 Context` 不变量的直接推论）。当有人问"能不能几个 Agent 共用一个 Context？"——规范的回答是 **NO**。
>
> **唯一可跨上下文共享的是**：`Workspace / Task / Evidence / Git`。**Context 永远不共享。**

---

## 4. 变更记录 — Workflow 定位（v0.1 → v1.0）

**v0.1（曾提议，已推翻）**：把 Workflow 并入 Skill、不设 Workflow 概念。

**v1.0（本版，已修正）**：**保留 Workflow 为术语，降级为 Convention（SOP）**，而非 Skill、非 primitive。

**修正理由（范畴差异）**：Skill 是加载进**单个** Context 的知识（per-context）；Workflow 描述的是**跨多个** Agent Instance 的 Route 序列（Backend→Review→Test）。二者作用域不同，不能合并。BugFix SOP 与 Feature SOP 不同、而 Task 概念相同——恰证明 Workflow 是 SOP 而非 Skill。定义见 §2.3。

**边界守则（沿用评审建议的准则）**：任何新增内容都要先回答"**它是新概念，还是已有概念的实例？**"——`BugFix Workflow` / `Feature Workflow` 是 Workflow 的**实例**，不扩充术语。

---

*RFC-000A v1.0 — **Frozen**（经 Runtime Sequence Diagram 验收）。*

> **术语准入铁律（Frozen 之后生效）**：任何新增术语,**必须能被画进 Runtime Sequence Diagram**(用已冻结术语标注其箭头)。画不进,就不新增。这条规则本身取代了"讨论要不要加某个词"——用画图代替争论。
