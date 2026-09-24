# bindings/ — 平台入口载体（L3 Binding）

> 本目录回答一个问题：**某平台怎么加载 ACRS？**
> Skill 本体（`../skills/`）不属于任何平台；这里只管"接入"——Agent/Skill 怎么被该平台识别、加载、执行。换平台 = 换一层 binding，Core 与 Skill 一行不改。

## 目录结构
```
bindings/
├── joycode/            # JoyCode 载体
│   ├── agents/         # 6 个 ACRS Agent 定义（Architect/Backend/Critic/Orchestrator/Solo/Test）
│   ├── app/            # JoyCode App 侧：agent bundles、能力矩阵、合规清单（🟡 未实测编排）
│   ├── cli/            # JoyCode CLI 侧：root-prompt，让 CLI 会话遵守 ACRS（🟢 已验证）
│   └── install/        # 各 binding 的安装说明（供 bin/acrs-install.sh 消费）
├── claude/             # Claude Code 载体（🟡 binding 已建，编排未实测跑 case）
│   ├── agents/         # 6 个入口薄壳（Claude 格式：name/description/tools/skills 预载）
│   └── install/        # 部署说明（acrs sync 用户级 / acrs-install.sh 项目级）
└── codex/              # OpenAI Codex 载体（🟡 binding 已建，编排未实测跑 case）
    ├── agents/         # 6 个入口 custom agent（Codex 格式：TOML name/description/developer_instructions）
    └── install/        # 部署说明（acrs sync 用户级 / acrs-install.sh 项目级）
```

## 现状与诚实分级
| 平台 | 状态 |
| --- | --- |
| JoyCode CLI | 🟢 已验证（见 `reference/joycode/` 的真实运行留痕） |
| JoyCode App | 🟡 设计意图（机制就绪，编排时序未实测） |
| Claude Code | 🟡 binding 已建（机制按官方 subagents 文档：frontmatter skills 预载 + Agent 工具显式授予；待真跑 case 后升 🟢） |
| Codex | 🟡 binding 已建（custom agent TOML 按官方 subagents 文档；skills 走开放标准 `~/.agents/skills/` 天然兼容；待真跑 case 后升 🟢） |
| Cursor | ⬜ 未建（见 ROADMAP Phase 5） |

> 新增平台 = 新建 `bindings/<platform>/`，遵循同样结构（agents/ + roots.conf + install/）。
