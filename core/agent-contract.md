# ACRS Core — Agent Contract（Agent 契约 Schema）

> **Layer**: Core（平台无关）。
> **Status**: Draft v0.2。
> **依赖**: RFC-000A（术语）、RFC-001（Runtime Lifecycle）。
> **验证依据**: RI-BUGFIX-001（findings A-1 / A-2 / B-1）；case-000#F-002（Admission Review 2026-09-23，`docs/review/2026-09-23-core-admission-review.md`）。

本文件回答一个、且只回答一个问题：

> **一个 Agent Type 在 ACRS 里，是什么？必须满足什么？**

它**不**回答"这个场景该用哪几个 Agent"——那是 Workflow / 领域选择，属于
[Agent Catalog](./agent-catalog.md)（参考目录，可增删），不是 Core。

---

## 1. 为什么 Core 只放 Schema，不放具体角色

ACRS 演化过程中反复出现同一个陷阱：**把"固定角色流水线"当成架构**
（Architect→Backend→Test→Critic 拆分链）。RI-BUGFIX-001 的首要结论正好推翻它：

> **A-1**：bugfix「定位→根因→补丁→回归」全在单个 Worker Context 内连贯完成，
> **没派 Architect**，就是更优解。

如果把 `Architect Agent` 冻进 Core，等于给"每次都走一遍 Architect"发了一张架构级许可证。
所以 Core 的边界是：

| 进 Core（平台无关 + 已被 RI 验证） | 降级为 Catalog（Workflow/领域选择，可增删） |
| --- | --- |
| ① Agent 契约 **Schema**（本文件 §2） | Backend Agent |
| ② 不变量：**独立验证者**（本文件 §3） | Architect Agent |
| | Review Agent |
| | Test Agent |

判据（沿用 RFC-000A 术语准入规则）：**能画进 Runtime Sequence Diagram 的箭头行为**才是 Core；
**"这一步派谁"**是实例选择，属 Binding/Workflow。

---

## 2. Agent Contract Schema（五段式）

一个 Agent Type 的定义 **MUST** 由且仅由以下五段构成。Prompt 是本 Schema 在某平台的
*渲染结果*（Binding），不是 Schema 本身——见 RFC-000 两层模型。

```yaml
agent_type: <name>          # 稳定标识，跨平台一致（如 worker / reviewer）
responsibilities:           # 它在一个 Context 内负责推进什么。一句话可陈述。
boundary:                   # MUST NOT 清单：它绝不做的事（越权即违约）。
input:                      # 它启动时消费的 Handoff Package 字段（承 RFC-002 WHAT）。
output:                     # 它进入 Waiting-Handoff 时冻结产出的字段。
handoff:                    # 它把控制权交给谁、附带哪些 Evidence 引用。
```

### 2.1 各段约束

- **responsibilities**：描述"在**一个** Context 内连贯完成什么"。若一句话说不清、
  需要跨多个认知域，说明它该被拆成多个 Agent Type，或该 Spawn。
- **boundary**：**MUST** 是 `MUST NOT` 清单，不是"建议"。越过 boundary = 契约违反，
  Boundary（Done Gate）有权拒收其产物。
- **input** / **output**：只引用 **Handoff Package 字段名**，不内联正文。
  一个 Agent 拿到的全部输入 = 它的 Handoff Package + 共享文件系统 + Tool/MCP（P-9）。
  **MUST NOT** 假设能读到父对话 / 上一个 Agent 的自述。
- **handoff**：产出**引用**（路径 + 退出码 + 一行摘要），不产出对话正文。
  `test_log_ref` 之类的引用 **MUST** 真实可解、含退出码。

### 2.2 Schema 之外没有别的 Agent 属性

Agent Type **MUST NOT** 携带：模型选择、Prompt 全文、Skill 加载清单、平台调用方式。
这些都是 Binding。理由：`Backend Agent` 的**契约**在 JoyCode / Claude Code / Cursor 上应完全一致，
变的只是它在各平台怎么被渲染和调用。

---

## 3. Core 不变量：独立验证者（The Independent Verifier）

这是 Core 关于"多 Agent 协作"的全部强制条款（INV-VERIFY + INV-INPUT）。其余组合方式
（几个 Agent、什么顺序）都是 Workflow 选择。

> **INV-VERIFY（MUST）**：产出某项 Evidence 的 Agent Instance，
> **MUST NOT** 是对该 Evidence 做验收判定的 Agent Instance。
> 验证 **MUST** 发生在一个**独立、隔离的 Context** 里，且验证者**独立重取客观信号**
> （如独立重跑测试拿自己的退出码），不得以被验者的自述为准。

**为什么是不变量而非建议**：RI-BUGFIX-001（A-2）实测——Reviewer 看不到 Worker 自述，
只拿 Evidence 引用并**独立重跑**。"自己改的不能自己验"从口号变成了可观测的物理隔离事实。
这是 ACRS 相对"单 Prompt 自证"的核心价值，因此升为 MUST。

**这条不变量约束的是"隔离与独立取证"，不约束"验证者叫什么"**。
它可以是 Reviewer、可以是 Test Agent、可以是一次独立的 CI ——具体是谁，属 Binding/Workflow。

> **INV-INPUT（MUST）**：验证者实例的输入（Handoff Package）**MUST NOT** 携带任何
> 关于被验产物的上游验收结论（"已确认 / 全部落地"类断言）；上游的倾向性观察只能以
> **待核验清单**形态进入，验证者一律按待验证假设处理。
>
> **为什么升 MUST**：case-000#F-002（评审喂答案污染，2 次独立暴露）+ RI-BUGFIX-002 CLI
> 弱隔离旁证（`reference/joycode/bugfix-reject/cli-binding/PORTABILITY.md`：验证者记忆含
> 产出者全部改动时盲验退化）——验证者输入被污染时，INV-VERIFY 的隔离形同虚设。
> 经 RFC-000B Admission Review（2026-09-23）Admitted。操作形态（如何措辞任务书、倾向
> 如何转待核验清单）留在 Convention（acrs-shared R5 / acrs-critic §〇），不随迁。

### 3.1 与 Boundary 的关系

INV-VERIFY 保证"存在一个独立验证者"；Boundary（Done Gate，见 RFC-005）保证
"验证者的判定被真正采信、不可验证的证据被拒收"。两者配合，缺一不可：
- 只有独立验证者、没有 Boundary → 验证结果可能被忽略。
- 只有 Boundary、没有独立验证者 → Boundary 在核验一份自证的证据（无隔离）。

---

## 4. 一致性检查（Conformance）

一个自称遵循 ACRS 的实现，其 Agent 定义 **MUST** 满足：

1. 每个 Agent Type 的定义可被归约成 §2 的五段式（多一段、少一段都不合规）。
2. 至少存在一对 (producer, verifier) 满足 §3 INV-VERIFY，且它们是**不同 Instance / 不同 Context**。
3. 不存在"某 Agent 既产出又对自己产出做终审判定"的路径——若存在，即违反 INV-VERIFY。
4. Core 层文档中**不出现**具体角色作为强制项；具体角色只出现在 Catalog / Binding。
5. 验证者实例的输入包**不含**上游验收结论性断言——存在即证伪（INV-INPUT）。

> 判据 4 是本文件的自检：如果哪天有人往 Core 里加了 `Architect MUST ...`，
> 就是又把流水线焊死了——RI-001 的 A-1 就是用来提醒这件事的实证。
