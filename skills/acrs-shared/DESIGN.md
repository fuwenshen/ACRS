# acrs-shared 设计规范（DESIGN）

> 治理 `SKILL.md` 的边界。**它管"acrs-shared 里能放什么、不能放什么、什么时候该拆出去"，
> 不是再往里堆内容。** 因为每个 Agent 都必加载它——它一胖，所有 Agent 一起变慢变贵。

## §0 一句话职责
> acrs-shared **只**承载**平台无关的行为规范（L2 Convention）**，且**只固化已冻结的 Core**。
> 它不含任何领域知识、不含任何平台调用细节、不含任何角色专属职责。

## §1 为什么必加载（MANDATORY）
承载 Core 不变量（Boundary/INV-VERIFY/Handoff…）的规则，若写在一个"可选"Skill 里，
就等于这些不变量可以被绕过。故它是**每个 ACRS Agent 的启动前提**，不是可选增强。

## §2 准入：MUST 放什么
仅限以下且**每条 MUST 能追溯到一个已过闸门的来源**（RFC-00x / agent-contract §y / validation case finding）：
- Context 规则、Handoff 规则、Evidence 规则、Boundary/Done Gate、INV-VERIFY、
  Worker Loop 骨架、Spawn 规则、Archive 规则、Escalation。
- **finding 来源**（2026-09-20 起，依据 case-000）：经 validation 四分类闸门归层为
  Convention 的 finding 可固化入本 Skill，标注 `（来源：case-00x#F-yy）`；
  Core 候选条目须同时标注候选去向（待哪个 RFC 增补）。
- 判据：**"所有 Agent（不分领域、不分平台）都必须守"** 的行为，才够格进来。

## §3 禁止：MUST NOT 放什么（违反即应移出）
| 禁止内容 | 它该去哪 |
| --- | --- |
| 领域知识：Java/Spring/MyBatis/SQL/DDD/Security/Review checklist | 领域 Skill（`skills/java-backend` 等）|
| 平台调用细节：怎么调 Agent 工具、怎么写 CLAUDE.md | 各 Binding（`app/` `cli/` …）|
| 某个角色专属职责（只有 reviewer 要守 / 只有 architect 要守）| 该角色的领域 Skill 或 agent bundle |
| 运行时旋钮：retry / hooks / tool policy / model 选择 | Binding；或根本不该存在（见 Principles P3）|
| Core 里还没有的**新**行为规则 | **先过闸门**：validation case finding 归层 Convention 后固化（标 case 引用），或先改 Core（RFC/agent-contract）再回来固化 |

## §4 什么时候从 acrs-shared 拆出新 Skill
出现下列任一，该内容**不属于** acrs-shared，拆成领域/角色 Skill，由需要的 Agent `on_init` 加载：
1. 只有**部分** Agent 需要（不是"所有 Agent 都守"）；
2. 是**领域**知识（技术栈、框架、行业规则）；
3. 是**可选**的最佳实践（不遵守不构成 Core 违约）。

## §5 改哪一层？（决策树）
一个新需求来了，先问：
```
它是"所有 Agent 都必守的行为、且能画进 Runtime Sequence"吗？
  是 → 它是 Core 行为：先改 RFC/agent-contract（Core），再在 acrs-shared 固化引用。
  否 → 它是"某平台怎么表达 Agent"吗？
        是 → 改对应 Binding（app/cli/claude-code…）。
        否 → 它是领域/角色/可选能力吗？
              是 → 新增或改领域 Skill。
              否 → 大概率你在发明一个不该存在的概念（回 Principles P8 三问）。
```
> 关键：**acrs-shared 自己永远不是"新规则的诞生地"**。新行为规则的源头只能是 Core。

## §6 尺寸预算（防胖硬约束）
- **目标上限**：SKILL.md 正文 ≲ 400 行 / ≈ 3.5K token（每个 Agent 都要吞它，预算是全局乘数）。
- **实测基线（2026-07-30）**：SKILL.md 3526 字符 / 92 行。
- **增补记录（2026-09-20，case-000 过闸固化）**：+R10~R13（澄清前置 / Acceptance 契约 /
  接地模式谱系 / result 协议），现 115 行。仍在预算内；下次改动继续记录增量。
- **趋势监控（比单点上限更重要）**：记录 SKILL.md 体量轨迹，如 `3.5K→3.8K→4.2K→5.0K`。
  **持续单调上涨 = Convention 正在吞噬 Domain**——这是全项目最该盯的维护信号（Core/Binding/Entry 都稳定，天天改的是这里）。
- **触发复审**：逼近上限**或**连续 3 次提交只增不减 → MUST 先按 §3/§4 往外拆，**不得靠加内容解决问题**。
- **度量**：每次改动在提交里记录字符/行数增量；上涨须给出"为什么这条必须在 Convention 而非 Domain"的理由。

## §7 变更流程
1. 改 acrs-shared 前，先确认新增条目在 Core 有来源；没有 → 先改 Core。
2. 每条规则保留 `（来源：…）` 标注，评审时逐条核对是否仍与 Core 一致（防漂移）。
3. 删除比新增更受欢迎：能下沉到领域 Skill 的，就不该留在这里。
