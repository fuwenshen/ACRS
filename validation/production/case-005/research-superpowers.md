# superpowers 研读底稿（case-005）

> 源：obra/superpowers v6.4.1（2026-09-18），2026-09-23 研读日快照（codeload tarball）。
> 子 Agent 全文深读产出，主控抽查承重论断属实（hooks matcher / TDD Iron Law / RELEASE-NOTES v6.4.1）。
> file:line 引用相对仓库根。下游引用请核对源版本，勿跨版本引行号。

## A. 一句话定位与设计哲学

superpowers 是 Jesse Vincent（Prime Radiant）开发的、跑在 16 个 coding agent harness 上的完整软件开发方法论插件，自述为 "a complete software development methodology for your coding agents, built on top of a set of composable skills and some initial instructions that make sure your agent uses them"（README.md:3-5）。设计哲学四条：TDD 永远优先、系统化优于临时起意、复杂度削减、证据优于断言（README.md:366-372）；执行姿态是 "Mandatory workflows, not suggestions"（README.md:323）——skill 一律自动触发，不允许逐会话 opt-in。

## B. 架构与分发

**核心是 session-start 强制注入**：`hooks/hooks.json:5` 用 matcher `"startup|clear|compact"` 让 bootstrap 在启动、清屏、压缩后全部重新注入；`hooks/session-start:27` 把 using-superpowers/SKILL.md 全文包进 `<EXTREMELY_IMPORTANT>` 标签输出。这是全体系的总闸门——验收测试就是 "Let's make a react todo list" 必须在干净会话自动触发 brainstorming（docs/porting-to-a-new-harness.md:86-106）。

**跨平台三 Shape**（docs/porting-to-a-new-harness.md:168-298）：
- **Shape A**：shell hook + JSON hook 声明（Claude Code/Cursor/Muse 等）
- **Shape B**：in-process 插件（OpenCode V2 原生 API 注册 skill，bootstrap 在 continuation/restart/fork/compaction 全存活）
- **Shape C**：instructions-file（GEMINI.md 用 `@` 语法引用 SKILL.md）

manifest 群覆盖 `.claude-plugin`、`.codex-plugin`（显式 `hooks: {}` 压制自动发现，否则 Codex 会错误注册 Claude 的 hook——RELEASE-NOTES.md v6.1.1）、`.kimi-plugin`、`.muse-plugin`、`.cursor-plugin`、`.hermes-plugin` 等。

**两大移植铁律**：
1. skills 写动作不写工具名（"dispatch a subagent" 而非 "use the Task tool"），工具映射放到 per-harness reference 文件（docs/porting-to-a-new-harness.md:59-63）
2. 一切走 harness 原生安装机制，绝不改用户配置文件（:65-77）

**打包健壮性细节**：所有脚本经解释器调用（`bash scripts/foo.sh`）而非依赖执行位——因为 Codex marketplace 和 MiniMax 的重打包会剥掉执行位，导致所有文档命令 `Permission denied`（RELEASE-NOTES.md v6.4.1 Fixes；#2301）。版本同步用 `scripts/bump-version.sh` 集中 bump 所有 manifest。

## C. 技能机制摘要表

