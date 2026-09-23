# RFC-000B Core Admission Review — 首次真实运行评审报告（归档件）

> **派发**：ACRS 总控（独立实例评审，任务书只含审什么/依据/范围，不含结论）。
> **评审者**：ACRS Critic（独立实例）｜**完成**：2026-09-23。
> **对象**：RFC-000B §5 Pending 表 4 条候选（case-000#F-002 / F-003 / F-004 + case-004#F-001）。
> **协议**：RFC-000B §3 五步判定。**verdict：PASS_WITH_NITS**。
> **决策执行**：见 RFC-000B §5 决策登记表；Convention 吸收与口径判例已同期落盘。
> 以下为评审者产出原文（verbatim）。

---

## 〇、任务书与证据的矛盾标注（以证据为准）

1. 任务书称 PRINCIPLES 位于 `RFC/RFC-000-architecture-manifesto.md`。**证伪**：该文件是历史邀评稿（v0.1 Draft，Principle 3 = Human-in-Loop）；"P-3 只写行为不写 HOW / P8 抽象冻结"实际出处为根目录 `PRINCIPLES.md`（P3 Behavior>Implementation，PRINCIPLES.md:17-20；P8 Earn Every Abstraction，PRINCIPLES.md:49-55）与 `RFC/RFC-000-Scope.md:73`。本次判定按真实出处执行。
2. 任务书（源自 case-000 findings 闸门判定）称 F-003 落点前提"RFC-001 已有 DISCUSSING 态原型"。**证伪**：grep `RFC/` 全目录无 DISCUSSING、无 Intent Freeze；RFC-001 v0.2 §2 Task 状态为 Created→Running→Done→Closed（RFC-001:49-54）。落点前提失效，判定中已修正。
3. 任务书要求"只读不写、文本回传"与 acrs-critic 手册"review-report 落 docs/review/"冲突——按任务书执行（更具体的派发指令优先）。

## 一、候选 1：case-000#F-002 评审喂答案污染 → 目标 core/agent-contract.md §3

**五步逐条**：

| 步 | 结论 | 依据 |
|---|---|---|
| 1. P8 契约级 | **✓** | 新增约束的行为主体是**注入侧**（Orchestrator→验证者的 Handoff 内容），现有 §3 INV-VERIFY 只约束验证者侧"不得采信自述"（agent-contract.md:79-83），未约束注入侧"不得喂结论"——行为主体不同，属规则真空而非措辞差异。P8 三问全过 |
| 2. Evidence 可解 | **✓（附标注）** | ① case-000/findings.md:19-28（F-002 全文）；② 第二次独立暴露落盘 reference/joycode/bugfix-reject/cli-binding/PORTABILITY.md:20-37——"Reviewer 的记忆里就有 Backend 刚才的每一处改动"= 验证者输入侧被污染的独立实测形态。两处均亲读核验。标注：case-000 为回溯证据等级（case-000/README.md:3-5），协议未区分证据等级，接受但如实记档 |
| 3. 平台无关 WHAT | **✓** | 验证者收到携带结论的任务书即产生锚定（confirmatory bias），含人类审计——认知层现象，平台无关 |
| 4. Core boundary | **✓** | "验证者输入 MUST NOT 携带上游验收结论"是 WHAT，可画进 Runtime Sequence Diagram（Orchestrator→Reviewer 箭头的 payload 约束）；"倾向转待核验清单"等操作形态已在 Convention（R5/acrs-critic §〇），不随迁 |
| 5. Decision | **Admitted** | 见下 |

