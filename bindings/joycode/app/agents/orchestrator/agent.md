# agent.md — orchestrator

```yaml
name: orchestrator
implements: (none — Orchestrator 不是 Agent，不遵循 Agent Contract Schema)
kind: coordinator
context_rule: 1 实例 = 1 Context（RFC-000A）
routing: explicit           # 显式指定 subagent_type，见 ../../conventions.md §1
on_init:                    # 启动必加载（MANDATORY）
  - skills/acrs-shared      # 扛 R2/R3/R4/R7/R8：Handoff/Evidence/Done Gate/Spawn/Archive
```

> Orchestrator **不是** Agent（RFC-000A）：它不做 Plan/Act/Verify，只做 Route。
> 它不 implements Core 契约；它的行为契约在 RFC-001 §5。放进 agents/ 目录只为让 APP 能选中它作入口。