| 技能 | 触发 | 核心机制 | 硬纪律 |
|---|---|---|---|
| using-superpowers | 每个会话开始（hook 注入） | 1% 法则强制技能检查；12 行 Red Flags 反合理化表；process skill 优先于 implementation skill | "even a 1% chance a skill might apply, you ABSOLUTELY MUST invoke the skill"（:10-16） |
| brainstorming | 任何创造性工作之前 | 三路径分流（spike/bounded/architectural）+ HARD-GATE 阶段门 + 棘轮 | "When in doubt between two paths, take the heavier one. The ratchet is one-way"（:86-88）；"A reply approves the stage actually presented"（:38-56） |
| writing-plans | 有 spec 后、动码前 | 计划头（Spec 指针/Global Constraints/Review Focus）+ Files/Interfaces 块 + No Placeholders | "A task's implementer sees only their own task; this block is how they learn the names"（:104-108）；禁 TBD/TODO/"similar to Task N" |
| subagent-driven-development | 执行多任务计划 | 控制器模式：task-brief/review-package 脚本、模型分层、5 轮 fix-loop 断路器、plan-scoped workspace | "Every dispatch states its model"（:204-206）；"Deviating from the plan without a ledgered ruling is a decision made in secret" |
| executing-plans | 内联执行计划 | ledger 即记忆 + task-start/task-done 脚本 + 连续执行不停顿 | 四停条件；"Rulings, not stalls"（:32） |
| test-driven-development | 实现任何功能/修 bug 前 | RED-GREEN-REFACTOR + 验证 RED 必须亲眼看 | Iron Law："NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"（:34）；"delete means delete" |
| systematic-debugging | 任何 bug/测试失败/异常行为，提修复方案之前 | 四阶段（根因→模式→假设→实施）+ 多组件边界证据插桩 | "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"（:17）；3 次修复失败→质疑架构（:195-212） |
| verification-before-completion | 宣称完成/修复/通过之前 | 门函数 IDENTIFY→RUN→READ→VERIFY→THEN claim | "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"（:17）；"Skip any step = lying, not verifying"（:24-36） |
| requesting-code-review | 完成任务/大功能/合并前 | dispatch 独立 reviewer subagent，传 SHA 范围不传会话史 | "Hand it precisely crafted context, never your session's history" |
| receiving-code-review | 收到评审反馈后 | 验证优先、YAGNI 检查、逐条分级回应 | 禁止 "You're absolutely right!" 表演性附和（:29-38） |
| using-git-worktrees | 需要隔离工作区时 | Step 0 检测既有隔离（`GIT_DIR != GIT_COMMON` + submodule guard）→原生工具优先→git 回退 | "phantom state your harness can't see"（:55）——禁绕过原生 worktree 工具 |
| finishing-a-development-branch | 实现完成、测试全绿后 | 3 选项菜单照原文呈现；typed "discard" 确认 | "Never `--force` on your own initiative... Show your human partner what is at stake and ask"（:180-198） |
| dispatching-parallel-agents | ≥2 个独立无依赖任务 | 独立域拆分 + prompt 结构模板 | 何时不用：有共享状态或顺序依赖 |
| writing-skills | 创建/修改任何 skill | 技能=TDD 对象：SDO 陷阱、Token 效率、Form-to-Failure、micro-test | "NO SKILL WITHOUT A FAILING TEST FIRST"（:379） |
| diagnosing-superpowers | 会话跑砸了（重复工作/忽略计划/技能没触发/账单异常） | 读 transcript 验尸，7 维并行 analyst subagent | "Every finding cites path:line. No citation, no finding"（SKILL.md:14-17） |

## D. 深层机制亮点

1. **Ruling 纪律 + Ledger（ACRS 可能缺的最大一块）**。SDD 和 executing-plans 共用："Rulings, not stalls"——控制器遇到计划冲突/歧义时不停等人类，而是记录裁决继续干活（RELEASE-NOTES.md v6.3.0：一个捐赠会话因为控制器本可自己决定的问题停摆了近 9 小时，#2077）。Ledger 是 plan-scoped 工作区（`.superpowers/sdd/<plan-basename>/`）里的进度账本，防跨计划污染（#2138 同名计划共享一个目录互相覆写）。裁决格式：`Ruling: <what> — <why> — <what it costs if wrong>`。"Deviating from the plan without a ledgered ruling is a decision made in secret"。**解决故障模式**：控制器压缩后失忆重派已完成任务（"the single most expensive failure observed"）、或停摆等人。**对应 ACRS 缺口**：ACRS 有 Handoff/Context，但没有「可继续推进但必须留痕的裁决」这个中间态——目前 ACRS 的选择大概是「停」或「问」，缺 "rule and continue with a receipt"。

2. **5 轮 fix-loop 断路器 + 升级模型**（SDD SKILL.md:373-429）。R1-3 resume 原 implementer（上下文还在，便宜），R4-5 换新 implementer + 更强模型（"fresh eyes and a capability bump in one move"），R5 触发后控制器 adjudicate：park with ruling 或对 load-bearing 问题裁决。"Adjudicating earlier to end a loop is pre-judging with a different name"——禁止提前打断来"省事"。**解决故障模式**：同一 reviewer finding 无限 ping-pong。**ACRS 落地点**：ACRS 的返工契约（rework）没有明确的失败次数→升级路径。

3. **模型分层显式化**（SDD SKILL.md:204-208）。每个 dispatch 必须显式指定模型："An omitted model inherits your session's model... silently defeats this section"——不写就静默继承最贵模型，曾导致一次 run 把全部 26 个 reviewer 派到顶配。原则："Turn count beats token price"（次数比单价贵）。**ACRS 落地点**：ACRS 派发规范里没有模型分层纪律。

4. **"Violating the letter of the rules is violating the spirit of the rules"**（多个 SKILL.md 反复出现，如 TDD:36、systematic-debugging:19、verification:15）。这一句直接堵死 agent 最爱的 escape hatch——"精神比字面重要，所以我这个 case 可以例外"。配套的是 9-12 行 Excuse/Reality 合理化对照表，逐条预演 agent 会怎么给自己找借口。**解决故障模式**：LLM 对禁令的礼貌性绕过。（已吸收进 acrs-shared R12。）

5. **SDO（Skill Discovery Optimization）陷阱**（writing-skills/SKILL.md:154-158）。description 只写触发条件、绝不概括流程——"A description saying 'code review between tasks' caused an agent to do ONE review, even though the skill's flowchart clearly showed TWO"。description 是检索入口，一旦概括了内容，agent 就会自以为懂而不读正文。（已吸收进 skills/README 写作规范。）

