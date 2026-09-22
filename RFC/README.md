# RFC/ — ACRS 协议层（L1 Core）

> 本目录回答一个问题：**ACRS 的规则本身是什么？**
> 这里是全仓库的权威源头——`core/`、`skills/`、`bindings/` 的任何行为规范都能回链到这里的某份 RFC。
> 改动需走 RI 实证（见 `PRINCIPLES.md`），不允许"发现问题就直接改"；**新条款准入与升版一律走 RFC-000B 协议**。

## 文档清单
| 文档 | 主题 | 状态 |
| --- | --- | --- |
| [RFC-000-Scope.md](RFC-000-Scope.md) | 范围与边界：ACRS 管什么、不管什么 | Draft — Frozen Candidate |
| [RFC-000-architecture-manifesto.md](RFC-000-architecture-manifesto.md) | 架构宣言：四层模型与"Entry Adapter"主张（历史邀评稿） | Draft (RFC) |
| [RFC-000A-Terminology.md](RFC-000A-Terminology.md) | 术语冻结：Context/Handoff/Evidence/Boundary 等动词的唯一定义 | **Frozen (v1.0)** |
| [RFC-000B-Core-Admission-Protocol.md](RFC-000B-Core-Admission-Protocol.md) | Core 准入协议：条款如何进入 Core、RFC 如何升版 | **Active (v1.0)** |
| [RFC-001-Runtime-Lifecycle.md](RFC-001-Runtime-Lifecycle.md) | 运行时生命周期：任务从进 Context 到 Handoff 的状态机 | **Frozen Candidate (v0.2)**——已逐节标注实证，转 Frozen 差 §8 判据 1/3 |
| [runtime-sequence.md](runtime-sequence.md) | 运行时序图：RFC-000A 术语的"单元测试"（箭头画不出=术语有洞） | Draft |

规划槽位（未写）：RFC-002 Handoff Package（WHAT）、RFC-003 Loop、RFC-004 Skill、RFC-005 Evidence & Boundary。
**RFC-002 触发条件**（RFC-000B §4：禁为假想需求立法）：下一次真实 Handoff 溢出续跑 case 出现，或现存悬空引用（acrs-shared R2、root-prompt 的"RFC-002 落地后回填"）造成实际误读时启动。

## 阅读顺序建议
1. `RFC-000-Scope.md` → 搞清边界
2. `RFC-000A-Terminology.md` → 术语是后续一切的地基（唯一已冻结）
3. `RFC-001-Runtime-Lifecycle.md` → 动词环如何落地成生命周期
4. `runtime-sequence.md` → 用一张图验收术语完备性
5. `RFC-000B-Core-Admission-Protocol.md` → 改 RFC 前必读的准入流程

## 三套原则编号对照表

仓库存在三套"P 编号"，**同名不同义**，引用时 MUST 用全限定（如 `RFC-000 P-4`，禁裸写 `P4`）：

| 语义 | PRINCIPLES.md（治理层铁律） | RFC-000 §4（Scope 原则） | manifesto §6（历史邀评稿） |
| --- | --- | --- | --- |
| 平台现实优先 | — | **P-1** Platform First | Principle 1（同义前身） |
| 只写 WHAT 不写 HOW | **P3** Behavior > Implementation | **P-3** Specification defines What, not How | — |
| 客观证据驱动 | **P7**（验收侧：INV-VERIFY） | **P-4** Evidence Driven | Principle 4（同义前身） |
| Context 经济 | **P5**（1 实例=1 Context 侧面） | **P-5** Context Economy | Principle 5（同义前身） |
| 模型无关 | — | **P-6** Model Agnostic | Principle 6（同义前身） |
| Agent=Context 容器 | **P5** One Instance, One Context | **P-7** Agent = Context Container | —（并入 Principle 5 语义） |
| 跨上下文只走 Handoff | **P6** Everything by Handoff | **P-9** Handoff is the only cross-context transfer | — |
| Orchestrator 只路由 | — | **P-8** Orchestrator routes, not implements | — |
| APP/CLI 一套规范 | — | **P-2** APP/CLI Compatibility | Principle 3（控制权归属前身） |
| Core/Binding 分层 | **P1** Core > Binding | §5 两层模型 | — |
| Convention > Prompt | **P2** Convention > Prompt | — | — |
| 薄入口+激活 | **P4** Thin Entry, Focused Skills | — | — |
| 赚得抽象（元规则） | **P8** Earn Every Abstraction | — | — |
| Skill 是重构产物 | **P9** Skills 是重构的产物 | — | — |
| Simple First | — | —（**断链待处理**：RFC-001 §7 引用"RFC-000 Simple First"，但 RFC-000 无此编号条目；语义存于 manifesto Principle 2） | Principle 2 |
| Agent 数量收敛 | — | — | Principle 7（被 PRINCIPLES P8/P9 精神收编） |

**关系声明**：PRINCIPLES.md 是现行治理层权威；RFC-000 §4 是规范层原则；manifesto 是历史邀评输入（Status: 邀评稿），已被前两者收编，不再独立演进。
