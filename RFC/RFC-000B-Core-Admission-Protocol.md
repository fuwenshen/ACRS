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
## 5. Admission 决策登记（首次 Review 完成 2026-09-23，报告 `docs/review/2026-09-23-core-admission-review.md`，评审者独立实例）

| Finding | 独立暴露 | Convention 固化位置 | 目标 RFC | Core 决策 |
| --- | --- | --- | --- | --- |
| F-002 评审喂答案污染 | 2（case-000 回溯 + PORTABILITY 独立实测） | acrs-shared R5 等 | agent-contract §3 | **Admitted（2026-09-23）**：INV-INPUT 落 `core/agent-contract.md` §3 + §4 判据 5（v0.2）；五步全过，注入侧义务属规则真空 |
| F-003 需求没问清白做 | 复检实为 1（通则确认≠独立暴露，口径判例已记 validation/README） | acrs-shared R10（四 case 真实执行无违反） | RFC-001 | **Deferred（2026-09-23）**：触发 = ①再独立暴露 1 次澄清缺失致白做/返工（在线留痕）②已登记 benchmark 候选落地复现 |
| F-004 bugfix 拆分链修不到位 | 2（case-000 + RI-001 独立实验，证据质量最佳） | acrs-orchestrator 连贯性密度 + acrs-solo | agent-catalog（不可承载，自我声明非强制） | **Deferred（2026-09-23）**：五步 1–4 预审通过，唯一阻断=落点承载能力；触发 = RFC-003（Loop Convention）立项时作为一级输入并入；改 catalog 地位须另走 RFC |
| case-004#F-001 系统边界输入验证缺失 | 1 | 回落 Convention（acrs-architect checklist 指南 + acrs-critic 敏感域扩展） | 无（不进 Core） | **Rejected（2026-09-23）**：缺陷本体是工程缺陷非协作契约缺失（体系拦截成功 = 协议在工作，非协议缺失证据；先例 case-001#F-001 判例）；"系统边界"与 Core 既有 Boundary 同名异义违反 RFC-000A；benchmark planted defect 候选已记 case-004 findings |

---

*RFC-000B v1.0 — Active。本协议的修订自身同样受 §4 铁律约束。*
