# findings — RI-BUGFIX-002（真实运行结果，喂给 RFC-001/002 修订）

> 标注：`✅ 验证` / `⚠️ 需改措辞` / `❓ 未验证`。本轮首要目标是解 RI-001 的 D-1。

## A. 解掉的诚实缺口

**A-1 ✅ REJECT 回环实跑成立（原 RI-001 D-1）。**
Reviewer#1 独立重跑 full suite 拿到 exit 1，回传 `verdict: REJECT` + 精确理由；
Orchestrator 据此 Route = Spawn(backend#2)。回环从"纸面箭头"变成真实退出码驱动的事件。
→ runtime-sequence.md 里画的 Backend#2 回环，现在有实跑证据。

**A-2 ✅ 打回后是"新实例 / 新 Context"，不是唤醒旧 Context（RFC-001 §3.1）。**
Worker#2 是全新 spawn 的隔离 Agent，briefing 里只带 `reject_reason`（引用级信息），
它没有、也无法访问 Worker#1 的上下文。"无 Context Refresh、续修靠 Spawn+Handoff"实测成立。

**A-3 ✅ INV-VERIFY 的"独立全量验收"确有不可替代的价值。**
Worker#1 的窄修在 scoped repro 下 exit 0、**完全合规**；若无独立全量 Reviewer，
"修 reserve 解开 unreserve"这个回归会直接漏过。独立验证者不是形式主义——它抓到了 producer
在其合法范围内**看不到**的问题。这是对 core/agent-contract §3 的最强实证。

**A-4 ✅ Done Gate 真的会拒。**
本轮 Boundary 说出了一次 REJECT（非永远盖章）。"存在能被 Boundary 拒绝的证据态"这条
合规判据（RFC-005）在真实运行里被满足。

## B. 措辞/设计确认

**B-1 ✅ reject_reason 是必要且充分的最小续修输入（本用例范围内）。**
Worker#2 仅凭 `reject_reason`（"unreserve 未回补 available，实际 6 应 10"）+ full failing_cmd
就精确续修，未要求 Worker#1 的任何上下文。→ 支持 RFC-002：Handoff Package 对 REJECT 续修场景，
`reject_reason` 字段足够；无需回传旧实例对话。

**B-2 ⚠️ Evidence Index 的"累计补丁"语义要写清。**
本轮 `worker2.patch` 是 before→now 的**累计** diff（含 Worker#1 的 reserve 修改）。
多轮修复时，"补丁引用"到底指单轮增量还是累计，RFC-002 应明确。本 RI 采累计（对 Done Gate 更安全）。
→ 动作：RFC-002 写 Evidence Index 时注明"补丁引用的基线"。

## C. 仍未验证（诚实缺口，RFC-002 冻结前仍需）

**C-1 ❓ 溢出续接（原 D-2）仍未触发。** 本任务小，没到 Context 上限，"溢出→同类实例 Handoff 续接"
仍无实跑证据。

**C-2 ❓ 三层递归 / CONV-TREE 未验证。** 本轮是 Orchestrator 直接 Spawn（两层，串行）；
`SubAgent → SubAgent` 递归与"每级只管自己孩子"仍属纸面（conventions.md §2 CONV-TREE 待验）。

**C-3 ❓ 本轮仍在 CLI 用 Agent 工具跑，非 APP 原生 Agent Call。** APP 的 Agent-to-Agent
时序仍未直接实测（joycode/app/README §6 的诚实缺口未消）。

## D. 给 RFC 的最小动作

| # | RFC/文件 | 动作 | 依据 |
| --- | --- | --- | --- |
| 1 | RFC-001 §3.1 | 标注"REJECT→Spawn 新实例、不唤醒旧 Context"**已实证** | A-1/A-2 |
| 2 | RFC-002 | Handoff Package 增列 `reject_reason`，注明续修场景充分 | B-1 |
| 3 | RFC-002 | Evidence Index 补丁引用注明基线（增量 vs 累计）| B-2 |
| 4 | core/agent-contract §3 | 可引 RI-002 A-3 作 INV-VERIFY 的实证脚注 | A-3 |
| 5 | — | RFC-002 冻结仍需第 3 条 RI：溢出续接 + 三层递归（C-1/C-2）| C |

> 结论：**D-1（REJECT 回环）已实证解除**，RFC-001 §3.1 可从"推导"升级为"验证"。
> 但 RFC-002 **仍不能整体冻结**——溢出续接与递归拓扑（C-1/C-2）还差一条 RI。
