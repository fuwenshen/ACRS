# bindings/ — 平台入口载体（L3 Binding）

> 本目录回答一个问题：**某平台怎么加载 ACRS？**
> Skill 本体（`../skills/`）不属于任何平台；这里只管"接入"——Agent/Skill 怎么被该平台识别、加载、执行。换平台 = 换一层 binding，Core 与 Skill 一行不改。

## 目录结构
```
bindings/
└── joycode/            # 当前唯一已建 binding
    ├── agents/         # 6 个 ACRS Agent 定义（Architect/Backend/Critic/Orchestrator/Solo/Test）
    ├── app/            # JoyCode App 侧：agent bundles、能力矩阵、合规清单（🟡 未实测编排）
    ├── cli/            # JoyCode CLI 侧：root-prompt，让 CLI 会话遵守 ACRS（🟢 已验证）
    └── install/        # 各 binding 的安装说明（供 bin/acrs-install.sh 消费）
```

## 现状与诚实分级
| 平台 | 状态 |
| --- | --- |
| JoyCode CLI | 🟢 已验证（见 `reference/joycode/` 的真实运行留痕） |
| JoyCode App | 🟡 设计意图（机制就绪，编排时序未实测） |
| Claude Code / Codex / Cursor | ⬜ 未建（见 ROADMAP Phase 5） |

> 新增平台 = 新建 `bindings/<platform>/`，遵循同样四件套结构。