**Decision：Admitted**。落点建议（增补不重写，RFC-000B §4.1）：
- `core/agent-contract.md` §3 增补一条 MUST（暂名 INV-INPUT）："验证者实例的输入（Handoff Package）MUST NOT 携带任何关于被验产物的上游验收结论（'已确认/全部落地'类断言）；上游倾向性观察只能以**待核验清单**形态进入，验证者一律按待验证假设处理。"脚注证据链：`[Validated @ case-000#F-002; PORTABILITY（弱隔离旁证）]`。
- 同步 §4 Conformance 增判据 5——满足 §4"每条 MUST 配可观测判据"（RFC-000-Scope.md:96-98）。
- 版本 +0.1（RFC-000B §1 版本规则）。
- ⚠️ 附注：agent-contract 现为 Draft v0.1，RFC-000B §2 标注义务仅覆盖 Frozen Candidate 及以上——建议本次增补自愿携带 Evidence Status 标注（协议缝隙，见校准观察）。

## 二、候选 2：case-000#F-003 需求没问清白做 → 目标 RFC/RFC-001

**五步逐条**：

| 步 | 结论 | 依据 |
|---|---|---|
| 1. P8 契约级 | **✓** | "存在实质分叉未澄清 MUST NOT 开工"是 Task 状态转换前置条件（Created→Running 守卫），契约级 |
| 2. Evidence 可解 | **⚠️ 资格存疑** | findings 存在可解（case-000/findings.md:32-41）。但独立核验暴露计数：① diy-orc 实战（回溯）；② "用户明文通则确认"——**通则确认是对既有事件的总结性权威确认，非第二次缺陷暴露**，未产出新的可解引用缺陷观察。对照 F-002（PORTABILITY 独立实验产出新观察）与 F-004（RI-001 独立实验产出新观察），本条第二来源不独立。实际独立暴露 = **1** |
| 3. 平台无关 WHAT | **✓** | 人团队同理（case-000 findings 闸门判定成立） |
| 4. Core boundary | **✓（若 Admitted）** | 落点形态应为 RFC-001 §2 "Running 进入条件"增澄清前置守卫；五类扫描/姿态选择（独立→摆全/依赖→grilling）属 HOW，留 R10/G-CLARIFY。但原落点前提（"已有 DISCUSSING 态原型"）经 grep 证伪（见 §〇.2） |
| 5. Decision | **Deferred** | 见下 |

**Decision：Deferred**。触发条件（满足其一即重开 Review）：
- a) 再次**独立**暴露 1 次澄清缺失导致的白做/返工事件（新 case 在线留痕，非回溯）；
- b) case-000 已登记的 benchmark 候选（"澄清前置 vs 直接派发"返工轮数差实验）落地并复现该缺陷。

理由：① 资格门槛 ≥2 独立暴露按独立口径未达（"用户通则确认"不计），灰色升一档 fail-closed；② Convention 层 R10 已稳定承载且在 case-001~004 四个 case 的 G-CLARIFY 中真实执行、无违反观察——Core 化无紧迫性（铁律 3"有资格 ≠ 现在就进"，何况资格存疑）。附带产出：将"通则/权威确认 ≠ 独立暴露"记为计数口径判例（Convention 层吸收，不走 Core）。

## 三、候选 3：case-000#F-004 bugfix 拆分链修不到位 → 目标 core/agent-catalog.md

**五步逐条**：

| 步 | 结论 | 依据 |
|---|---|---|
| 1. P8 契约级 | **✓** | "连贯性不可跨 Handoff 无损传递时不得拆分推理链"（连贯性密度判据）是任务路由契约 |
| 2. Evidence 可解 | **✓** | ① case-000/findings.md:45-54；② RI-001 独立实验（reference/joycode/bugfix/findings.md:10-14 A-1：bugfix 单 Context 连贯完成、未派 Architect 更优）——真独立、真可解、产出新观察。四条候选中证据质量最佳 |
| 3. 平台无关 WHAT | **✓** | 人团队改 bug 由同一人从头跟到尾同理 |
| 4. Core boundary | **✓ 行为 / ✗ 落点** | 行为是 WHAT、可画进时序图。**但落点核验失败**：agent-catalog.md:3 自我声明"Core-adjacent 参考目录，**不是 Core 强制项**"，agent-catalog.md:10-13 明示"某个 Workflow 用哪几个是那条 Workflow 的选择"——该文档不承载 MUST；"bugfix 默认归 SOLO"写进 catalog 违反其自身地位及 agent-contract §4 判据 4 同源精神（agent-contract.md:107）。真正能承载的 RFC-003（Loop Convention）**尚未存在**（RFC/ 无此文件，ROADMAP 槽位） |
| 5. Decision | **Deferred** | 见下 |

