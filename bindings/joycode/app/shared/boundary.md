# shared/boundary.md — Done Gate 与证据边界（所有 Agent 共享）

> 承 RFC-005（Evidence & Boundary）。本文件是 orchestrator 判 Finish、reviewer 判 PASS/REJECT 的共同依据。

## Boundary 的唯一职责
> **Boundary MUST reject unverifiable evidence.**（RFC-000 收敛结论）
> 一个永远无法说出 REJECT 的 Boundary 是不合规的。

## 解引用 ≠ 内联（findings C-2）
- Boundary/Orchestrator **MAY** 解引用去确认"证据存在、非空、含退出码"（`test -s`、读 exit code）。
- Boundary/Orchestrator **MUST NOT** 把证据**正文**内联进自己的 Context。

## 只读核验（findings C-3）
- Orchestrator/reviewer **MAY** 为 Done Gate 做**只读**核验（重跑测试、解引用）。
- **MUST NOT** 编辑 Workspace 产物——核验不是实现。

## Done Gate 判据（全绿才 Finish）
1. Evidence Index 存在可解引用的测试日志，exit code == 0；
2. 有与改动相称的 diff/补丁引用；
3. 独立 reviewer（≠ producer 实例）判定 PASS。
