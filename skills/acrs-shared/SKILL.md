---
name: acrs-shared
description: 所有 ACRS Agent 必加载的行为规范层。定义 Context/Handoff/Evidence/Boundary/INV-VERIFY/Loop/Spawn/Archive 的 MUST 规则。承载 Core 不变量，是"薄 Agent + 厚 Skill"里最厚的那块共享 Skill。
---

# acrs-shared — ACRS 行为规范层（所有 Agent 必加载）

## 它在四层模型里的位置

```
L1 Core        RFC/ + core/          协议原语，永不随平台变
L2 Convention  ← 本 Skill 的内容      "所有 Agent 必守的行为"（平台无关）
L3 Binding     bindings/joycode/      各平台怎么加载/执行本 Skill（载体，不含 Skill 本体）
L4 Reference   reference/            真跑证据
```

- **本 Skill 是 ACRS 的能力资产（平台无关）**，住在仓库顶层 `skills/`——它不属于任何平台。
  Binding 只回答"JoyCode/Claude Code/Codex **怎么接入**"：加载链、入口 Agent、部署脚本。
- **MANDATORY（必加载，非可选）**：承载 Core 不变量的规则若写在一个没被加载的 Skill 里，
  等于没有 boundary。故每个 ACRS Agent 启动 **MUST** 先加载本 Skill。
- 每条规则标注 **来源**（RFC/agent-contract/validation case finding），本 Skill **不新增**规则、只**消费并固化** Core，
  防止行为层与冻结的 Core 漂移。

---

## R1. Context 规则（来源：RFC-000A / RFC-001 §6）
- **MUST**：`1 Instance = 1 Context`。你在你这一个 Context 内连贯完成使命。
- **MUST NOT**：假设有"Context Refresh / 记忆续期"。没有。
- 接近上限时 **MUST**：把产物落盘 + 写 Handoff Package，**Spawn 同类新实例**接续；
  **MUST NOT** 原地硬撑续跑。

## R2. Handoff 规则（来源：RFC-000 P-9 / agent-contract §2.1 / reference/joycode/bugfix-reject 实证；RFC-002 为 ROADMAP 规划槽位，落地后回填）
- 你收到的**全部输入** = Handoff Package + 共享文件系统 + Tool/MCP。
- **MUST NOT** 依赖读到父对话、上一个 Agent 的思考轨迹或自述。
- 跨实例状态**只**走 Handoff Package。Package **MUST** 只带**引用**（路径/退出码/一行摘要），
  **MUST NOT** 内联日志或对话正文。

## R3. Evidence 规则（来源：agent-contract §2.1 / bindings/joycode/app/shared/evidence.md）
- Evidence **MUST** 来自客观来源：git diff / test log / build 输出 / Tool·MCP。**不接受"我觉得"**。
- 引用（如 `test_log_ref`）**MUST** 真实、可解、非空、含退出码。
- 你回传的是**证据引用**，不是"我修好了"的口头结论。

## R4. Boundary / Done Gate 规则（来源：agent-contract §2.1 / bindings/joycode/app/shared/boundary.md）
- **Boundary MUST reject unverifiable evidence。** 一个永远说不出 REJECT 的 Boundary 不合规。
- Done Gate 三判据（全绿才算完成）：
  1. 有可解引用的测试日志，exit code == 0；
  2. 有与"改动"相称的 diff/补丁引用（非大范围重写）；
  3. **独立**验证者（≠ producer 实例）判定 PASS。
- 核验时 **MAY** 解引用确认"证据存在/含退出码"、**MAY** 只读重跑；**MUST NOT** 编辑 Workspace 产物、
  **MUST NOT** 把证据正文内联进自己的 Context。

## R5. INV-VERIFY — 独立验证者（来源：agent-contract §3，Core 唯一的组合类不变量）
- **MUST**：产出某 Evidence 的实例 ≠ 对其验收的实例；验收发生在**独立隔离 Context**。
- 验证者 **MUST** 独立重取客观信号（自己重跑拿自己的退出码），**MUST NOT** 以被验者自述为准。
- ⚠️ **隔离强度按 Binding 不同**（可移植性实验结论）：APP 靠进程边界=**机制强制**盲验；
  CLI 单上下文=**纪律自律**（弱隔离）。高度依赖盲验的任务 SHOULD 路由到 APP，
  或在 CLI 上用补偿机制（另起会话做 review）。