**Decision：Deferred**。触发条件（满足其一）：
- a) RFC-003（Loop Convention）立项开写时，本条作为 Worker Loop 连贯性条款的一级输入并入（五步 1–4 已预审通过，届时直接进落点设计）；
- b) 若坚持落 agent-catalog，须先经 RFC 流程变更其自身地位声明——该变更不得由 Admission 顺手完成（增补不重写，RFC-000B §4.1）。

理由：证据、平台无关性、行为 WHAT 全过，唯一阻断是**落点承载能力**——Admission 协议无权改落点文档的地位声明。现有 Convention 固化（acrs-orchestrator 连贯性密度判据 + acrs-solo 全文）持续有效承载。

## 四、候选 4：case-004#F-001 系统边界输入验证缺失 → 目标未定

**五步逐条**：

| 步 | 结论 | 依据 |
|---|---|---|
| 1. P8 契约级 | **✗（关键分岔）** | 三层核验：① 缺陷本体是**工程实现缺陷**（四字段有 FinAssert 而 source 无——业务代码漏校验），非多 Agent 协作契约缺失。判例先例：case-001#F-001 闸门（case-001/findings.md:22）"平台无关，但属 Context 构造范畴，**非多 Agent 协作契约缺失** → 不进 Core"。② 体系层定性：全链 = Critic 独立评审拦截 BLOCKER → 回退链正确回流 → 修复 → 复审翻绿（case-004/findings.md + Case Run Ledger，REJECT 1、回退链 1 且正确）——**这是体系护栏的实测成功，不是协议缺失的证据**：INV-VERIFY + DC 契约（R11）架构上已覆盖且实测拦截成功。③ 诊断协议（validation/README.md:41-50）：体系侧无规则真空——acrs-critic 设计清单 5 敏感域条款已架构覆盖，至多是 Convention 表达强度不足（未操作化到"系统边界输入"粒度） |
| 2. Evidence 可解 | **✓（深度属实）** | case-004/findings.md 存在，证据链描述属实；但独立暴露 = **1**，未达 ≥2 门槛 |
| 3. 平台无关 WHAT | **✓（但非充分）** | 任何平台 AI 都可能漏写校验。注意此步仅为必要条件：case-003 四条 finding 全平台无关却全归 Convention——"平台无关"对 Core vs Convention 无区分力 |
| 4. Core boundary | **✗** | 拟议内容是**业务工程规范**非 Agent 协作契约：写进 agent-contract 违反其单一职责（agent-contract.md:8-10）；ACRS Core 的 "Boundary"= Done Gate 验收边界（RFC-000-Scope.md:100-102），与"系统边界（API input boundary）"**同名异义**——新造不变量条款会引入术语冲突，违反 RFC-000A 术语纪律（RFC-000A-Terminology.md:9-11） |
| 5. Decision | **Rejected** | 见下 |

**Decision：Rejected**。回落与去向：
- **回落 Convention**（主）：acrs-architect design_checklist 指南增补建议（"涉及对外契约/系统边界输入时，每个入参必须有校验/拒绝语义的 DC 条目"）+ acrs-critic 设计清单 5 敏感域清单扩展——与 case-003#F-001（同类对照）、F-002（框架咬合）同性质同归层先例完全一致。该增补走 Convention 常规吸收管道（skills 维护者），非本次 Admission 产出。
- **Benchmark 登记**（建议）：本案是"深度证据"的正确去向——缺校验字段→脏数据不可自愈是极好的 planted defect 素材（测 Critic 抓出率，与 case-000 F-002 benchmark 候选设计同构）。
- 若 Convention 固化后同类缺陷**仍**双漏检（设计+评审都放行）且第 2 次独立暴露，届时以新证据重开分类闸门，不复活本条。

