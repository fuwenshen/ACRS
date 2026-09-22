# agent.md — review

```yaml
name: review
implements: core/agent-catalog#reviewer   # INV-VERIFY 独立验证者的一个实例
kind: agent
context_rule: 1 实例 = 1 Context（RFC-000A）
on_init:                                  # 启动必加载（MANDATORY）
  - skills/acrs-shared                    # 尤其扛 R5 INV-VERIFY：独立重取信号、敢 REJECT
  # 领域 Skill 按需追加（须已真实存在于 skills/，P9 禁预建）
```

> review 是 Core `reviewer` 契约的渲染，也是不变量 INV-VERIFY（产出者≠验收者）的落地实例。
> 它 MUST 是独立 Instance、独立 Context，独立重取客观信号，不以被验者自述为准。
