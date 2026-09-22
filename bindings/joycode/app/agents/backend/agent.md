# agent.md — backend

```yaml
name: backend
implements: core/agent-catalog#worker    # backend = worker 的后端领域特化
kind: agent
context_rule: 1 实例 = 1 Context（RFC-000A）
on_init:                                  # 启动必加载（MANDATORY），薄 Agent 靠它扛 Core
  - skills/acrs-shared                    # R1–R9 行为规范层（必加载，非可选）
  # 领域 Skill 按需追加（须已真实存在于 skills/，P9 禁预建）
```

> backend 是 Core `worker` 契约的一个**领域渲染**。契约（Responsibilities/Boundary/Input/Output/Handoff）
> 以 core/agent-catalog#worker 为准；本 bundle 只做后端技术栈的渲染，不得加契约外职责。
> 同一个 worker 契约以后也可渲染出 frontend / data 等 bundle——这正是"契约在 Core、渲染在 Binding"。
