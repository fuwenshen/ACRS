# findings — RI-BUGFIX-001（真实运行结果，喂给 RFC-001/002 修订）

> 本文件是 Step 2 的输入：**只写实测得出的结论**，不写推理补充。
> 每条标注对 RFC 的动作：`✅ 验证` / `⚠️ 需改措辞` / `❓ 未验证（诚实缺口）`。

---

## A. 命题验证（RI 的首要目的）

**A-1 ✅ bugfix 未重演"过度编排"失败模式。**
「定位→根因→补丁→回归」全在 **Worker#1 单一 Context** 内连贯完成（Worker Loop 内 Continue），
全程只 Spawn 2 次（执行 1 + 独立验证 1），**未派 Architect、未跨 context 拆分推理**。
根因（"发货漏 `self.reserved -= qty`"）由同一个上下文一次性想清并落地，没有 Handoff 损耗。
→ 这是 ACRS 相对原体系的核心分水岭，实测成立。

**A-2 ✅ "独立判断必须 Spawn"（RFC-001 §5 MUST）确有物理意义。**
Reviewer 是独立子上下文，看不到 Worker 的自述，只拿到 evidence 引用，且**独立重跑**拿自己的退出码。
"自己改的不能自己验"从口号变成了可观测的隔离事实。

---

## B. 平台事实验证（回答此前的开放经验问题）

**B-1 ✅ 子 Agent 是隔离上下文，不继承父对话（P2 / RFC-000 §3）。**
Worker、Reviewer 都只靠 briefing（Handoff Package）工作；没有任何一方引用到主对话内容。
→ P-9「Handoff 是唯一跨上下文传递」在实跑中天然成立——不是被规范"禁止依赖对话继承"，
而是平台**根本没给**这条通道。规范只是把平台事实写成了 MUST。

**B-2 ✅ Orchestrator Context 未随 worker 数增长（RFC-001 §8 判据 4）。**
Collect 只把 evidence *引用*（路径 + 退出码 + 一行摘要）写进 ledger，
Orchestrator 全程**没有把 worker1-test.log / worker1.patch 的正文读进自己上下文**。
→ RFC-001 §5「Orchestrator MUST NOT accumulate execution history」实测可执行。

---

## C. 需改 RFC 措辞（⚠️ 实跑暴露的定义不够精确处）

**C-1 ⚠️ RFC-002：Evidence Index 的载体必须是可插拔 Binding，不能默认绑 MCP ledger。**
本次 MCP ledger（`ledger-blueprint`）调用**超时 600s 失败**，被迫回退到文件型 `ledger.jsonl`。
两种载体都满足"Orchestrator 只持引用"的 WHAT。
→ **动作**：RFC-002 写 Evidence Index 时，明确"载体（MCP / 文件 / DB）是 Binding，Core Spec 只约束
'Orchestrator 持引用、Boundary 解引用核验'这条 WHAT"。已在 RFC-000 §5 埋了两层模型，此处补一个反面实证。
→ 同时进 RFC-006 合规缺口登记表：`JoyCode MCP ledger 在本环境不可用（600s 超时）`。

**C-2 ⚠️ RFC-005：Boundary 与 Orchestrator 的"读证据"边界要写清"解引用 ≠ 内联"。**
Done Gate 要求 Orchestrator 确认引用"可解、非空、含退出码"——这需要它**触碰**证据（`test -s`、看 exit code），
但**不等于把正文累积进 Context**。当前 RFC-001 §5 只说"不得累积正文"，没说"可以确认存在性"。
→ **动作**：RFC-005 补一句区分——`Boundary/Orchestrator MAY dereference to confirm existence &
exit-code, MUST NOT inline evidence body into its own Context`。

**C-3 ⚠️ Orchestrator 亲自终验退出码，是否违反 P-8「routes, not implements」？**
本次我（Orchestrator）在 Done 前自己也跑了一遍测试（exit=0）。跑测试属于 *verify* 还是 *implement*？
判断：verify（读证据）不算 implement（产出业务代码），但**规范当前没给这条线**。
→ **动作**：RFC-005 明确"Orchestrator 可为 Done Gate 做**只读**核验（重跑测试/解引用），
但不得编辑 Workspace 产物"。否则会被误读成"Orchestrator 什么都能干"。

---

## D. 诚实缺口（❓ 本次没跑到，RFC 里的相关条款仍属未验证）

**D-1 ❓ REJECT 回环（Route=Spawn Worker#2）未被触发。**
Worker#1 一次就修对了，Reviewer PASS。所以 RFC-001 §3.1「打回后 Spawn 新实例、不唤醒旧 Context」
这条路径**本次没有实跑证据**。runtime-sequence.md 里画的 Backend#2 回环仍是纸面推导。
→ **动作**：需要一个"故意让 Worker#1 修错 / Reviewer 必须 REJECT"的第二条 RI 用例来验证回环与归档时机。

**D-2 ❓ 溢出续接（Context 近窗口上限 → Spawn 后继同类实例 + Handoff）未验证。**
本任务太小，没触发 RFC-001 §6 的第 3 种 Handoff。"无 Context Refresh、只能 Spawn+Handoff 续做"
仍未被真实的长任务证明。

**D-3 ❓ Handoff Package 的字段充分性（RFC-002 WHAT）未被压力测试。**
本次 briefing 只用到 repo/failing_cmd/expected/constraints 就够了，因为任务简单。
更复杂任务是否需要 workspace 快照、已加载 Skill 清单等字段，本次给不出证据。

---

## E. 给 RFC 修订的最小动作清单

| # | RFC | 动作 | 依据 |
| --- | --- | --- | --- |
| 1 | RFC-002 | Evidence Index 载体标注为 Binding（MCP/文件/DB 皆可），Core 只约束"持引用/解引用" | C-1 |
| 2 | RFC-006 | 登记合规缺口：本环境 MCP ledger 600s 超时不可用 | C-1 |
| 3 | RFC-005 | 加"解引用确认存在性 ≠ 内联正文"的区分句 | C-2 |
| 4 | RFC-005 | 明确 Orchestrator 可做只读核验、不得编辑产物 | C-3 |
| 5 | — | 新增第 2 条 RI 用例（强制 REJECT）验证回环与归档 | D-1 |

> 结论：RFC-001 的**核心生命周期骨架经真实运行验证成立**（A、B 全绿）；
> 需要修订的都是**边界措辞**（C），不是结构。RFC-002 尚不能仅凭本次实跑冻结——
> 因为 REJECT 回环与 Handoff 字段充分性（D）还没有实测证据。