6. **Match the Form to the Failure**（writing-skills/SKILL.md:461-478）。纪律失守→禁令+合理化表；输出形状错→正面 recipe 范例；缺元素→结构化 REQUIRED 槽；条件行为→可观察谓词。且有 micro-test 实验证据："prohibition arm produced clearly more of the unwanted content than the recipe arm"——纯禁令在形状问题上反而更糟。（已吸收进 skills/README 写作规范。）

7. **Micro-test 方法论**（writing-skills/SKILL.md:577-587）。改 skill 措辞=改代码，必须测：一次一词、必设无引导对照组、"5+ reps per variant. Single samples lie."、"Variance is a metric"。删 recap/prose 也要 micro-test——v6.2.0 曾有一处删除可测量地劣化了行为（8/10→5/10），于是重写而非发布。

8. **"套件定义绿" 反假绿条款**（TDD SKILL.md:185-193）。"A green run of the test you wrote is not a green suite... a red test you watched scroll past and didn't mention is a report falsified by omission"——探测中 12 次有 11 次只跑单个文件，隔壁的坏测试视而不见，于是强制跑全项目套件并逐名上报。（已吸收进 acrs-shared R12。）

9. **Review Focus 节**（writing-plans/SKILL.md:79-89）。计划必须列出 5 个 spec 隐含但无任务覆盖的失败模式并逐条钉测试。起源：eval 中"每个 implementer 都在同一个 spec 未命名的输入上崩了"（RELEASE-NOTES.md v6.4.1）。

10. **评审独立性硬约束**（RELEASE-NOTES.md v6.0.0）。"The controller can't tell a reviewer what to ignore"——真实 run 抓到控制器教 reviewer 跳过 finding；"Reviewers are read-only and skeptical of rationales"。与 ACRS 评审独立性铁律同构。

## E. 弱点/局限

1. **强绑定单一作者审美，贡献近乎关闭**。AGENTS.md:7 审计出 94% PR 拒绝率；skill 改动必须附 before/after eval 证据（:95-100）。对 ACRS 这种以 RFC 进化为目标的社区型协议不可复制——它是个人品味驱动的产品，不是开放协议。
2. **中文/多语言场景缺位**。全部 skill 英文写作、无本地化层；而国内 Agent 平台 skill 通常中英混排甚至中文主体。
3. **token 成本靠"斤斤计较"而非结构性方案**。bootstrap 每会话全文注入 + 词法压缩——全是"省"出来的。ACRS 的按需加载在结构上更优。
4. **fix-loop 断路器是全局 5 轮，不分严重度轴**。比 ACRS 四轴粗——Critical 修不动（架构错）和 Minor 修不动（措辞）走同一个 5 轮循环。
5. **Windows/跨平台兼容靠逐 case 修复**，每个新 harness 都是一次性适配工作，无自动适配层。

## F. 与 ACRS 的映射

**ACRS 已覆盖**：Gate 注册表 ≈ HARD-GATE；接地/INV-VERIFY ≈ verification-before-completion；薄 Agent 厚 Skill ≈ 整体架构；四停条件 ≈ 不可逆轴；评审独立性；注入包 ≈ SessionStart bootstrap；反伪解精神 ≈ "letter=spirit"（措辞已吸收）。

**ACRS 缺、值得落地**：Ruling+Ledger 中间态（挂账 H-2）、断路器+模型升级（挂账）、模型分层显式化（挂账 H-3）、Review Focus 节（挂账 H-4）、SDO 描述规范（已吸收）、Form-to-Failure 表（已吸收）、套件定义绿（已吸收）、micro-test 方法论（挂账 H-5）。

**理念冲突、不该收**：全员注入 bootstrap、封闭贡献模式、全局 5 轮断路器。

## G. 值得注意的细节

1. **元设计：技能是 TDD 对象**。description 是检索入口、正文是行为规范、micro-test 是单测、eval 是集成测试——"薄 Agent 厚 Skill"路线下最成熟的元方法论。
2. **测试双轨制**（docs/testing.md:3-37）：`tests/`（非 LLM 集成）+ `evals/`（Quorum 驱动真实 tmux 会话）。只有静态 gate 适合公共 CI，行为测试放独立 eval 仓库。
3. **文档工程**：RELEASE-NOTES 每条机制变更都附真实故障案例，故障→机制一一对应。
4. **反 slop 治理**：AGENTS.md 要求一切贡献披露 "model, harness, version, and installed plugins"（:17）。
5. **细节健壮性**：`hooks: {}` 必须是空对象而非 `[]`；脚本一律经解释器调用防剥执行位；Hermes 无 post-compaction hook 就在 README 明写局限。

**总结**：superpowers 与 ACRS 在接地/评审/薄 Agent 方向高度同源，真正值得 ACRS 拿走的是五个东西——Ruling+Ledger 的中间态、模型分层纪律、Review Focus 节、SDO 描述规范、以及全套 Excuse/Reality 合理化表措辞库；不该收的是其全员注入的成本模型和封闭的贡献模式。
