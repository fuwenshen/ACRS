# Quick Start —— 我怎么用上 ACRS？

> 只回答一个问题：一个开发者拿到这个仓库后，如何在自己的平台上跑起 ACRS。
> **状态分级（重要）**：🟢 已实测 · 🟡 设计意图（机制未在该平台实测）· ⬜ 未建（binding 不存在）。
> 别把 🟡/⬜ 当成"照着做就能用"——那些是路线，不是保证。

---

## 你在用哪个平台？

| 平台 | 入口载体 | 状态 |
| --- | --- | --- |
| JoyCode CLI | Root Prompt（`bindings/joycode/cli/root-prompt.md`）| 🟢 已实测 |
| JoyCode APP | Agent bundle（`bindings/joycode/app/agents/`）| 🟡 设计意图 |
| Claude Code | `CLAUDE.md` | ⬜ 未建 |
| Codex | `AGENTS.md` | ⬜ 未建 |
| Cursor | Rules | ⬜ 未建 |

> 你会发现：**变的只有"入口载体"这一列，acrs-shared 和 Core 完全一样**。

---

## 🟢 形态 B · ACRS-native Skills（主推，case-001 验证主线）
6 角色 Skill + 6 Agent 入口装进 `~/.joycode/`（全局用户级，所有项目可用）：

```bash
cd <ACRS 仓库>
bash install.sh   # 写 ~/.acrs/path 指针
bin/acrs sync     # 部署 + 校验（幂等；源=仓库本体，单向以仓库为准）
```

然后任意项目对话里点名 Agent（如「派 ACRS Architect 做 XX 设计」）或让总控分诊。
资产接入见 `acrs attach`（`bin/acrs` --help）。

## 🟢 形态 A · JoyCode CLI 行为模拟（RI-001/002 已实证）
ACRS 的 RI-001/002 都是在这里真跑出来的。

1. 打开你的项目，启动 JoyCode CLI。
2. 把 [`bindings/joycode/cli/root-prompt.md`](../bindings/joycode/cli/root-prompt.md) 的内容作为会话的根提示词
   （它内联了 acrs-shared 的**核心行为**：Route/Spawn/INV-VERIFY/Done Gate/溢出续接；
   非全量——R10–R13 未入，完整版以 [`skills/acrs/acrs-shared/SKILL.md`](../skills/acrs/acrs-shared/SKILL.md) 为准）。
3. 直接给任务，例如"修复 XXX 这个 bug"。根提示词会让单个 Context 扮演
   Orchestrator → Backend → Review 的行为，REJECT 后 Spawn 新实例重来。
4. 完成时你会拿到：改动 diff + 测试退出码 + review 结论——都是可核对的**证据引用**，不是"我觉得好了"。

> ⚠️ CLI 是**单 Context 行为模拟**：隔离靠纪律不靠机制，INV-VERIFY 是弱隔离
> （见 `bindings/joycode/app/capability-matrix.md`）。强盲验需求建议走 APP 或另起会话做 review。

---

## 🟡 JoyCode APP（设计意图，导入机制尚未在 APP 实测）
以下是**目标用法**，不是已验证流程——APP 原生 Agent-to-Agent 编排的时序我们还没直接实测。

1. 安装 JoyCode APP。
2. 导入 [`bindings/joycode/app/agents/`](../bindings/joycode/app/agents/)（orchestrator / backend / review）
   与 [`skills/`](../skills/)（acrs-shared 等，平台无关的能力资产）。
3. 打开项目，选择 **Orchestrator** 作为入口 Agent。
4. 预期行为：`Orchestrator → Backend → Review →（REJECT）→ Backend#2 → Done`，
   跨实例状态只走 Handoff Package。
5. 每个 Agent 极薄，靠 `on_init` 加载 `acrs-shared`（必加载）+ 领域 Skill。

> 📌 这一段任何"照做没跑通"的地方，就是 Validation 要去补的第一批 findings——**欢迎它失败**。

---

## ⬜ Claude Code / Codex / Cursor（规划中，binding 未建）
原理相同、只换入口载体：

```
Claude Code : CLAUDE.md  → acrs-shared → Domain Skill
Codex       : AGENTS.md  → acrs-shared → Domain Skill
Cursor      : Rules      → acrs-shared → Domain Skill
```

这些 binding 还没建（ROADMAP Phase 5）。届时 Core 与 acrs-shared 一行不改，只新增入口层。

---

## 我该导入 Agent 还是 Skill？（新人最常问）
- **入口（Agent / CLAUDE.md / Rules）**：定义"我是谁、能调谁、启动加载哪些 Skill"，很薄。
- **acrs-shared**：所有入口**必加载**的行为规范，是地基。
- **领域 Skill（如 java-backend）**：按需加载的能力——**目前刻意还没建**，等真实开发中重复出现再抽（PRINCIPLES P9）。

> 一句话：**入口选一个 → 它自动带上 acrs-shared → 需要领域能力时再加 Skill。**