## 五、协议校准观察（只记录，不改协议）

**判定清晰的步骤**：
- 第 1 步 P8（契约级 vs 措辞）：可操作、区分力强——case-004#F-001 正是被此步正确挡出 Core（"体系成功拦截 ≠ 协议缺失"）。
- 第 2 步的可解引用检查：操作明确（打开文件核验），本次 8 份引用文件全部亲读可解。
- 第 3 步平台无关：判据清晰，**有效排除 Binding 类问题**——但对 Core vs Convention 无区分力，其角色是必要条件过滤器而非决策步。

**存在自由裁量空间的步骤**：
- 第 2 步只验"编号存在可解"，**未定义"独立暴露"口径**：通则确认算不算？（F-003 实测：不算）同母题不同形态算不算？（F-002 实测：算，因 PORTABILITY 产出新观察）——本次区分标准由评审者自造（"是否产出新的可解引用缺陷观察"），协议无此定义，跨评审者复现性存疑。
- 第 4 步判行为、**不判落点承载能力**：F-004 暴露此缝隙——行为五步全过，目标文档（agent-catalog）自我声明不承载 MUST。协议缺"落点核验"子步。
- 第 5 步 Deferred/Rejected 边界未定义决策树：本次自造标准="行为是否已过前四步"（过而受阻于外部条件→Deferred；受阻于本体定性→Rejected），协议未载明。
- §2 证据标注义务仅覆盖 Frozen Candidate 及以上：agent-contract 是 Draft v0.1——Admitted 条款进 Draft 文档时标注是否强制、core/ 文档是否适用 +0.1 版本规则，协议未覆盖。
- 候选来源（§3 首"≥2 次独立暴露"）与 §5 表（case-004#F-001 按 1 次深证据登记）存在协议内张力：入场时是否复检 ≥2、Review 时安全网是否需重审资格，协议未分工。

**B-1 边界案例（单次暴露、证据深）的处理路径**：
- 协议给出的路径：§5 表"按证据质量登记，Admission Review 时独立判定"——**有入场通道 ✓**；但五步本身无"证据深度"替代判据，深度只存在于登记表脚注。
- 实测结论：深证据弥补的是**举证强度**，弥补不了**定性**——B-1 的核心矛盾是"缺陷是工程缺陷、拦截是体系成功"，第 1 步（P8 契约级）正确将其挡出，路径清晰可用。
- 协议未答的元问题："体系护栏**正确拦截**的缺陷能否作为协议缺失的论据？"——本案实测答案是不能（拦截成功恰证明协议在工作）。建议此判词后续走闸门补入协议。
- 校准建议（供闸门参考，非本次改动）：① 将"独立暴露"口径定义补入协议；② 五步第 4 步后增"落点核验"子步；③ 把"单次深证据候选的默认路由显式写为 benchmark 登记"。均按 RFC-000B §4 铁律走协议自身的修订管道。

## 六、verdict

**PASS_WITH_NITS**——协议首次真实运行可用：四条候选全部得到有证据链的三态决策，无一 BLOCKED，区分"工程 Bug / Convention / Binding / Core 不变量"的实测评测完成。NIT 项（记档，不阻断）：任务书 PRINCIPLES 路径指错、独立暴露口径未定义、落点核验缺失、Draft 文档标注义务空档——均应走协议修订闸门收口。

---

## result（评审者 JSON 原文）

