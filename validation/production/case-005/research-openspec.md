# OpenSpec 研读底稿（case-005）

> 源：Fission-AI/OpenSpec v1.13.1，2026-09-23 研读日快照（codeload tarball）。
> 子 Agent 全文深读产出，主控抽查承重论断属实（AGENTS.md 空文件 / #1385 注释 / SHALL-MUST 检测）。
> file:line 引用相对仓库根。下游引用请核对源版本，勿跨版本引行号。

## A. 一句话定位与设计哲学

一个让"人与 AI 先就 specs 达成一致、再写代码"的轻量级 spec 驱动开发框架，核心反目标是一切 rigid/waterfall/ceremony。哲学原文（README.md:28-34）：

```text
→ fluid not rigid
→ iterative not waterfall
→ easy not complex
→ built for brownfield not just greenfield
```

动机（README.md:194）：*"AI coding assistants are powerful but unpredictable when requirements live only in chat history"*。与 Spec Kit 对比定位（README.md:203）：*"Thorough but heavyweight. Rigid phase gates, lots of Markdown, Python setup. OpenSpec is lighter and lets you iterate freely."*

## B. 核心工作流：从想法到 archived spec 的完整生命周期

双区结构（docs/concepts.md:37-48）：`openspec/specs/` = source of truth（系统当前行为），`openspec/changes/` = 提议中的修改（每个 change 一个文件夹，delta 形式）。

| 阶段 | 命令/入口 | 文件产物 |
|---|---|---|
| 1. 探索（可选） | `/opsx:explore` | 无产物，纯对话（README.md:150） |
| 2. 建 change | `openspec new change "<name>"` | `openspec/changes/<name>/.openspec.yaml`（元数据：schema、created、skip_specs、retire_capabilities，docs/concepts.md:193） |
| 3. 产 artifacts | `/opsx:propose` 按 schema 依赖图逐个生成 | `proposal.md`（why/what）、`specs/<capability>/spec.md`（delta：ADDED/MODIFIED/REMOVED/RENAMED Requirements）、`design.md`（how，条件性）、`tasks.md`（checkbox 清单）——schemas/spec-driven/schema.yaml:4-247 |
| 4. 校验 | `openspec validate <change>` | 无产物，退出码 0/1 + 结构化报告 |
| 5. 实现 | `/opsx:apply` | 勾 tasks.md 的 `- [x]`（apply "tracks: tasks.md"，schema.yaml:242-247）；改项目代码 |
| 6. 归档 | `openspec archive <change>` | ① delta 逐条合并进 `openspec/specs/<capability>/spec.md`；② change 目录改名移入 `changes/archive/YYYY-MM-DD-<name>/` 全文保留（docs/concepts.md:528-551） |
| 7. 归档后审计 | `openspec validate --archived` | 校验归档 change 的 tasks 是否全部勾完（validate.ts:611-706） |

关键：workflow 由 schema.yaml 的 artifacts 依赖图定义（proposal→specs→design→tasks，schema.yaml:148-150, 183-185, 238-240），且明确 *"Dependencies are enablers, not gates"*（docs/concepts.md:458）——与 ACRS 的 FROZEN 闸门哲学相反。

## C. validate 的精确实现

**运行时与依赖**：Node.js ≥20.19.0（README.md:125），TypeScript + Zod，MIT 协议。本地复用 = `npm install -g @fission-ai/openspec` 后调 CLI（含 `--json` 结构化输出），或直接抄 `src/core/validation/` 代码（无外部重依赖，核心只依赖 zod + 自研 markdown parser）。

**双层架构**：
- **Zod schema 层**（数据形状）：
  - `RequirementSchema`：text ≥1 字 + scenarios ≥1 条（src/core/schemas/base.schema.ts:15-18）
  - `SpecSchema`：name/overview ≥1、requirements ≥1（spec.schema.ts:5-15）
  - `ChangeSchema`：why 长度 ∈[50,1000] 字符、whatChanges ≥1、deltas ∈[1,10]（change.schema.ts:26-32；阈值 constants.ts:6-12）
  - 注意：SHALL/MUST 校验刻意不进 Zod（base.schema.ts:9-14 注释：parser 把 header 折进 text，Zod refine 会发误导性错误，故移到命令式层）
- **命令式规则层**（大头，`Validator.validateChangeDeltaSpecs`，validator.ts:164-531）：

**逐条规则清单**（ERROR=阻断，WARNING=默认放行/--strict 阻断，INFO=永远放行）：

