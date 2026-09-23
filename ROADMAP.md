# ACRS ROADMAP

> 节奏总览。原则：**规范已够用，下一阶段让它经受真实工程检验，而不是继续在文档层加抽象。**
> 图例：✅ 完成 · 🟡 进行中/部分 · ⬜ 未开始
>
> **北极星（Adoption 期，2026-07-30 立）**：开发者几乎感觉不到 ACRS 存在、却始终按它工作
> （Context 生命周期对业务透明）。⚠️ 透明是**成熟产品**的终点，非**验证期**目标——验证期需可观测以收集 findings。
>
> **决策（2026-07-30）：Bootstrap/Session 不设为第五层。** 它是横跨 Binding(on_init)/Convention(必载 acrs-shared)/Core(Handoff 续接)
> 的**横切契约**，不新增内容，按 P8 只做成 `docs/bootstrap.md` 文档，不与 Core/Convention/Binding 并列。
> 其"运行段"(Spawn/Handoff/Done)即 Mental Model 环，不重复造概念。`lifecycle.md`/`faq.md` 暂不写（避免重复与零用户虚构）。
>
> **决策（2026-07-30）：Activation 命名进 P4，不新增 P10。** "行为是激活出来的不是内嵌的"(Role+Convention+Domain=Executable Agent)
> 是准确洞察，但它拦的错误与 P4 的检查同源（行为该进 Convention 而非写死 agent.md）——按 P8，给 P4 换说法不构成新契约。
> 故写进 P4 正文 + `docs/bootstrap.md` Activation 节，principle 数量不增。
>
> **决策（2026-07-30，修订）：抽象冻结是【阶段性】的，不是永久原则。**
> 表述为「**During Validation phase**, every abstraction must be earned by repeated production findings」——
> 只在**验证期**生效，防的是"零验证时空谈概念"。**不写成永久"禁止新增抽象"**：未来 Claude/Codex/Codex/多-Agent-Runtime
> 的新能力**可能真的逼 Core 演进**，永久冻结会反噬自己。**解冻门槛**：某概念被 **≥2 个真实 Production Findings 反复暴露**
> （与 P8/P9 同源），才有资格进 Core/PRINCIPLES。**验证期内抽象冻结**：新概念须先经 ≥2 条真实 Production Findings 证明，才谈进 Core。

## Phase 0 · 理念探索 ✅
- ✅ 为什么需要 Multi-Agent（Manifesto）

## Phase 1 · 规范设计 ✅（约 85%，**主动停在这里**）
- ✅ RFC-000 Scope / Manifesto（Frozen 思想）
- ✅ RFC-000A Terminology（Frozen）
- ✅ RFC-000B Core Admission Protocol（Active v1.0，2026-09-22——打通 Convention→Core 上行通道；F-002/F-003/F-004 登记 Pending，待协议经一次真实闭环验证后逐条 Review）
- 🟡 RFC-001 Runtime Lifecycle（**Frozen Candidate v0.2**——已按 RFC-000B 逐节标注实证；转 Frozen 差判据 1/3 各 1 次实证）
- ✅ RFC/README.md（RFC 状态索引 + 三套原则编号对照表；登记断链：RFC-001 §7 引用的"Simple First"在 RFC-000 无编号条目）
- ✅ core/agent-contract（五段式 Schema + INV-VERIFY）+ agent-catalog（含准入闸门）
- ⬜ RFC-002 Handoff **不冻结**——见下方"RFC-002 冻结门槛"
- ⬜ RFC-003/004/005 待补（不急，等真实反馈）
- 📌 **决定：暂停写新 RFC。** 无真实验证，继续写 RFC 边际收益递减。（例外：经 RFC-000B Admission Review 的**增补**不受此限——增补不重写，且必须实证准入。）

## Phase 2 · Reference Implementation ← 现在
- ✅ acrs-shared（SKILL.md 行为规范层 + DESIGN.md 设计边界）
- ✅ Thin Agent 模式跑通（orchestrator/backend/review 已接 `on_init: [acrs-shared, 领域skill]`）
- ✅ PRINCIPLES.md（防再膨胀的自检铁律）
- ✅ bindings 结构：`bindings/joycode/{app,cli,skills}`（App/CLI = 同平台两入口）
- ⬜ 领域 Skill：`java-backend`、`code-review`（**下一步 #2**，本 ROADMAP 后紧接）
- 🟡 Reference 样例：✅ RI-001 BugFix · ✅ RI-002 强制 REJECT · ✅ 可移植性(App vs CLI)
  · ⬜ Feature · ⬜ Refactor · ⬜ Architecture

