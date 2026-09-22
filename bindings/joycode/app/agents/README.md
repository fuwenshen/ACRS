# agents/ — APP Agent 目录说明

> ⚠️ **两代并存裁决（2026-09-21）**：本目录是**旧代 APP bundle（4 角色 catalog 渲染，🟡 APP 编排未实测）**，保留为可回退遗留路径。
> 当前主线是 **ACRS-native 6 入口**（`bindings/joycode/agents/`）+ **6 角色 Skill**（`skills/`），部署用 `bin/acrs sync`。
> 两代勿混用（同一任务单主线）；本目录不再新增 bundle。

> 每个子目录是一个 Agent 的 **Binding bundle**，复制 `_template/` 生成。
> **入口 = 薄 Agent，能力 = Skill**：Agent 只留"身份 + 路由权限 + `on_init` 加载哪些 Skill"，
> 其余全在 `../../skills/acrs/` 里。每个 Agent 的 `on_init` **MUST** 加载 `skills/acrs/acrs-shared`（扛 Core 不变量）。

## 已建（MVP 链路所需）
| 目录 | 渲染的 Core 契约 | on_init 加载 | 状态 |
| --- | --- | --- | --- |
| `orchestrator/` | （非 Agent，Route 协调者，RFC-001 §5）| acrs-shared | ✅ |
| `backend/` | core/agent-catalog#worker（后端特化）| acrs-shared（领域 Skill 按需追加）| ✅ |
| `review/` | core/agent-catalog#reviewer（INV-VERIFY 实例）| acrs-shared（领域 Skill 按需追加）| ✅ |

## 未建（按需再加，**刻意不预建**）
`architect/`、`test/`、`security/`、`frontend/` …… 复制 `_template/`，写 `on_init: [acrs-shared, <领域skill>]` 即可。
新增 Agent 前 **MUST** 过 [core/agent-catalog](../../../../../core/agent-catalog.md) 末尾的"准入闸门"3 问。

> **为什么刻意不预建 architect**：RI-BUGFIX-001 实测 bugfix 不需要它（findings A-1）。
> 预建等于暗示"每个流程都要先过 architect"——那正是我们质疑的固定流水线。
> 需要哪个 Agent，是**具体 Workflow 的选择**，不是框架默认。