1. ≥1 个 delta，否则 ERROR（除 `.openspec.yaml` 声明 `skip_specs: true`，validator.ts:518-524）
2. `skip_specs: true` 但 `specs/` 下有任何文件 → ERROR 冲突；`specs/` 不可读时 **fail-closed** 按有文件处理（validator.ts:498-513）
3. ADDED/MODIFIED 每条 requirement MUST 含 ≥1 个 `#### Scenario:`（恰好 4 个 #；schema.yaml:95 警告 *"Using 3 hashtags or bullets will fail silently"*）；空 scenario header 不计数（validator.ts:305-308, 1053-1056）
4. requirement 正文缺 SHALL/MUST → WARNING（正文空=ERROR）；header 里有正文里没有时给定向提示（validator.ts:1029-1040）
5. RENAMED 的 FROM:/TO: 必须成对，未配对 → ERROR（validator.ts:231-239）
6. 同 section 重名、跨 section 冲突（MODIFIED∩REMOVED、ADDED∩MODIFIED 等）→ ERROR（validator.ts:277-431）
7. **scenario 丢失检测**：MODIFIED 块对照当前主 spec，漏抄主 spec 还有的 scenario → ERROR（MODIFIED 是整块替换，归档时漏的会真丢）（validator.ts:671-756）
8. **布局守卫**：`specs/spec.md`（根级）或非 `spec.md` 命名的 delta 文件——合并路径会静默丢弃 → ERROR（validator.ts:188-197, 465-472）
9. **归档 dry-run**：跑 archive 的合并器 `buildUpdatedSpec`，"Archive would refuse this delta" 报为 INFO 不动 verdict（validator.ts:924-979）
10. tasks.md lint：checkbox 缺失/编号跳跃 → WARNING（validator.ts:547-579）
11. strict 模式：`valid = errors===0 && warnings===0`；默认只看 ERROR（validator.ts:986-988）

**schema 格式**：不是 JSON Schema，是自研约定——Zod 定义对象形状 + markdown parser 产出结构 + 命令式规则。`schemas/` 目录只有 `spec-driven/schema.yaml`（工作流定义，非校验 schema）+ 模板 md。

## D. 深层机制亮点

1. **校验器与合并器共用同一解析器**——防"validate 绿但 archive 丢数据"。原文（validator.ts:176-181）：*"Discover delta specs through the same helper the change parser, show, apply, and archive use, so **validate never accepts a layout the merge path silently skips** (#1385)"*。
2. **故障前置**：scenario 丢失检测从 archive 提前到 authoring 期（validator.ts:346-348）：*"so the change fails at authoring time instead of days later at archive time (#1477)"*。
3. **退休守卫（unaccountedContent）**：删除整个 spec 文件前，合并器必须能解释文件里**每一行非空内容**，解释不了就拒绝删除。原文注释（specs-apply.ts:186-201）：*"for seven rounds it looked for requirement-SHAPED text and was beaten by a new disguise each round... **Fails safe in every direction: a line this cannot classify counts as unaccounted, which refuses rather than deletes**"*。
4. **fail-closed 纪律贯穿**：skip_specs 探测 specs/ 读不了按"有冲突"处理（validator.ts:498-509）；archive 目录权限错误不许冒充"无归档 change"——*"that would let a pre-commit lint pass without inspecting anything (#205)"*（validate.ts:585-598）；task 文件存在但读不了 → *"must fail loudly, not be silently counted as 'no tasks' and pass"*（validate.ts:640-648）。
5. **三态分级 + strict 档位**：ERROR/WARNING/INFO 与归档 dry-run 的"报告但不动 verdict"；`--strict` 把 WARNING 提为阻断（validator.ts:986-988）。配套 `--report findings` 只输出有问题的项（validate.ts:64-79）。
6. **Agent 集成走 skills 而非 AGENTS.md 静态注入**：根 AGENTS.md 是**空文件**；`legacy-cleanup.ts` 专责检测/迁移带 marker 的 AGENTS.md 与旧 slash commands（legacy-cleanup.ts:231-238）。新载体是 `skills/`（12 个，含 propose/apply/archive/verify/bulk-archive/onboard），带 `allowed-tools: Bash(openspec:*)` 最小权限（skills/openspec-propose/SKILL.md:4）。
7. **planning boundary（规划/实现分离的硬边界写进 skill）**（SKILL.md:14）：*"This workflow creates planning artifacts only... **Do not start implementation in the same response, even if the initial request asks for it**"*。
8. **对 Agent 的元层防御性指令**：`"root": null` 是答案不是故障，*"read the JSON instead of retrying or working around it"*（SKILL.md:30）；status 是 file-existence 而非质量，要求 Agent 沿 `requires` 边做传递闭包（SKILL.md:131-132）；*"re-read them from disk, even if you saw them earlier in the conversation (the user may have edited them)"*（SKILL.md:119）。

## E. 弱点/局限

