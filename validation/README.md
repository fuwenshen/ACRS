# Validation —— 让 ACRS 经受真实工程检验

> 从这里起，价值不再来自"再写规范"，而来自"证明规范真的提高了 AI Coding"。
> 本目录定义**怎么验证**（方法与契约）；具体案例**按需生长**，一个真实问题脱敏一个才建一个（P9，禁止预建空树）。

## ACRS 自己的 PDCA —— 规范演进走这条固定流程（不许"发现问题就直接改"）
```
真实问题
   ↓
建 Production Case（脱敏，只留结论+引用）
   ↓
用 ACRS 开发（CLI 全流程）
   ↓
记录 Findings
   ↓
【分类闸门】每条 Finding 先定性 → Core / Convention / Binding / Usage(DX)   ← 强制，先分类再谈改
   ↓
决定是否修改（哪层的问题改哪层，禁止跨层顺手改 Core）
   ↓
必要时才沉淀 Benchmark
```
> 这道流程本身就是 ACRS 的护栏：**任何规范改动都必须能回答"这属于哪一层的问题"**。

## Findings 分类闸门（防 Core 被平台问题污染 —— 最重要的一条纪律）
每条 Finding 在决定"改不改"之前，MUST 先归入且仅归入一类：

| 类别 | 判据（什么样的问题属于它） | 改哪里 | 例 |
| --- | --- | --- | --- |
| **Core** | 协议/不变量本身缺失或错误，任何平台都会犯 | `RFC/` `core/`（需 RI 实证）| Handoff 缺字段导致跨实例丢状态 |
| **Convention** | 行为规范表达不足，跨平台通用 | `acrs-shared/` | Evidence 结构不足以表达 Review 结论 |
| **Binding** | 某平台机制/时序特性引起，换平台就不一样 | `bindings/<平台>/` | JoyCode App 里 Agent 调 Agent 卡住 |
| **Usage(DX)** | 用户没理解/没装对，规范本身没错 | 文档/Quick Start | 用户不知道该导入 acrs-shared |

**铁律**：
1. **平台特性引起的问题，一律先归 Binding**，不许因为"在 Core 层改更省事"就改 Core。
2. 想改 Core，必须证明"**换任何平台都会犯**"，否则它就不是 Core 问题。
3. 分类有争议时默认归**低层**（Binding > Convention > Core），Core 改动门槛最高。

> 一句话：**Core 只被"平台无关的真问题"修改**。这是 ACRS 从"个人规范"长成"跨平台标准"而不烂掉的关键。

## Finding 的两个终局（防 findings/ 沦为无人再看的坟场）
> 规则：**Every production finding must either disappear or become a benchmark.**
> 每条 Finding 最终只能进入两种终局之一，不许无限堆积：

| 终局 | 条件 | 归档动作 |
| --- | --- | --- |
| **A · Closed（消失）** | 修完，后续再没复现 | 关闭；**若曾触发规范改动，必须回链改了哪层**（Core/Convention/Binding，接分类闸门）——留住"为什么改"的历史，别让 Closed 抹掉动机 |
| **B · Promoted（升级）** | **反复出现**（≥2 次同类）| 脱敏成 Benchmark case，进 `benchmark/`，以后所有平台反复跑 |

- **禁止第三态**："先记着以后再说"的开放 Finding 不许长期挂账——要么 A 要么 B。
- 这条与"分类闸门"配套：闸门管**改哪层**，终局管**这条 Finding 何时清账**。
- 反例警戒：`findings/case001…case872` 无人再看 = 验证失效。Finding 数量应**趋于收敛**，不是单调递增。

## 两条线（分工，不混淆）
| 线 | 来源 | 产出 | 作用 |
| --- | --- | --- | --- |
| **Production** | 真实项目 | 定性 **Findings** | 倒逼规范演化（改 Binding / Convention / Core）|
| **Benchmark** | 脱敏、标准化的可复现任务 | 定量 **Metrics** | 开关对照 + 跨平台对照 |

**流转**：真实项目发现值得研究的问题 → 脱敏/标准化 → 沉淀进 Benchmark → 长期维护、所有平台反复跑。
Benchmark 越攒越值钱，最终 `git clone` 就能让任何人跑自己的 Agent 做对比——ACRS 由此从"规范"变成"标准"。

## 目录（按需生长）
```
validation/
  production/            # 真实项目 findings（不含敏感代码，只留结论 + 引用）
    case-XXX/findings.md
  benchmark/             # 可复现、可公开、可对照
    java/bugfix/case001-.../
    ...                  # java/feature、python/... 等，出现真实需求才建
```

## Benchmark Case 契约（缺一不可比）
每个 case 目录 MUST 含：
- `task.md`：脱敏后的真实任务描述 + 验收判据。
- **处于坏状态的最小仓库快照**（可 build）。
- **确定性 oracle**：一个**失败的测试 / 复现脚本**，修好后必须 `exit 0`。
  —— 可比性的根基；**没有 oracle 的 case 不算 benchmark**（复用 Done Gate "只认退出码"）。
- （推荐）**planted defect**：故意埋一个"看起来对其实错"的坑，用来测缺陷逃逸 / 独立验证抓不抓得住。
- `expected.md`：正解要点，供**人工**核对，**不喂给被测 Agent**。

## 两种对照，绝不能混（范畴纠正）
> ACRS 不是 Claude Code / Codex 的同类竞品，它是**跑在平台之上的约定层**。故有两种正交对照：
1. **价值对照（同平台，ACRS 开/关）**：如 JoyCode 裸单 Agent **vs** JoyCode+ACRS 全流程。
   —— 证明"ACRS 到底加没加价值"，是护城河数据的**主对照**。
2. **可移植对照（跨平台，ACRS 恒开）**：JoyCode+ACRS **vs** ClaudeCode+ACRS **vs** Codex+ACRS。
   —— 证明"同一 Core 换 Binding 行为是否一致"（Phase 5 才做）。
> ⚠️ "ACRS vs Claude Code" 是范畴错误，别这么设指标。

## 指标（correctness-first；token 只作成本项，不吹节省）
每个 case、每个对照臂记录：
- **pass@1**：一次过是否正确（oracle `exit 0`）。
- **缺陷逃逸率**：planted defect 是否被 Review 抓住（漏掉 = 逃逸）——INV-VERIFY 的核心 KPI。
- **返工轮数**：到 PASS 前 Backend↔Review 往返次数。
- **回归引入**：是否弄坏了原本绿的其它测试。
- **成本项**：token / 墙钟时间 / Spawn 次数——如实记在"为正确性付的价"这栏，**不当成绩吹**。
> 指标**从案例里长出来**：先跑 1-2 个 case，看哪几个真有区分度，再固化。别先建十项仪表盘（P8）。
