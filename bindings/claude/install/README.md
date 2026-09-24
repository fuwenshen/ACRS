# Claude Code Binding — 安装/部署说明

> **职责边界**：`skills/`（仓库顶层）是 ACRS 的能力资产，**平台无关**；
> 本目录只回答"**怎么把 ACRS 接入 Claude Code**"——加载链、入口 Agent、部署方式。
> **状态**：🟡 binding 已建、机制就绪（frontmatter 格式按官方 subagents 文档），多 Agent 编排时序尚未实测跑 case。

## Claude Code 怎么加载 ACRS（与 JoyCode 的差异）

| 维度 | JoyCode | Claude Code |
| --- | --- | --- |
| subagent 格式 | `name` + `groups` frontmatter | `name` + `description`（必填，缺了文件被跳过）+ 可选 `tools`/`skills` |
| 注册名 | `ACRS Architect（架构师）` 等中文注册名 | 限小写字母/数字/连字符：`acrs-architect` 等 6 个 |
| skills 位置 | `~/.joycode/skills/<skill>/` | `~/.claude/skills/<skill>/`（用户级）或 `<project>/.claude/skills/` |
| agents 位置 | `~/.joycode/agents/*.md` | `~/.claude/agents/*.md`（用户级）或 `<project>/.claude/agents/` |
| 开局加载 Skill | agent 正文指示"调 Skill 工具加载" | frontmatter `skills:` 字段**预载**（平台原生机制，MANDATORY 加载更硬）+ 正文兜底指示 |
| 子代理再派发 | Agent 工具默认可用 | 须在 frontmatter `tools` 显式列出 `Agent` 才能再 spawn（总控已配） |

> 其余（注入包、result 块、接地证据、DC 勾对、`acrs validate`）全部走 acrs-shared / acrs SKILL，
> 平台无关，零改动。

## 两种部署形态

### A. 私有环境部署（用户级，`acrs sync` 一键）

```bash
./bin/acrs sync    # 自动按 bindings/claude/roots.conf 部署：
                  #   skills/acrs/* → ~/.claude/skills/acrs-*（native 强制同步）
                  #   bindings/claude/agents/*.md → ~/.claude/agents/
```

同步后任何 Claude Code 会话可派发：`Agent(subagent_type="acrs-orchestrator")`，
或直接 @acrs-orchestrator。**注意**：若 `~/.claude/agents/` 此前不存在，
首次部署后需重启 Claude Code 会话（平台 watcher 只监视会话启动时已存在的目录）。

### B. 项目级安装（`bin/acrs-install.sh`）

```bash
./bin/acrs-install.sh --target <项目目录> --platform claude-code [--dry-run]
```

装进目标项目自包含目录，幂等：

- `<project>/.acrs/` — 公共产物（acrs-shared + 文档），与 JoyCode 版相同
- `<project>/.claude/skills/` — 7 个 ACRS skill（项目级，随仓库走、可提交 git）
- `<project>/.claude/agents/` — 6 个入口 agent 薄壳
- `<project>/CLAUDE.md` — 注入 ACRS:BEGIN/END 标记块（指引研发任务派发给 acrs-orchestrator，不动原有正文）

## 入口 Agent 与 Skill 的加载链

```
用户/总控 → Agent(subagent_type=acrs-<role>) → ~/.claude/agents/acrs-<role>.md（薄入口）
                                             └→ frontmatter skills: 预载 acrs-shared（R1–R13）+ acrs-<role>（角色手册）
                                             └→ （预载失败兜底）Skill("acrs-shared") / Skill("acrs-<role>")
```

每个入口 Agent 只含：identity + 角色红线 + 预载核对指示（几十行）。
所有行为细则在 Skill（能力资产），不在 Agent（载体）——
新增角色 ≈ 新增一个薄入口 + 一个角色 Skill；换平台 ≈ 换 Binding，Skill 零改动。

## 验证

```bash
claude plugin validate ~/.claude/agents   # 检查 frontmatter 可解析（v2.1.233+）
```

真跑一次编排后，按仓库诚实分级把结果记入 `reference/`（🟡 → 🟢 需要真实运行留痕）。