```json
{
  "review_type": "core-admission",
  "decisions": [
    {"finding": "case-000#F-002", "decision": "Admitted", "target": "core/agent-contract.md §3 增补 INV-INPUT + §4 增对应 Conformance 判据；版本 +0.1", "trigger_or_reason": "五步全过：注入侧义务是规则真空，区别于既有验证者侧条款；2 次独立暴露均亲读核验；confirmatory bias 认知层现象平台无关；WHAT 可画进时序图，HOW 留 Convention", "evidence_refs": ["case-000/findings.md:19-28", "reference/joycode/bugfix-reject/cli-binding/PORTABILITY.md:20-37", "core/agent-contract.md:79-83", "PRINCIPLES.md:49-55"]},
    {"finding": "case-000#F-003", "decision": "Deferred", "target": "RFC/RFC-001-Runtime-Lifecycle.md（若未来 Admitted，落点为 §2 Running 进入条件增澄清前置守卫）", "trigger_or_reason": "独立暴露实际=1（通则确认≠独立暴露，无新可解引用观察）；fail-closed；Convention R10 已稳定承载四 case 无违反。触发：a) 再独立暴露 1 次澄清缺失致白做/返工（在线留痕）b) 已登记 benchmark 候选落地复现", "evidence_refs": ["case-000/findings.md:32-41", "RFC/RFC-001-Runtime-Lifecycle.md:49-54", "skills/acrs/acrs-shared/SKILL.md R10"]},
    {"finding": "case-000#F-004", "decision": "Deferred", "target": "agent-catalog 不可承载（自我声明非强制参考目录）；真正落点为未立项的 RFC-003 Loop Convention", "trigger_or_reason": "五步 1-4 行为层面全过（证据链四条中最佳），唯一阻断=落点承载能力；改 catalog 地位须另走 RFC。触发：RFC-003 立项开写时作为一级输入并入", "evidence_refs": ["case-000/findings.md:45-54", "reference/joycode/bugfix/findings.md:10-14", "core/agent-catalog.md:3", "core/agent-catalog.md:10-13"]},
    {"finding": "case-004#F-001", "decision": "Rejected", "target": "回落 Convention（acrs-architect design_checklist 指南 + acrs-critic 敏感域扩展）+ 登记 benchmark planted defect 候选", "trigger_or_reason": "第 1 步即挡出：工程实现缺陷非协作契约缺失（先例 case-001#F-001）；体系拦截成功=协议在工作非协议缺失证据；独立暴露=1 未达门槛；'系统边界'与 Core Boundary 同名异义违反 RFC-000A；写 agent-contract 违反其单一职责", "evidence_refs": ["validation/production/case-004/findings.md", "validation/production/case-001/findings.md:22", "core/agent-contract.md:8-10", "RFC/RFC-000-Scope.md:100-102"]}
  ],
  "calibration": {"stable_steps": ["第1步 P8 契约级判定（可操作、区分力强，case-004#F-001 由此正确挡出）", "第2步可解引用检查（8 份引用文件全部亲读可解）", "第3步平台无关（有效排除 Binding 类；对 Core vs Convention 无区分力，角色是必要条件过滤器）"], "ambiguous_steps": ["第2步未定义'独立暴露'口径（本次由评审者自造标准，复现性存疑）", "第4步不判落点承载能力（F-004 暴露：缺'落点核验'子步）", "第5步 Deferred/Rejected 边界无决策树", "§2 证据标注义务仅覆盖 Frozen Candidate 及以上，Draft 目标文档空档", "候选来源 ≥2 门槛与 §5 表按证据质量登记的张力：入场与 Review 的资格复检分工未定义"], "b1_boundary_case_handling": "协议有入场通道但五步无证据深度替代判据。实测：深证据弥补举证强度、弥补不了定性——第 1 步（P8 契约级）正确挡出，路径清晰可用。元问题实测答案：体系护栏正确拦截的缺陷不能作为协议缺失论据。建议（走闸门）：补'独立暴露'口径定义；第 4 步后增落点核验子步；单次深证据候选默认路由显式写为 benchmark 登记"},
  "verdict": "PASS_WITH_NITS"
}
```