## R6. Worker Loop（来源：agent-catalog#worker / RFC-003）
- 改动类任务 **MUST** 在**一个** Context 内连贯跑完：**Observe → Locate → RootCause → Act → Verify**。
- **MUST**：先复现再动手；根因一次理透，不丢给下一个 Context 重解。
- **Verify MUST** 拿退出码，只认退出码。

## R7. Spawn 规则（来源：RFC-001 / conventions §1-2）
- 何时 Spawn：需要一个**新的隔离 Context**时——独立验证、Context 溢出续接、或跨认知域子任务。
- **MUST** 显式指定 agent_type（显式路由），**MUST NOT** 让平台自动猜。
- **CONV-TREE**：只管理**你直接** Spawn 的子实例，不跨层管孙子；没有"全知总控"。

## R8. Archive 规则（来源：RFC-001 §3.1，已由 RI-002 实证）
- 子实例进入 Waiting-Handoff 且被 Collect（登记引用）后即 Archive。
- **REJECT 后 MUST Spawn 新实例**（新 Context，只带 `reject_reason`），**MUST NOT** 唤醒旧 Context。

## R9. Escalation（来源：agent-catalog#worker boundary）
- 若发现是**跨模块设计缺陷**而非局部 bug：**MUST 停手并 escalate**，**MUST NOT** 硬改。

## R10. 澄清前置（来源：case-000#F-003，Convention 归层 / Core 候选 RFC-001）
- 改动类任务开工前，"**正确行为是否已定**"是可核对项，不是可选项。
- 存在会实质改变设计/接口/数据模型的分叉（数据口径/行为语义/对外契约/技术分叉/范围边界）
  而**未**澄清 → **MUST 停下先问**（经能触达用户的实例转达），**MUST NOT** 拿假设开工。
- 前期没问清 = 后面全白做。澄清是**义务**，不是"想多问几句"。

## R11. Acceptance 契约（来源：case-000#F-005，Convention 归层，agent-contract §2.1 Evidence 原语的操作化）
- 跨实例交接的设计 **MUST** 携带可核对验收锚点（DC-xx 条目：当 X → 做 Y → 期望 Z，
  event/状态/错误各自独立一条，粒度到"能写出一条 pass/fail 明确的测试"）。
- 生产者逐条落地、测试者逐条覆盖回传、验证者逐条勾对（已实现/缺失/偏离）——
  任一"缺失/偏离" **MUST** 阻断放行。**绿灯若建立在漏测锚点之上 = 假绿。**

## R12. 接地模式谱系（来源：case-000#F-006，Convention 归层，agent-contract §2.1 Evidence 的操作化）
- "完成"的判据按模式取证据，不一刀切：full（test=0）/ scoped（子集=0+范围说明）/
  baseline（**new_failures=0**，存量失败不卡你，但你不能引入新失败）/ trivial（build=0+理由）/
  waiver（无代码任务+理由）。模式由派发者指定，执行者按模式回传。
- **可执行应用（有 main/启动入口）加一档 boot smoke（case-001#F-5）**：build=0 只证编译不证能启动——接地证据 MUST 含最小启动冒烟（真实拉起 context / 健康端点探测，@Scheduled/监听器/连接池类启动即崩缺陷只有这层能暴露）。
- **无退出码的"完成" = 违约。**

## R13. result 输出协议（来源：case-000#F-007，Convention 归层，Handoff Package 输出侧操作化）
- 被派发实例 **MUST** 在回复最末尾输出结构化 result 块（合法 JSON、含 status/产物引用/接地证据），
  供派发者解析。**解析失败 → 定向重问"只补 result 块"，MUST NOT 整任务重派。**

---

## 薄 Agent 怎么用它（App 入口示例）

一个 App Agent 应该薄到只剩三件事，其余全交给本 Skill + 领域 Skill：

```
Backend Agent（入口，几十行）
  identity   : 我是 backend（渲染 core#worker）
  routing    : 我可 Spawn 哪些 agent_type
  on-init    : MUST Load skills/acrs-shared   ← 扛 R1–R13（Core 不变量 + 过闸 Convention）
               Load skills/backend-java        ← 领域能力（Spring/MyBatis/DDD）
```

> 新增 Agent（如 blockchain）≈ `Load acrs-shared + Load solidity`，几乎不用重写 Prompt。
> 新增 Skill（如 rust）≈ 所有 worker 类 Agent 都能调，Core 一行不改。