1. **接地深度浅：证据全是自我声明**。validate 管格式，`--archived` 管的"完成"只是 checkbox 字符：`- [x]` 谁都能打（validate.ts:649-655）。无 build/test 退出码采集，无 evidence 字段——DONE 判据是弱证据。这是与 ACRS 最大的互补点而非可抄点。
2. **英文单语言假设**：SHALL/MUST 检测仅英文（validator.ts:827-831）；中文 spec 的规范词会全部漏检。
3. **Markdown 作为数据格式的持续税**：恰好 4 个 # 否则 fail silently；code fence 内假 scenario 要专门 mask——格式解析器是永久维护负担（specs-apply.ts:186-199 自认七轮对抗性修补）。
4. **主校验路径不查 proposal.md**：`validate <change>` 走 `validateChangeDeltaSpecs`（validate.ts:337），proposal 的 Why 长度/What Changes 只在 `validateChange`（非阻塞 warning 用）里查——"validate 通过"不等于"全部产物合格"。
5. **逃生门是自我豁免**：`skip_specs: true` 由 change 作者自己声明即可绕过全部 delta 校验（validator.ts:518-524），仅靠 skill 指令约束滥用——prose，零 enforcement。

## F. 与 ACRS 的映射

**已覆盖**：机器可读契约（docs/agent-contract.md ≈ ACRS core/agent-contract.md，且 OpenSpec 多一层 exit-code 契约表值得补）；归档审计闭环 ≈ validation/production 的 case/findings 闭环（ACRS 更重）；四轴/评审独立性/注入包协议在 OpenSpec 无对应。

**ACRS 缺的（可落地，按优先级）**：

1. **`bin/acrs validate` 子命令（最大缺口，直接抄 C 节三层结构）**。ACRS 自己已写明路径（validation/README.md:31）：*"可下沉为机制/工具强制的优先下沉（P7 同源：机制强制 > 纪律自律）"*。最小可抄清单：注入包 JSON 校验（injected_artifacts 只认 status∈{APPROVED,FROZEN}，现为 prose skills/acrs/acrs/SKILL.md:175）；DC-xx 硬格式校验（id/desc/sensitive，格式已在 acrs/SKILL.md:169 定义）；checklist_coverage 完备性（coverage 必须覆盖注入包全部 DC id，对应 OpenSpec 的 scenario 丢失检测 validator.ts:738-756）；Gate 证据 fail-closed（证据文件存在且可读，读不到=不达标，抄 validator.ts:498-509）；退出码接地（validate 失败 exit 1，判 DONE 前必跑）。
2. **三态分级 + curated 降档机械化**：ERROR/WARNING/INFO + `--strict` 是现成模型：curated 条目违例=WARNING，empirical 违例=ERROR（ACRS 已有 `DC-xx(curated)` 降档概念 assets/README.md:27，但无机械表达）。
3. **共用解析器铁律**：若 bin/acrs 同时有 sync 和 validate，两者必须共用同一份注入包/DC 解析代码——#1385 教训原样适用。
4. **测试策略**：真实临时目录 + 每条规则正反例 + 文件名=故障模式（test/core/validation.test.ts 结构）。

**理念冲突不该收**："fluid not rigid / no phase gates"（与 APPROVED/FROZEN 直接对立）；skip_specs 式自我豁免（ACRS 豁免必须总控显式分型）；checkbox 即完成的弱接地。

## G. 值得注意的细节

- **每条规则都有 issue 编号 + 故障模式注释**：#1385/#1477/#205/#1182/#1846/#1280/#1520/#1302 散布全部源码，注释先讲"什么会出错、为什么这样防"再讲实现——源码即故障台账。
- **阈值全公开常量**：MIN_PURPOSE=50、MAX_WHY=1000、MAX_REQUIREMENT_TEXT=500、MAX_DELTAS=10（constants.ts:6-12），且校验与生成共用同一常量，防两处漂移。
- **仓库全量自举**：openspec/changes/ 下 28 个在途 + 83 个归档 change；install.md 本身是一份 Agent 任务提示词，带 DONE WHEN 验收清单（install.md:33-45）。
- **telemetry 默认开**、仅命令名+版本（README.md:248-250），CI 自动关。
- **`validate --archived` 的定位**：*"an archived change with unchecked tasks is a real integrity problem the normal validate flow never surfaces"*（validate.ts:620-631）——归档后还有审计层，对应 ACRS 的收口复盘扫描。

**一句话结论**：OpenSpec 最大的可移植资产不是它的理念（与 ACRS 的闸门哲学部分相冲），而是它把"格式契约 → 三态分级 → fail-closed → 退出码接地"四个性质做成机械校验的完整工程范式——ACRS 的 Gate/DC 勾对要补的正是这一层，`bin/acrs validate` 可按本报告 C/F 两节直接开工。
