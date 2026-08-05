# RI-BUGFIX-002 — 强制 REJECT 回环（真实运行）

> **目的**：补上 RI-BUGFIX-001 的诚实缺口 **D-1**（REJECT 回环从未被实跑），
> 用真实 spawn 的隔离子 Agent 验证「打回 → Spawn 新实例（非唤醒旧 Context）→ 续修 → PASS」。
> **平台**：JoyCode CLI，Orchestrator 用 `Agent` 工具真派 Worker / Reviewer（与 RI-001 同法）。

## fixture 设计：让 REJECT 自然发生（非指令造假）

`inventory.py` 埋了两个**对称 bug**且**相互掩盖**：
- `reserve` 漏 `available -= qty`（BUG#1）；`unreserve` 漏 `available += qty`（BUG#2）。
- 初始态：`available` 从不变动 → `test_reserve` 失败，但 `test_unreserve` **碰巧通过**（两 bug 抵消）。
- **一旦修好 reserve，`test_unreserve` 才被暴露**。

关键手法：给 Worker#1 的是 **scoped repro**（只跑 `test_reserve`），并配**合法**的"最小改动"约束。
Worker#1 只修 reserve 是**完全正确**的窄修，不是被指使的破坏。
独立 Reviewer 的验收判据是 **full suite**——于是它抓到被解开的 `test_unreserve` → 自然 REJECT。

> 这条用例因此还顺带证明了一件事：**窄范围 Worker + 独立全量 Reviewer** 的组合，
> 正是 INV-VERIFY 存在的价值——"修一个 bug 解开另一个"这种事，只有独立全量验收能兜住。

## 运行结果（全部为真实退出码）

| 步 | 角色（真实 spawn） | 动作 | 客观结果 |
| --- | --- | --- | --- |
| observe | Orchestrator | 跑 baseline full | exit 1（reserve 红 / unreserve 假绿 / ship 绿）|
| Spawn#1 | Worker#1（隔离） | scoped repro 下修 reserve | scoped test 绿，exit 0 |
| Collect | Orchestrator | 登记引用（不内联）| worker1.patch 只动 reserve |
| Spawn#2 | Reviewer#1（隔离，独立）| full suite 独立重跑 | **exit 1 → REJECT**（test_unreserve 暴露）|
| Route | Orchestrator | Spawn(backend#2)，带 reject_reason | **新实例 / 新 Context，不唤醒 Worker#1** |
| Spawn#3 | Worker#2（隔离） | 按 reject_reason 补 unreserve | full suite 绿，exit 0 |
| Spawn#4 | Reviewer#2（隔离，独立）| full suite 独立重跑 | **exit 0 → PASS** |
| Done Gate | Orchestrator | 只读终验 full | exit 0，三判据齐 → Finish |

证据见 `evidence/`（含 baseline、两轮 worker/reviewer 日志、累计补丁、`ledger.jsonl` Evidence Index）。