## Phase 3 · Validation 🟡（最重要，价值最高；方法见 `validation/README.md`）
**顺序调整**：DX 先行 → 真实项目跑 findings → 重复问题才沉淀成 Benchmark（Benchmark 来源于真实反复出现的问题，不凭空设计）。
- 🟢 ① **Quick Start + Mental Model + Bootstrap（DX 起步）**：`README`（Mental Model 动词环头图 + Entry Adapter 图 + 透明北极星）、`docs/mental-model.md`、`docs/quick-start.md`、`docs/bootstrap.md`（各平台启动加载链）（本轮完成）。
- 🟢 ②′ **case-000 回溯归档（2026-09-20）**：diy-orc 六周生产缺陷史（7 findings：F-001~F-007）逐条过分类闸门——6 Convention（3 条 Core 候选）/ 1 Binding / 0 Usage；F-002/003/004 终态 B·Promoted（≥2 次独立暴露，benchmark 候选）。**注意：回溯证据等级，非全流程跑通**——Phase 3.5 的"1 个真实 case 跑通"条件仍由 case-001 满足。
- 🟢 ②″ **ACRS-native Skills 落地（2026-09-20）**：按闸门结论重建 Skill 套装——acrs-shared 增补 R10~R13（澄清前置 / Acceptance 契约 / 接地模式谱系 / result 协议，均标 case-000 来源）+ 6 个角色 Skill（orchestrator / architect / backend / test / critic / solo，去 MCP 依赖、来源标注），本体住仓库顶层 `skills/acrs-*`（**能力资产，平台无关**）；JoyCode Binding 侧 = `bindings/joycode/agents/ACRS *`（6 薄入口）+ `bindings/joycode/install/`（部署说明），部署副本装于 `~/.joycode/skills/acrs-*` 与 `~/.joycode/agents/`。diy-orc 7 件套降级为历史参考实现，保留可回退。
- 🟢 ②‴ **资产层落地（2026-09-21）**：`assets/`（跨项目工程标准，首份 payment/java-backend-guardrails 脱敏自 fin-buddy@676aab9）+ 团队接入入口（根 `install.sh` 写 `~/.acrs/path` 指针 + `bin/acrs` init/path/assets/attach/feedback）+ 自我进化反哺闭环（每资产 `FEEDBACK.md` append-only 记录 → Rule of Three 消化：派生资产路由上游改源、原生资产直接改）。协议见 `assets/README.md`。**定位：资产层是 Phase 4 Extraction 的前置实验田**（资产被 ≥2 项目复用 → 候选抽 skill），不新增 Core 概念。
- ⬜ ② **真实项目连续使用**：在真实 Java 后端项目里用 **ACRS-native Skills** 做真实任务，产出定性 **Findings**（Production 线，case-001 起）。**现成首跑场景：资产三步接入（attach → 注入包携带 → DC 条目化 → Critic 勾对）。**
  **任务类型轮换（2026-09-22 立，外部评审建议收编）**：连续 case 刻意轮换 entry_type，防同型任务过拟合验证——case-001/case-004 已覆盖 Feature 全链（含 REJECT→设计修订→返工→复审翻绿），后续优先补：BugFix 快道（验 SOLO/FAST_TRACK 手感与 G-CLARIFY 探针）、Refactor（验回归纪律 baseline 模式）、跨模块/对外接口任务（验 case-003 对照组条款点火）。禁连续 2 个 case 同型（case-004 先于本规则落跑，不计违；case-005 起执行）。
- 🟢 ②′ **case-004 完成（2026-09-22，F04 资产三步接入）**：STANDARD Feature 全链含真实回退闭环（Critic BLOCKER→修复→复审翻绿）；产出首条真实闭环 Core Candidate（case-004#F-001，已登记 RFC-000B §5 Pending）；体系正例 3 项——case-003#F-004 覆盖边界声明首次生效、case-001#F-003 派发故障协议第 2 次暴露且正确执行、确认链落盘（parent 替换批准+spec 声明）；Case Run Ledger 首账落地（5 派发/1 REJECT/1 返工/2 人工，脏数据缺陷上线前被拦）。台账：`validation/production/case-004/`。
- 🟡 ③ **Findings 分类闸门**：每条 Finding 先归 Core / Convention / Binding / Usage(DX)，**再决定改不改**（防 Core 被平台问题污染，见 `validation/README.md`）。case-000 已首次走闸门（回溯补审）。
- 🟡 ④ **据分类倒逼规范**：哪层的问题改哪层，Core 改动门槛最高（须证明"换任何平台都会犯"）。case-000 的 3 条 Core 候选（F-002→agent-contract §3 细则、F-003→RFC-001、F-004→agent-catalog）已登记于 RFC-000B §5 Pending——**待协议经一次真实闭环验证后逐条 Admission Review，不默认批量晋升**。
- ⬜ ⑤ **Rule of Three**：同类内容真实重复 ≥3 次，才进入下一步。
- ⬜ ⑥ **Skill Extraction**：把重复的 Prompt 抽成领域 Skill（Phase 4）。
- 🟡 ⑦ **Benchmark**：真实反复问题脱敏成可复现 case（带确定性 oracle），此时才做定量 metrics 与开关对照。case-000 已登记 3 个 benchmark 候选（评审注入污染 / 澄清前置 / SOLO vs 拆分链），待 harness。（harness 落地后的回归方法约束已预定义：`validation/README.md` §Harness 自身变更的回归约束，源 fin-buddy@5ecfd07）
- 📌 **诚实边界**：真实项目跑不出干净 A/B，前期证据是**定性 findings 而非对照数字**；
  "ACRS 提高了成功率 X%" 这类结论要等 ⑦ Benchmark，别用 findings 预支。

