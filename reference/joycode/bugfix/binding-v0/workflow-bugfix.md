# BugFix Workflow (SOP) — binding v0

| 字段 | 值 |
| --- | --- |
| **性质** | Workflow = 行为约定（Convention / SOP），**不是** Runtime 原语，**不是** Worker 的 Skill（承 RFC-000A、RFC-000 §4）。 |
| **归属** | 描述一条 **Task** 期望的 Route 序列；跨多个 Agent Instance（承 RFC-000A：Skill 是 per-context，Workflow 跨 context）。 |
| **落地** | 在 JoyCode 上，本 SOP 由 Orchestrator 加载（P3 Skill 承载），指导它每一步 Route。 |

---

## 0. 这条 SOP 存在的理由（也是本 RI 要验证的命题）

原多智能体体系对 bugfix 的失败模式是：把「定位 → 根因 → 打补丁 → 回归」拆成
`Architect(设计) → Backend(照冻结设计编码) → Test` 三个**独立 context**，
每次 Handoff 都损耗一次「为什么这么改」的根因理解，token 烧光、根因还在漂。

**ACRS 对 bugfix 的正确编排**：

> bugfix 的核心是**连贯的因果推理**（现场 → 根因 → 改）。这份推理**必须在同一个
> Worker Context 内一气呵成**（Worker Loop 内 Continue，不跨 context 拆分），
> **只**为「独立验证」这一条 MUST 才 Spawn 出 Reviewer/Boundary。

**反例（本 SOP 明令禁止）**：为 bugfix 派 Architect；把定位/打补丁/回归拆成多个 Instance；
让 Orchestrator 自己读代码、自己改（违反 P-8 routes-not-implements）。

---

## 1. Route 序列（Orchestrator 视角）

```
Task: "test_X 失败，修好它"
   │
   ▼
① Route = Spawn(Worker)              ← 唯一的执行实例
   └─ 交付 Handoff Package：repo 路径 / 失败测试命令 / 期望退出码=0 / BugFix Loop
       └─ Worker 在【单一 Context】内跑 Worker Loop：
            Observe(复现失败) → Locate(定位) → RootCause(根因) →
            Patch(最小改动) → Verify(重跑测试拿退出码)
       └─ 回传 Handoff Package（含 Evidence 引用：diff / 测试日志 / 退出码）
   │
   ▼
② Collect：把 Worker 的 Evidence 引用登记进 Evidence Index（MCP ledger）
   └─ Orchestrator 不内联日志/diff 正文（P-5 / RFC-001 §5）
   │
   ▼
③ Route = Spawn(Reviewer)            ← MUST：需要独立判断（成本无投票权）
   └─ 交付 Handoff Package：只给 Evidence 引用 + 验收判据，【不给 Worker 的自述】
       └─ Reviewer 独立解引用、独立重跑、独立判 PASS/REJECT
   │
   ▼
④ Boundary @ Done Gate
   ├─ PASS  → Task → Done
   └─ REJECT→ Route = Spawn(Worker#2)（新 Context，带上 Reviewer 的拒绝理由）
```

**关键**：`①` 是**一次** Spawn，Worker 内部的定位/根因/打补丁/回归是 **Continue**（同 context 循环），
**不**是四次 Spawn。这是与失败模式的分水岭。

---

## 2. 每步的 Spawn/Continue 依据（承 RFC-001 §5）

| 步 | 决策 | 依据 |
| --- | --- | --- |
| 派 Worker | **Spawn** | Orchestrator 不实现业务（P-8）；需要一个执行 Context |
| Worker 内定位→根因→补丁→回归 | **Continue** | 无独立判断需求、无栈污染、context 未近上限 → 默认 Continue |
| 派 Reviewer | **Spawn (MUST)** | 需要**独立判断**：自己改的不能自己验（RFC-001 §5 MUST 档） |
| 打回后重修 | **Spawn Worker#2** | 无 Context Refresh；不唤醒 Worker#1（已 Archived） |

---

## 3. 升级出口（何时这条 SOP 不适用）

若 Worker 在 Observe/Locate 阶段发现该"bug"实为**跨模块设计缺陷**（blast ≥ 跨模块 / 触敏感域），
它**必须**在 Handoff 里标记 `escalate: design`，Orchestrator 改走 Feature/Architecture Workflow，
**不**在本 SOP 内硬修。（对应 RFC-000 里"编排价值线"：连贯小修走这条，跨模块重构不走。）
