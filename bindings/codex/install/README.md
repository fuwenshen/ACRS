# Codex Binding — 安装/部署说明

> **职责边界**：`skills/`（仓库顶层）是 ACRS 的能力资产，**平台无关**；
> 本目录只回答"**怎么把 ACRS 接入 OpenAI Codex**"——加载链、入口 Agent、部署方式。
> **状态**：🟡 binding 已建、机制就绪（custom agent TOML schema 按官方 subagents 文档），多 Agent 编排尚未实测跑 case。

## Codex 怎么加载 ACRS（与 Claude/JoyCode 的差异）

| 维度 | JoyCode | Claude Code | Codex |
| --- | --- | --- | --- |
| subagent 格式 | `name`+`groups` frontmatter md | `name`+`description`+`skills` frontmatter md | **TOML**：`name`+`description`+`developer_instructions`（必填三键） |
| agents 位置 | `~/.joycode/agents/` | `~/.claude/agents/` | `~/.codex/agents/*.toml`（用户级）/ `.codex/agents/`（项目级） |
| skills 位置 | `~/.joycode/skills/` | `~/.claude/skills/` | **`~/.agents/skills/`（开放标准，跨工具共享）** / 项目 `.agents/skills/` |
| 开局加载 Skill | 正文指示调 Skill 工具 | frontmatter `skills:` 预载 | 正文指示 `$acrs-shared` / `$acrs-<role>` 显式触发 |
| 派发方式 | Agent(subagent_type=...) | Agent(subagent_type=...) | 自然语言 spawn 具名 custom agent（"have acrs-architect ..."） |
| 入口标记文件 | JOYCODE.md | CLAUDE.md | AGENTS.md |

> **Skills 零成本**：Codex 采用 agentskills.io 开放标准，SKILL.md 与 Claude 通用且个人级路径
> `~/.agents/skills/` 正是 `acrs sync` 的回退默认——Skill 层无任何适配。
> 其余（注入包、result 块、接地证据、DC 勾对、`acrs validate`）全部走 acrs-shared / acrs SKILL，零改动。

## 两种部署形态

### A. 私有环境部署（用户级，`acrs sync` 一键）

```bash
./bin/acrs sync    # 自动按 bindings/codex/roots.conf 部署：
                  #   skills/acrs/* → ~/.agents/skills/acrs-*（开放标准位，Claude 等工具亦可读）
                  #   bindings/codex/agents/*.toml → ~/.codex/agents/
```

同步后在 Codex 会话里说"spawn acrs-orchestrator 处理 X"即用；也可在 AGENTS.md /
skill 指令里请求委派。用 `/agent` 检查子代理线程。

### B. 项目级安装（`bin/acrs-install.sh`）

```bash
./bin/acrs-install.sh --target <项目目录> --platform codex [--dry-run]
```

装进目标项目自包含目录，幂等：

- `<project>/.acrs/` — 公共产物（acrs-shared + 文档），与 JoyCode 版相同
- `<project>/.agents/skills/` — 7 个 ACRS skill（开放标准项目级位，随仓库走）
- `<project>/.codex/agents/` — 6 个入口 agent TOML
- `<project>/AGENTS.md` — 注入 ACRS:BEGIN/END 标记块（指引研发任务派发给 acrs-orchestrator）

## 入口 Agent 与 Skill 的加载链

```
用户/总控 → spawn 具名 custom agent（acrs-<role>） → ~/.codex/agents/acrs-<role>.toml（薄入口）
                                                 └→ developer_instructions 指示：$acrs-shared + $acrs-<role> 显式触发加载
```

每个入口 Agent 只含：identity + 角色红线 + 加载指示。
所有行为细则在 Skill（能力资产），不在 Agent（载体）——与 JoyCode/Claude binding 同构。

## 已知边界（诚实记录）

- Codex 无 `skills:` frontmatter 预载机制，Skill 靠 `$name` 显式触发 + AGENTS.md 指引兜底，
  首次触发多一跳（Claude 版预载更硬）。
- 官方提示 custom agent 文件格式"可能随 authoring 机制成熟而演变"，升级 Codex 时留意 schema 变化。
- 多 Agent 编排真跑 case 前，状态保持 🟡（见 bindings/README.md 分级表）。
