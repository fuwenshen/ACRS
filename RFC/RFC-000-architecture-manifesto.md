# RFC-000: AI Coding Architecture Manifesto

| 字段 | 值 |
| --- | --- |
| **Status** | Draft — Request For Comments |
| **Version** | 0.1 |
| **Created** | 2026-07-29 |
| **Supersedes** | diy-orc V1（保留其实测经验，不推翻） |
| **决策性质** | 本 RFC 只定**方向与边界**，不定 Workflow/Role/Prompt 的具体形态 |

> **一句话边界（本规范的宪法）**
> 本规范不是为了构建一个通用 Multi-Agent Framework，而是为了在 **JoyCode APP 与 JoyCode CLI** 两种运行模式下，建立一套**统一、可演进、可验证**的 AI Coding 架构。任何脱离 JoyCode 场景的能力扩张，都不在本规范范围内。

---

## 1. Why — 为什么需要这份 RFC

过去一年，AI Coding 的组织方式经历了三代演进：Prompt Engineering → Skill（知识沉淀）→ Multi-Agent（角色分工）。与此同时，Cursor、Claude Code、Codex、Cline、JoyCode 各自走了不同的路线：有的押注单上下文连续执行，有的押注 GUI 编程体验，有的押注 Tool-first 的自主循环。

但至今**没有任何一种架构，能同时统一** GUI、CLI、Workflow、Multi-Agent 与 Human-in-Loop 这五件事。每一种产品都在某个象限很强，在另一个象限失效。

本 RFC 不试图发明一个新框架，而是提出一个问题并邀请对撞：

> **下一代 AI Coding 架构，在 JoyCode 这个具体平台上，应该长成什么样？**

## 2. Problem — 三代方案各自的边界（含实测证据）

这不是纸面推演。本项目在 diy-orc V1（一套总控 Opus 调度 Architect / Backend / Test / Critic、用 MCP 强制状态机与接地校验的编排体系）上跑了数月，得到了可复现的观察：

| 代际 | 优点 | 缺点 |
| --- | --- | --- |
| **Prompt** | 简单、连续、上下文完整 | Prompt 无限膨胀，不可维护 |
| **Skill** | 知识可沉淀，Prompt 可维护 | Context 仍持续增长 |
| **Multi-Agent** | 上下文隔离、职责清晰、可按能力分配强弱模型 | **连续推理被切碎**；中小需求与 BugFix 质量下降、Token 上升 |
| **CLI（单上下文自主）** | 连续推理、Autonomous、BugFix 效果优秀 | 治理/约束能力弱，缺少可验证的质量闸门 |

### 2.1 两个决定性的实测案例

本 RFC 的核心动因来自两次"编排反而更差"的真实事件：

- **案例 A — 库存入库/出库逻辑（中等复杂度）**：走完整 `Architect → Backend → Test → Critic` 流程后，结果是"逻辑都写了，但不够顺畅、边界覆盖有洞"。改用**单一连续上下文的规约编程 / 直接 skill**，一次做到位。
- **案例 B — 一次 BugFix**：走编排链，花费大量 Token，效果仍不理想，根因始终漂移；改用**单一连续上下文**直接定位并修复到位。

### 2.2 从案例中提炼的根因

两个案例指向同一个结论，且它**不是** "Agent 不够聪明" 或 "设计没写细"：

> **问题是抽象层级错配。** 现有体系只提供两档——"拆分成多 Agent 流水线"或"退回人工"，缺少"**不拆、但由 AI 在连续上下文里自动做透**"这一档。中等复杂度、且需要连贯实现的任务（BugFix、中小 Feature）恰好掉进这个空洞：拆开则连贯性碎裂，不拆则无自动化路径。

**结论：没有任何单一方案能覆盖全部研发场景。真正决定效果的，不是用哪个 Agent，而是对某一类任务选择了哪种执行策略。**

## 3. Reality — JoyCode 平台约束（本 RFC 的地基）

本项目**不是**重新发明 Agent Framework，而是在 JoyCode 之上重新设计 AI Coding。因此必须先诚实地承认：JoyCode 当前只暴露**四种原语**。

