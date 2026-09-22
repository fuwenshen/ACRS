# JoyCode Binding — 安装/部署说明

> **职责边界**：`skills/`（仓库顶层）是 ACRS 的能力资产，**平台无关**；
> 本目录只回答"**怎么把 Skill 接入 JoyCode**"——加载链、入口 Agent、部署方式。

## 两种部署形态

### A. 项目级安装（`bin/acrs-install.sh`，推荐给目标项目）

```bash
./bin/acrs-install.sh --target <项目目录> --platform joycode-cli|joycode-app [--dry-run]
```

- 装进目标项目的自包含目录 `<project>/.acrs/`，幂等，不污染项目其它文件。
- CLI 平台自动接线 JOYCODE.md（ACRS:BEGIN/END 标记块）；APP 平台打印手动导入步骤（不谎称自动注册）。

### B. 私有环境部署（本目录管，`~/.joycode/` 全局可用）

把仓库产物同步到用户级 JoyCode 环境，使所有会话/项目可用：

| 源（仓库） | 目标（部署） | 内容 |
| --- | --- | --- |
| `skills/acrs-*`（7 件） | `~/.joycode/skills/acrs-*` | ACRS 能力资产（shared + 6 角色） |
| `bindings/joycode/agents/ACRS *.md`（6 个） | `~/.joycode/agents/` | JoyCode 入口 Agent（薄壳：identity + 红线 + Skill 加载指示） |

```bash
# 同步（幂等，可直接重复执行）：
cp -R skills/acrs-* ~/.joycode/skills/
cp bindings/joycode/agents/ACRS\ *.md ~/.joycode/agents/
```

> 部署副本的位置由 **JoyCode 平台**决定（它只认 `~/.joycode/`），这正是"Binding 管接入"的含义：
> Skill 本体在仓库 `skills/` 不动，部署只是复制。

## 与 diy-orc 的关系

`~/.joycode/skills/diy-orc-agent-skill/` 与 `~/.joycode/agents/` 里的 diy-orc 入口是**历史参考实现**（六周生产实战版，MCP Ledger 依赖），保留可回退。两套并存，互不干扰；ACRS 入口以 `ACRS ` 前缀命名区分。

## 入口 Agent 与 Skill 的加载链

```
用户 → Agent 工具(subagent_type) → ~/.joycode/agents/ACRS Xxx.md（薄入口）
                                     └→ Skill("acrs-shared")     R1–R13 通用契约（必加载）
                                     └→ Skill("acrs-<role>")     角色手册
```

每个入口 Agent 只含：identity + 角色红线 + 加载指示（几十行）。
所有行为细则在 Skill（能力资产），不在 Agent（载体）——
新增角色 ≈ 新增一个薄入口 + 一个角色 Skill；换平台 ≈ 换 Binding，Skill 零改动。
