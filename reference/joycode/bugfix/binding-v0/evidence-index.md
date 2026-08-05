# Evidence Index — binding v0（MCP ledger 承载）

> ACRS 里 Orchestrator **只持有 Evidence 的引用**，按需解引用，绝不把产物正文
> 累积进自己的 Context（RFC-001 §5：`Orchestrator MUST NOT accumulate execution history`）。
> 本 binding 用 **MCP ledger（P4）** 作为 Evidence Index 的物理载体。

## 为什么用 ledger 当 Evidence Index

- ledger 是 append-only 的**跨 Context 共享事实源**（对应 RFC-000A：只有 Workspace/Task/Evidence/Git 可跨 context 共享，Context 本身永不共享）。
- Orchestrator 往 ledger 写的是**引用条目**（task_id + 证据路径 + 退出码 + 一行摘要），不是日志正文。
- Boundary 校验时从 ledger 拿到引用，再去**文件系统解引用**核验。

## 引用条目结构（每次 Collect 追加一条）

| 字段 | 含义 | 示例 |
| --- | --- | --- |
| `task_id` | Task 唯一标识 | `RI-BUGFIX-001` |
| `grounding.test_cmd` | 实际测试命令 | `python3 run_tests.py` |
| `grounding.test_exit_code` | 退出码（0=全绿） | `0` |
| `grounding.evidence_ref` | 证据落盘路径 | `reference/joycode/bugfix/evidence/worker1-test.log` |
| `affected_files` | 改动文件 | `["fixture/inventory.py"]` |
| `status` / `sub_status` | 主线态 / 子态 | `REVIEWING` / `QUALITY_REVIEW` |

## 关键约束（conformance）

- **可解引用**：`evidence_ref` 指向的文件 MUST 真实存在、非空、含退出码；否则 Boundary REJECT。
- **Orchestrator Context 不随 worker 数增长**：跑 N 个 Worker，Orchestrator 只多 N 条引用，
  不多 N 份日志正文（RFC-001 §8 判据 4，本 RI 需实测这一点）。
- **baseline 对照**：入库 `baseline_failures`（改动前失败数）与 `current_failures`（改动后），
  `new_failures` MUST == 0（不新引入失败）。