| # | Primitive | 说明 |
| --- | --- | --- |
| P1 | **Conversation** | 多轮对话与上下文管理，由平台提供 |
| P2 | **Agent** | prompt + model，经 `Agent` 工具派发，运行在**隔离的独立上下文**中 |
| P3 | **Skill** | 经 `Skill` 工具加载，支持渐进式披露（progressive disclosure） |
| P4 | **Tool / MCP** | 文件操作、命令执行、外部 MCP 工具、以及可用作状态存储的 MCP ledger |

**Workflow、Execution Engine、Runtime、Control Loop 都不是平台原语。** 它们属于 *Architecture*，不属于 *Platform*。

### 3.1 接地铁律（Grounding Rule）— 强制约束

> 本规范中每一个抽象（Workflow / Role / Execution Strategy / Control Loop / Runtime …），**必须注明它由上述哪个/哪些 Primitive 实现**。凡是当前无法映射到 P1–P4 的，**必须显式标记 `[Aspirational — 平台不支持]`**，并且**不得**在其上继续设计依赖它的下游能力。

这条铁律的目的只有一个：**防止这份 RFC 本身变成新一轮的过度抽象**。我们逃离"胖总控"，绝不能一头栽进"胖 Spec"——一份 JoyCode 跑不起来的漂亮架构，会让所有评审者围着空气讨论。

## 4. Goals — 目标

建立一套统一 APP 与 CLI 的 AI Coding 架构，满足：

1. **Model Agnostic** — 不绑定任何单一模型；
2. **Agent 无关** — Agent 是可替换的执行器，不是架构的中心；
3. **Workflow 可替换** — 流程是扩展点，可增删而不动核心；
4. **Skill 可复用** — 领域知识作为长期资产沉淀；
5. **可持续演进** — 随模型能力增强而自然收敛，不需推翻重来；
6. **可验证** — 状态由 Evidence 驱动，而非 Agent 自述。

## 5. Non-Goals — 明确不做

- 不做 AutoGen / CrewAI / LangGraph 式的通用 Multi-Agent Framework；
- 不解决 JoyCode 场景之外的编排问题；
- 不追求"Agent 数量"的扩张（见 Principle 7）；
- 本 RFC 不定稿任何 Workflow、Role 或 Prompt 的具体内容。

## 6. Design Principles — 设计原则（待评审）

**Principle 1 — Platform First．** 任何设计先满足 JoyCode 的四原语现实；无法落地者标记 `[Aspirational]`。

**Principle 2 — Simple First．** 默认选择能解决问题的最简结构，复杂度只在被证明必要时才增加（对齐 Anthropic《Building Effective Agents》）。

**Principle 3 — Human-in-Loop 是控制权差异，不是两套架构．** APP 与 CLI 共享同一套 Workflow 与 Skill；二者唯一的本质区别是：**"推进到下一步"的继续键握在人手里（APP，闸门控）还是 AI 手里（CLI，自主）**。因此执行模型的核心变量不是"顺序 vs 并行"，而是"收敛循环的控制权归属"。

**Principle 4 — Evidence Driven．** 所有状态流转由客观 Evidence（构建/测试退出码、日志、可核验产物）驱动，不认 Agent 的自我陈述。

**Principle 5 — Context Economy．** Context 是有限资源，必须最小化占用；这也是 Skill 渐进披露与上下文隔离存在的理由。

**Principle 6 — Model Agnostic．** 任何 Workflow 不得绑定某一特定模型；强弱模型分配是策略，不是架构。

**Principle 7 — Capability over Agent．** 长期看 Agent 数量应收敛（建议 ≤ 4：如 Planner / Executor / Reviewer / Consultant），真正持续增长的是 Skill（领域能力）与 Workflow（生命周期），而非 Agent 角色。

## 7. Open Questions — 开放问题（评审核心）

以下问题**本 RFC 不作结论**，正是邀请对撞的焦点：

