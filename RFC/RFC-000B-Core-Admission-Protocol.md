# RFC-000B: Core Admission Protocol（Core 准入协议）

| 字段 | 值 |
| --- | --- |
| **Status** | **Active (v1.0)** — 治理元契约，自应用之日起生效（首个应用案例见 RFC-001 重标注） |
| **Version** | 1.0 |
| **Created** | 2026-09-22 |
| **Depends on** | RFC-000（P-3 / P-4 / §5 两层模型）、PRINCIPLES（P7 / P8） |
| **性质** | 治理元契约：定义**一条规则如何进入 Core RFC**与**RFC 如何升版**。不定义任何运行时行为（P-3）。 |

> **要解决的问题**：PRINCIPLES P8 承诺了 Core 准入标准（"MUST 有 RI 实证"），但 RFC 侧此前没有对应的接受协议——
> B·Promoted 候选（如 case-000 F-002/F-003/F-004）攒够资格却无处落籍。本协议补上这条通路。

---

## 1. RFC 状态机与版本规则

```
Draft → Frozen Candidate → Frozen
```

| 状态 | 含义 | 修改门槛 |
| --- | --- | --- |
| **Draft** | 自由修订 | 无 |
| **Frozen Candidate** | 结构冻结，接受实证标注（§2）与增补（§3） | 须走 §3 Admission 或标注更新 |
| **Frozen** | 条款生效 | 同上；**推翻既有条款 = 写新 RFC supersede，不原地改写** |

**版本规则**：澄清性编辑（不改语义）不升版、记变更记录；新增 MUST/SHOULD 条款升 +0.1；推翻既有条款禁止单文内完成。

---

## 2. Evidence Status（节级实证标注）

Frozen Candidate 及以上的 RFC，其每条 MUST 所属节**必须**携带以下标注之一：

| 标注 | 含义 |
| --- | --- |
| `[Derived]` | 由已冻结条款推导成立，尚未实证 |
| `[Validated @ <RI/case 编号>]` | 已由真实运行实证，编号必须可解引用到 findings 文件 |

**整篇转 Frozen 的条件**：全部 Conformance 判据节各有 ≥1 次实证（`[Validated]`）。

---

## 3. Core Admission Review（五步，逐条过）

**候选来源**：validation findings 终态 **B·Promoted**（≥2 次独立暴露）。

```
P8 契约级？ → Evidence 可解引用？ → 平台无关 WHAT？ → Core boundary？ → Admission Decision
```

1. **P8**：新增的是契约级能力，还是仅 Prompt 措辞？措辞差异 → 不进 Core。
2. **Evidence**：findings/RI 编号真实存在且可解引用（打开文件核验，P-4）。
3. **Cross-platform WHAT**：换任何平台（含人类团队）是否同样犯此缺陷？平台相关 → 回 Binding/Convention。
4. **Core boundary**：只写行为不写 HOW（P-3）；能画进 Runtime Sequence Diagram 的箭头才进（RFC-000A 术语准入铁律同源）。
5. **Decision**：三态——`Admitted`（进 RFC，条款脚注保留 Findings→RFC 证据链）/ `Deferred`（**必须写明触发条件**）/ `Rejected`（回 Convention 固化，写明理由）。

**独立性（承 PRINCIPLES P7）**：Admission Review 的评审者不得是产出该 findings 的同一实例单方拍板。

**登记格式**（评审前）：

| Finding | RI/独立暴露 | Convention 稳定 | 平台无关 WHAT | Core 决策 |
| --- | --- | --- | --- | --- |
| F-xxx | ≥2 ✓ | ✓ | 待审 | Pending |

---

## 4. 铁律

1. **增补，不重写**（manifesto 自我承诺：可演进不需推翻）。
2. **实证准入，禁推演立法**——每条 Admitted 增补必须引用 findings 编号，证据链全程可回溯：`RFC 条款 → Admission 表 → case findings → 真实生产问题`。
3. **有资格 ≠ 现在就进**——Admission Review 与"批次合入"分离，Pending 候选不默认批量晋升。
4. **RFC 不吸收 HOW**——五类扫描 / grilling / 探针等操作细节永远留在 Convention 层（P-3 违者即胖 Spec 复活）。

---
## 5. 当前 Pending 登记

| Finding | 独立暴露 | Convention 固化位置 | 目标 RFC | Core 决策 |
| --- | --- | --- | --- | --- |
| F-002 评审喂答案污染 | 2 | acrs-shared R5 等 | agent-contract §3 | Pending（待协议经一次真实闭环验证后逐条 Review） |
| F-003 需求没问清白做 | 2 | acrs-shared R10 等 | RFC-001 | Pending（同上） |
| F-004 bugfix 拆分链修不到位 | 2 | acrs-orchestrator 连贯性密度 | agent-catalog | Pending（同上） |
| case-004#F-001 系统边界输入验证缺失（source 校验遗漏致脏数据不可自愈） | 1（深度证据：代码+集成测试复现+不可自愈闭环） | 项目侧修复；Convention 侧暂无固化（G-CLARIFY 五类扫描含边界但未操作化到此粒度） | 待 Review 定位（候选 agent-contract / 校验不变量） | Pending（**首个真实闭环产生的候选**，未达 ≥2 门槛，按证据质量登记；Admission Review 时独立判定） |

---

*RFC-000B v1.0 — Active。本协议的修订自身同样受 §4 铁律约束。*
