# ACRS — Agent Convention & Runtime Spec

> 一套**平台无关的多 Agent 协作行为规范**。核心主张：
> **Agent / Skill / CLAUDE.md / AGENTS.md 都只是各平台的「入口载体（Entry Adapter）」，
> 真正跨平台不变的是 Core（Context / Handoff / Evidence / Boundary / Loop / Spawn）。**

## 它怎么跑（Mental Model —— 先记住这个环）

```
                    ┌────────────────────────────────────┐
                    ▼                                     │ REJECT（丢弃重来）
   Task ──▶ Context ──▶ Produce ──▶ Evidence ──▶ Verify ──▶ Decision
   任务      隔离边界     干活        留证据       独立验     判决  │
                                                              │ ACCEPT
                                                              ▼
                                                          Handoff ──▶ Done
```

> 任务进**隔离 Context** 干活 → 产物落成**可核对 Evidence** → **独立 Verify** 判决 →
> 通过就 **Handoff** 转移状态，不通过就 **Spawn 新 Context 重来**（不在污染上下文里打补丁）。
> 每个动词对应一条 Core 不变量，展开见 **[docs/mental-model.md](docs/mental-model.md)**。

## 它凭什么跨平台（Entry Adapter）

```
                        ACRS Core            ← 协议/不变量，永不随平台变
                    (RFC/ + core/)
                            │
                      acrs-shared            ← Convention：所有 Agent 必守的行为
                            │
        ┌───────────────────┼───────────────────┐
     JoyCode             Claude Code          Codex / Cursor
        │                    │                    │
   Agent(App)           CLAUDE.md          AGENTS.md / Rules   ← Entry：变的只有这一层
   Skill(CLI)               │                    │
        └───────────────────┴───────────────────┘
                            │
        Entry → Thin Agent → acrs-shared → Domain Skill → Runtime
```

> 换平台 = 换 Entry；上面那个环一行不改。这就是"为什么 Agent 可以那么薄"。

## 北极星：对业务开发透明
ACRS 的终态不是"设计得漂亮"，而是——**开发者几乎感觉不到它存在，却始终按它的规则工作**
（像 ESLint / Spring：没人天天读规范，但规范进了流程）。Context 爆了、Spawn、Handoff 都对业务开发透明。
- 任务如何启动 ACRS（每个平台的加载链）见 **[docs/bootstrap.md](docs/bootstrap.md)**。
- ⚠️ "透明"是**成熟产品**的终点，不是**验证期**的目标——验证期我们需要它**可观测**才能收集 findings。

## 四层结构
| 层 | 位置 | 是什么 |
| --- | --- | --- |
| **L1 Core** | `RFC/` `core/` | 协议与不变量（含 INV-VERIFY）。改动需 RI 实证。 |
| **L2 Convention** | `skills/acrs/acrs-shared/` | 所有 Agent 必守的行为，平台无关。 |
| **L3 Binding** | `bindings/joycode/{app,cli}/` | 平台入口载体——Skill 怎么被该平台加载/执行（当前只做了 JoyCode）。 |
| **L4 Validation** | `validation/` `reference/` | 真实/可复现地跑，证明它有用。 |

> **Skill 是 ACRS 的能力资产**（`skills/`，做什么/怎么做）；**Binding 只管接入**（某平台怎么加载它）。Skill 本体不属于任何平台。

## 现在处于哪一步（成熟度自评，不自封稳定）
- Core ★★★★☆ —— 设计自洽（RFC-000/000A 冻结、含 INV-VERIFY），但**从未在真实项目里活过一次**，"稳定"要靠 Validation 挣。
- Convention ★★★★☆ —— acrs-shared 就绪，待真实项目打磨。
- Binding(JoyCode) ★★★★☆ —— CLI 已具备验证能力；App 原生编排 🟡 未实测。
- DX ★★★☆☆ —— README/Quick Start 起步，**尚未做产品化**（刻意推迟到首个真实 case 跑通后，见 ROADMAP）。
- Validation ★★☆☆☆ —— 方法论已建（含 Findings 分类闸门），等真实项目。
- Benchmark ★☆☆☆☆ —— 未开始，来源于真实反复问题，不预造。

> 治理原则见 [PRINCIPLES.md](PRINCIPLES.md)（P1–P9）；节奏见 [ROADMAP.md](ROADMAP.md)；验证机制见 [validation/README.md](validation/README.md)。

## 从哪开始
**JoyCode 双路径（2026-09-21 收口）**：

- **形态 B · ACRS-native Skills（主推，case-001 验证主线）**：
  `bash install.sh && bin/acrs sync` —— 部署 6 角色 Skill + 6 Agent 入口到 `~/.joycode/`（全局用户级，所有项目可用；`acrs sync` 幂等可重跑校验漂移，单向以仓库为准）
- **形态 A · CLI 行为模拟（RI-001/002 已实证）**：
  `bin/acrs-install.sh --target <项目目录> --platform joycode-cli`（`--dry-run` 先预览）—— 项目级 `.acrs/` + 根提示词，单 Context 模拟 Orchestrator→Backend→Review

- 想 5 分钟上手 → **[docs/quick-start.md](docs/quick-start.md)**（我是 JoyCode 用户怎么用上 ACRS）
- 想懂"它怎么跑" → **[docs/mental-model.md](docs/mental-model.md)**（动词环）
- 想懂"任务怎么启动它" → **[docs/bootstrap.md](docs/bootstrap.md)**（各平台加载链）

## 路径规范与导读
目录语义、Artifact 命名（`handoff.yaml` / `evidence.yaml` / `review.yaml` / `result.md`——文件名表达类型而非 Agent）、谁读谁写生命周期、以及"业务代码目录 ≠ `.acrs/` 工作目录"铁律，统一见 **[docs/layout.md](docs/layout.md)**。核心三条：
- **目录语义固定**：每个目录承担什么语义查表即得，Agent 不需要猜。
- **文件名表达 Artifact 类型**：`backend-handoff.yaml` ❌ → `handoff.yaml` ✅。
- **协作状态不进业务树**：Agent 协作状态全部落在目标项目 `.acrs/` 下，删掉它项目必须照常构建。