## Phase 3.5 · Product-ization ⬜（刻意推迟——用第一个真实成功来换产品壳）
> 决策（2026-07-30）：ACRS 终将是**产品**不是 RFC，但"Product First"不能提前于 Validation。
> 在真实项目上**零验证**时就重命名成 Install/Getting-Started/Contributing、写"5 分钟跑通"营销 README，
> 是"过拟合"的升级版——**包装超前于实质 = 门面**。故 DX 现在只做到"诚实的文档"，产品化闸门如下：
- **触发条件**：至少 1 个真实 Production case 跑通 + 首批 Findings 归档。
- **届时才做**：文档改产品语义（Installation / Getting Started / Your First Task / Architecture / Validation / Contributing）；ACRS Lifecycle 生命周期图（安装→配置→首开发→首 Review→首 Reject→首 Handoff→Done）；README 卖"完成第一个任务"而非"结构说明"。
- **不做**：在此之前套产品壳。

## Phase 4 · Extraction ⬜（抽象，Skill 是 ⑤⑥ 的产物）
- ⬜ 领域 Skill（如 java-backend / code-review）只在真实重复 ≥3 次后抽取（P9），非设计阶段预设。
- 📌 **资产 → Skill 升级通道（2026-09-21 立）**：`assets/` 中某资产被 ≥2 项目独立复用且 FEEDBACK 消化过至少一轮 → 候选抽成领域 Skill 进 `skills/`（与 ⑥ 同判据；资产层是其前置实验田）。

## Phase 5 · 跨平台 ⬜
- ⬜ Claude Code binding（CLAUDE.md 作入口载体）——此时才触发 bindings 目录进一步重排
- ⬜ Codex（AGENTS.md）· Cursor（Rules）
- ⬜ **可移植对照**：同一套 Benchmark 上 JoyCode+ACRS vs ClaudeCode+ACRS vs Codex+ACRS
- 🎯 成功判据：同一 Core，仅换 Binding 就保持一致行为；若需动 Core，说明规范里仍混着平台细节。
- ⬜ **ACRS Capability Support Matrix**（**以后才做，非现在**）：`ACRS 能力（Evidence/Boundary/Handoff/Verification/Spawn/Context/Activation/Convention…）× 平台` 的支持矩阵，回答"这个平台支持哪些 ACRS 能力"。
  - ⚠️ 与现有 `bindings/joycode/app/capability-matrix.md`（JoyCode 内部诚实缺口）**不是一回事**，命名要区分。
  - 前提：**≥2 个平台 binding 落地**才有意义；现在只有 JoyCode + 零验证能力，建它=过拟合。可自动生成，留到那时。

---

## RFC-002 冻结门槛（三条实证，缺一不冻）
- ✅ REJECT 回环 + 打回 Spawn 新实例（RI-002）
- ⬜ Context 溢出续接（同类实例 Handoff 接力）——尚无实跑
- ⬜ 三层递归 SubAgent + CONV-TREE（每级只管直接子节点）——尚无实跑
> 前两阶段的 RI 都在 CLI 用 Agent 工具跑；APP 原生 Agent-to-Agent 时序仍待直接实测。

## 当前下一步（按性价比，DX + 真实项目优先）
1. ✅ acrs-shared 设计规范 + PRINCIPLES(P1–P9) + Validation 方法规范
2. ✅ DX 起步：README（Mental Model 动词环 + Entry Adapter 图）、docs/mental-model.md、docs/quick-start.md
3. ✅ Validation PDCA + Findings 分类闸门（Core/Convention/Binding/Usage）写进 validation/README
4. 🟡 **选定第一个真实验证项目**，在其上用 ACRS-native Skills 做真实任务，产出首批 findings（`validation/production/case-001/`；case-000 为 diy-orc 回溯归档已完成）
5. ⬜ 每条 finding 过分类闸门 → 哪层问题改哪层；重复 ≥3 次才抽 Skill / 沉淀 Benchmark
6. ⬜ 产品化（Phase 3.5）等首个真实 case 跑通后再启动，不提前套壳
