# skills/ — ACRS 能力资产（L2 Convention + 角色 Skill）

> 本目录回答一个问题：**每个角色该怎么做自己的活？**
> Skill 是"薄 Agent + 厚 Skill"架构里厚的那一层：Agent 定义（`../bindings/`）保持薄，行为规范全部沉淀在这里，平台无关、可被任何 binding 复用。

## Skill 清单
| Skill | 定位 |
| --- | --- |
| [acrs-shared/](acrs-shared/SKILL.md) | **所有 Agent 必加载**的行为规范层：Context/Handoff/Evidence/Boundary/INV-VERIFY/Loop/Spawn/Archive 的 MUST 规则，承载 Core 不变量 |
| [acrs/](acrs/SKILL.md) | 总控调度：入口分诊、四轴分流、Gate 注册表、接地判据、评审独立性、续跑纪律 |
| [acrs-architect/](acrs-architect/SKILL.md) | 架构师：系统/API/DB 设计产出规范、design_checklist 硬格式、一轮自审、质疑上游 |
| [acrs-backend/](acrs-backend/SKILL.md) | 实现者：照冻结设计实现、构建接地（回传真实 build 退出码）、最小 diff |
| [acrs-critic/](acrs-critic/SKILL.md) | 评审者：评审独立性铁律、verdict 三态、issue 分级、DC 逐条勾对 |
| [acrs-test/](acrs-test/SKILL.md) | 测试者：回传真实测试退出码、DC 逐条覆盖、复用优先、敏感域必测 |
| [acrs-solo/](acrs-solo/SKILL.md) | Solo 全栈：单上下文端到端连贯路（理解→骨架→码→自测→接地）、bugfix 快道 |

## 加载规则
- **任何角色被派发任务时**：先加载 `acrs-shared/`，再加载对应角色 Skill。
- Skill 做什么/怎么做归这里；某平台怎么加载它归 `../bindings/`。
