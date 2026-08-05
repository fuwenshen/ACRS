# RUN-LOG — RI-BUGFIX-002

真实运行时间线（Orchestrator = 本会话根 LLM；Worker/Reviewer = `Agent` 工具真派的隔离实例）。

```
observe   Orchestrator 跑 baseline full → exit 1（reserve红/unreserve假绿/ship绿）→ evidence/baseline-test.log
Spawn#1   Agent(worker) briefing=scoped repro(test_reserve) → 返回 {root_cause:reserve漏available-=qty, exit_code:0}
collect   diff before→now = evidence/worker1.patch（仅reserve）；核验 worker1-test.log 非空
Spawn#2   Agent(reviewer) acceptance=full suite → 返回 {verdict:REJECT, independent_exit_code:1,
          reason:test_unreserve 实际6应10} → evidence/reviewer1-test.log
route     Orchestrator: REJECT → Spawn(backend#2)，带 reject_reason（新实例，不唤醒#1）
Spawn#3   Agent(worker) briefing=full + reject_reason → 返回 {root_cause:unreserve漏available+=qty, exit_code:0}
collect   diff before→now = evidence/worker2.patch（reserve+unreserve 两处对称）
Spawn#4   Agent(reviewer) acceptance=full → 返回 {verdict:PASS, independent_exit_code:0} → evidence/reviewer2-test.log
doneGate  Orchestrator 只读重跑 full → 3/3 exit 0；三判据齐 → Route=Finish
```

Evidence Index：`evidence/ledger.jsonl`（seq 0–11，全程只登记引用，未内联正文）。

平台噪声：本环境 shell 每次打印 `oh-my-zsh nice(5) failed` 与 `MCP ledger 600s 超时`（同 RI-001 C-1），
故 Evidence Index 载体用文件型 `ledger.jsonl`，不影响结论。
