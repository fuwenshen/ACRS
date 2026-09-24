# skills/ — ACRS 能力资产（L2 Convention + 角色 Skill）

> 本目录回答一个问题：**每个角色该怎么做自己的活？**
> Skill 是"薄 Agent + 厚 Skill"架构里厚的那一层：Agent 定义（`../bindings/`）保持薄，行为规范全部沉淀在这里，平台无关、可被任何 binding 复用。

## Skill 清单（native，`acrs/` 系列）
| Skill | 定位 |
| --- | --- |
| [acrs-shared/](acrs/acrs-shared/SKILL.md) | **所有 Agent 必加载**的行为规范层：Context/Handoff/Evidence/Boundary/INV-VERIFY/Loop/Spawn/Archive 的 MUST 规则，承载 Core 不变量 |
| [acrs/](acrs/acrs/SKILL.md) | 总控调度：入口分诊、四轴分流、Gate 注册表、接地判据、评审独立性、续跑纪律 |
| [acrs-architect/](acrs/acrs-architect/SKILL.md) | 架构师：系统/API/DB 设计产出规范、design_checklist 硬格式、一轮自审、质疑上游 |
| [acrs-backend/](acrs/acrs-backend/SKILL.md) | 实现者：照冻结设计实现、构建接地（回传真实 build 退出码）、最小 diff |
| [acrs-critic/](acrs/acrs-critic/SKILL.md) | 评审者：评审独立性铁律、verdict 三态、issue 分级、DC 逐条勾对 |
| [acrs-test/](acrs/acrs-test/SKILL.md) | 测试者：回传真实测试退出码、DC 逐条覆盖、复用优先、敏感域必测 |
| [acrs-solo/](acrs/acrs-solo/SKILL.md) | Solo 全栈：单上下文端到端连贯路（理解→骨架→码→自测→接地）、bugfix 快道 |

## 加载规则
- **任何角色被派发任务时**：先加载 `acrs-shared/`，再加载对应角色 Skill。
- Skill 做什么/怎么做归这里；某平台怎么加载它归 `../bindings/`。

## 目录约定（2026-09-22 定稿：系列化，无特殊层）
- 结构统一 `skills/<系列>/<skill>/SKILL.md`，native 与扩展同构。
- **`acrs/` 系 = native**（体系行为契约）：`bin/acrs sync` 单向以仓库为准强制同步，改动走 RFC。
- **其他系列 = 扩展**（工具能力，非角色范畴）：如 `superpowers/`、`chinese/`；sync 按二级 `<skill>` 目录名平铺到各载体 skills 根，**冲突不覆盖**（个人配置优先），治理自由生长。
- 各载体的部署根由 `../bindings/<载体>/roots.conf` 自声明（未声明回退 `~/.agents/`），未来 CC / Codex 等载体各建各的。
- 纪律：扩展 skill 提供**工具能力**不豁免 ACRS 行为契约——被 ACRS 角色使用时 result 块/接地证据/DC 勾对照常执行。

## 写作规范（superpowers@v6.4.1 研读吸收，case-005#F-001）
- **SDO 陷阱（技能发现度）**：SKILL.md 的 description **只写触发条件，不概括流程内容**——描述一旦概括了内容，Agent 会自以为读过而跳过正文（superpowers 实测：描述写"任务间做 review"，Agent 只执行 1 次而流程要求 2 次）。
- **形态对准故障（Form-to-Failure）**：写约束时先问失守的形态是什么，再选形态——
  纪律失守（Agent 找借口绕过）→ 禁令 + 借口/现实对照表（逐条预演合理化话术）；
  输出形状错 → 正面 recipe 范例（纯禁令在此场景反而更糟，superpowers micro-test 实证：禁令组的劣化输出多于范例组）；
  缺元素 → 结构化 REQUIRED 槽位；条件行为 → 可观察谓词（满足什么可观察条件才做什么）。