- **Q1 — 控制模型**：核心应是一次性的 **Workflow（流水线）**，还是 K8s Controller 式的 **Control Loop（Desired State ⇄ Current State ⇄ Reconcile）**？还是二者嵌套（Reconcile 为外层控制、Workflow 为期望态模板）？
- **Q2 — Runtime**：是否应把 "Runtime" 提为核心抽象，还是它只是若干 Skill + 总控 prose + MCP 状态的组合别名？
- **Q3 — 角色抽象**：Role 应继续按"人的岗位"划分（Architect / Backend / Reviewer），还是按"任务生命周期"划分（Plan / Execute / Verify）？
- **Q4 — BugFix 默认路径**：默认 Single Context，还是默认 Workflow？何种条件下才升级为多 Agent 拆分？
- **Q5 — APP/CLI 统一**：如何让 Workflow 对"运行在 APP 还是 CLI"完全无感（见 Principle 3）？
- **Q6 — Workflow 是否声明式**：Workflow 应是声明式（描述期望态）还是命令式（描述步骤）？
- **Q7 — Execution Strategy 是否一级抽象**："按任务类型选择执行策略"是否应成为第一等公民，凌驾于 Workflow 与 Role 之上？
- **Q8 — 演进方向**：随着模型持续增强，本架构如何演进而不被推翻？哪些抽象会自然消亡？
- **Q9 —（本项目最痛的敞口）线外任务缺可测收敛判据**：接地哲学依赖客观退出码，但**设计/评审这类"线外"产物没有退出码**。无论选 Workflow 还是 Control Loop，都无法凭空为它们提供可验证的收敛判据——此时质量只能退回主观评审（且必须由**独立上下文**做，自评=盖章）。**请评审者正面回应：这个敞口应被接受、被显式建模、还是有第三条路？**

## 8. Future Direction — 一个候选模型（未定稿）

当前提出一个**候选**分层，仅供 Challenge，不作结论：

```
Task
  ↓
Task Classification      （分诊：风险 + 连贯性密度）
  ↓
Execution Strategy       （选择：单上下文 / Workflow / 多 Agent）
  ↓
Control Loop             （Reconcile：Desired ⇄ Current ⇄ 收敛）  [Aspirational — 需映射到 Agent 循环 + MCP 状态]
  ↓
Workflow                 （生命周期模板）                          [由 Skill 实现]
  ↓
Role                     （Planner / Executor / Reviewer …）        [由 Agent 实现]
  ↓
Skill                    （领域知识资产）                          [Primitive P3]
  ↓
Tool / MCP               （执行与状态）                            [Primitive P4]
```

注意其中的 `[…]` 标注：这正是 §3.1 接地铁律的应用示范——每一层都必须能落到一个 Primitive，落不了的显式标为 Aspirational。

## 9. Review Request — 评审请求

请评审的是 **Architecture**，**不是** Prompt、不是 Workflow、不是 Agent。重点关注：

1. 抽象层级是否合理？
2. 是否能落地到 JoyCode 的四原语（§3）？
3. APP 与 CLI 是否真被统一？
4. 是否存在过度设计？
5. 是否遗漏了核心概念？

### 9.1 Review Guide — 反馈模板（请勿直接给方案，按此模板作答）

```
Review Result
1. 最大的优点：
2. 最大的风险：
3. 最大的遗漏：
4. 是否存在过度设计（是/否 + 具体指出哪一处）：
5. 哪些抽象应该删除：
6. 哪些抽象应该新增：
7. 是否符合 JoyCode Reality（§3 四原语 + 接地铁律）：
8. 如果重新设计：你会保留什么？推翻什么？为什么？
```

### 9.2 评审分工建议

不让所有模型泛泛点评全文，而是按风格分配侧重问题：

| AI | 侧重问题 |
| --- | --- |
| **Claude Opus** | 架构抽象、设计原则、长期演进（Q2 / Q8） |
| **GPT-5.5** | 系统架构、边界划分、产品约束、可演进性（Q5 / Q7） |
| **Gemini** | Workflow、工程化、平台落地（Q4 / Q6） |
| **DeepSeek** | 成本、国产模型适配、Prompt 与 Skill 设计（Principle 6 / Q3） |
| **Grok** | 挑战假设、寻找反例、指出过度设计（Q1 / Q9 + Review Guide #4） |

---

*本 RFC 为 Draft 0.1，一切结论待评审对撞后进入 RFC-001（Platform Constraints）起细化。*
