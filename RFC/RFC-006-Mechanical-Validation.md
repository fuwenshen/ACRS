# RFC-006 · 机械校验契约（Mechanical Validation）

| | |
| --- | --- |
| **Status** | **Frozen Candidate (v0.2)**——§5 三判据已满足（case-006：26/26 测试 + 真实拦截一次 + 闭环亲测），转 Frozen 差持续 RI |
| **Version** | 0.2 |
| **Created** | 2026-09-23 |
| **Depends on** | RFC-000（分层与立法门槛）、RFC-001（生命周期与续跑）、PRINCIPLES P7（机制强制 > 纪律自律） |
| **性质** | 工具化契约：把既有 prose MUST 下沉为退出码判据（WHAT 层；实现属 `bin/acrs`，不进本篇） |
| **证据起点** | case-005#F-002 H-1（OpenSpec 研读，挂账触发器已点火）、JoyCode binding 总控 L42「未来可 Binding 工具化」预留、validation/README.md:31（P7 同源：可下沉为机制强制的优先下沉） |
| **实证** | case-006（2026-09-24，validate --json 派发：V1.4 真实拦截 Draft 资产注入 + 闭环 exit 0） |

---

## §0 摘要

把注入包（Handoff Package 派发形态）与 result 侧（checklist_coverage / 接地证据）的关键 MUST，
从「总控自觉核对」下沉为「机械校验器 + 退出码」。本 RFC 只定义**契约**（校验什么、
fail-closed 语义、退出码接地、schema 唯一权威）；实现是 `bin/acrs validate`（HOW，不进本篇）。

## §1 动机与证据

现状是结构性弱点：**一套讲「放行唯一凭据 = 客观证据」的体系，自己的注入包/DC 勾对全部是 prose，零 enforcement**。
四条独立证据链指向同一缺口：

1. **内源预留**（JoyCode binding 总控 L42）：「checklist 硬栏校验（diy-orc 下沉在 MCP 代码硬校验，
   ACRS 无 Runtime）**退化为总控职责**，靠 SKILL 决策表 + 判 DONE 前强制核对自觉执行。**未来可 Binding 工具化**」——
   仓库自己已立法预告了本 RFC 的方向；
2. **真实故障**（case-001#F-1 派发故障）：注入包只存在于会话正文，派发失败后探查无据可依——落盘是机械校验的前提；
3. **环境坑复发**（case-001#F-6）：environment 缺失导致角色重踩环境坑——必填字段是最便宜的机械化收益；
4. **外部工程范式**（case-005，OpenSpec@v1.13.1 研读）：格式契约→三态分级→fail-closed→退出码接地的完整四层范式已被验证，
   且其 #1385 教训（validate 永不接受执行路径会静默跳过的布局）直接适用。

## §2 范围

**做**：
- 注入包文件的机械校验（结构/必填/格式/一致性）；
- result 侧 coverage 闭环的机械校验（对照注入包）；
- fail-closed 语义与退出码接地契约。

**不做**（防 scope creep，全部列开放槽待触发器）：
- 运行时拦截（校验发生在派发前/判 DONE 前，由总控调用，不是自动 hook）；
- result 块自动落盘（当前仅注入包侧落盘，result 落盘见 §9 槽位 2）；
- 语义级校验（desc 是否「粒度到可写一条测试」是判断题，留评审，不机械化——机械只管「无歧义可判」的规则）。

## §3 契约条款（MUST 集）

> 逐条带证据状态：`[Derived]`（自既有 prose MUST 推导）/ `[Validated @ case-xxx]`（真实案例背书）。

### 3.1 落盘契约

- **C1** 注入包在派发前 MUST 落盘为 UTF-8 JSON 文件：`<project>/.acrs/handoff/<task_id>.json`。
  `[Derived]`（RFC-001 Handoff Package 会话内定义 + case-001#F-1 探查需求 + P6 Everything by Handoff 的文件化推论）
- **C2** `task_id` MUST 可作文件名（`^[A-Za-z0-9_.-]+$`）——禁路径穿越/空格/中文，违者校验 ERROR。
  `[Derived]`（防 C1 的落盘位置被注入歧义）

### 3.2 注入包判据（对落盘文件校验）

| # | 判据 | 级别 | 证据 |
| --- | --- | --- | --- |
| V1.1 | `task_id` / `target_agent` / `entry_type` / `grounding_mode` 非空字符串 | ERROR | `[Derived]` acrs SKILL §9 模板必填 |
| V1.2 | `environment` 整体缺失 → WARNING（可能是非首次派发）；`environment` 存在但 `prerequisites` 为空 → ERROR（带了环境段却不说前置 = 形式主义填充） | ERROR/WARNING | `[Validated @ case-001#F-6]`（教训是「该有却没有」，不是「每次都必须全新」） |
| V1.3 | `grounding_mode` ∈ {full, baseline, scoped, scaffold, trivial, waiver} | ERROR | `[Derived]` acrs SKILL §五分型表 |
| V1.4 | `injected_artifacts[].status` ∈ {APPROVED, FROZEN} | ERROR | `[Derived]` acrs SKILL §9「只注入 status∈{APPROVED,FROZEN}」prose 机械化 |
| V1.5 | `design_checklist[]`：id 匹配 `^DC-[0-9]+$` 且全局唯一；desc 非空；sensitive ∈ {true, false} | ERROR | `[Derived]` acrs-architect SKILL §二硬格式 1-3 |
| V1.6 | `constraints.sensitive_domains` 为字符串数组（可空） | ERROR | `[Derived]` acrs SKILL §9 模板 |
| V1.7 | `existing_test_files` 数组内条目为字符串（存在性 → W1.2） | ERROR | `[Derived]` acrs SKILL §9 模板 |

### 3.3 警告判据（默认放行；`--strict` 下阻断）

| # | 判据 | 理由留 WARNING |
| --- | --- | --- |
| W1.1 | DC 条目标 `sensitive:true` 但 `constraints.sensitive_domains` 为空 | 敏感域联动缺口，可能是漏标而非错 |
| W1.2 | `existing_test_files` 列出但文件不存在 | 可能是「待建」合法状态（新测试文件未写） |
| W1.3 | `design_checklist` 与 `acceptance_criteria` 同时为空 | TRIVIAL 型可能合法；STANDARD+ 应有——无法从注入包判定分型，降 WARNING |

### 3.4 result 侧闭环判据（`--result` 时对 result 文件校验）

| # | 判据 | 级别 | 证据 |
| --- | --- | --- | --- |
| V2.1 | `status` ∈ {DONE, PARTIAL, ESCALATED, BLOCKED} | ERROR | `[Derived]` R13 result 协议四处 prose 状态词的集合化 |
| V2.2 | `checklist_coverage` 覆盖注入包**全部** DC id；多余 id（引用不存在条目）= ERROR | ERROR | `[Derived]` acrs-test SKILL §四「不静默跳过」；对位 OpenSpec scenario 丢失检测 |
| V2.3 | coverage 每条有 `test_case`（用例名）或 `reason`（未覆盖原因）二选一非空 | ERROR | `[Derived]` acrs-test SKILL §四回传格式 |
| V2.4 | `sensitive:true` 的 DC 缺 coverage = ERROR（敏感条目必测） | ERROR | `[Validated @ case-004 敏感域必测纪律]` |
| V2.5 | `grounding` 含 `build_exit_code` / `test_exit_code` 至少其一，且为整数 | ERROR | `[Derived]` R12「无退出码的『完成』=违约」机械化 |
| W2.1 | `status=DONE` 但存在带 `reason` 的未覆盖非敏感条目 | WARNING | 形式合法但可疑（DONE 伴未覆盖项） |

### 3.5 fail-closed 契约

- **C3** 校验器读不到输入（文件不存在/不可读/JSON 解析失败）→ **一律 ERROR 退出**，禁止把「读不到」
  当作「没有校验对象」而放行。`[Derived]`（OpenSpec #205 教训：权限错误不许冒充「无对象」）
- **C4** 依赖缺失（如 python3 不可用）→ **ERROR 退出**，禁止静默跳过校验。`[Derived]`（同上，fail-closed 是方向不是偏好）
- **C5** 校验器自身异常（未捕获错误）→ 非零退出 + stderr 报错，禁止异常时默认通过。

### 3.6 退出码接地契约

- **C6** 退出码契约：`0` = 通过（无 ERROR；WARNING 允许）；`1` = 存在 ERROR（或 `--strict` 下存在 WARNING）；
  `2` = 用法错误（参数/文件缺失）。
- **C7** 总控判 DONE / 派发前的核对清单中，`validate exit 0` 是 G-GROUNDING / G-ACCEPTANCE 放行凭据的**组成部分**
  （不替代人工核对，是人工核对的机械化前置）。`[Derived]`（P7：能机制强制的不再依赖自律）

## §4 schema 唯一权威铁律（本仓版「共用解析器」）

- **C8** 注入包 schema 的**规范性定义只有一份**：本 RFC §3.2/3.3 判据表。`skills/acrs/acrs/SKILL.md` §9 模板、
  `bin/acrs validate` 实现、未来任何 Binding 的校验器，MUST 与本表逐字段一致；修改判据 MUST 先改本 RFC
  （Draft 期自由，Frozen 后走 RFC 流程），再同步各处。
  `[Derived]`（OpenSpec #1385：validate 永不接受执行路径会静默跳过的布局——单一事实源防两处漂移）

## §5 升 Frozen Candidate 判据（RI 实证）

本 RFC 全部条款当前为 `[Derived]`（+2 条 `[Validated]` 历史案例）。按 P8 硬门槛，升 Frozen Candidate 需：
1. `bin/acrs validate` 实现并通过正反例测试（机械 RI）；
2. **至少 1 个真实派发案例**中：注入包按 C1 落盘、validate 在派发前/判 DONE 前实际运行且其结论
   （放行/拦截）参与过总控决策——validation/production 新开 case 记录；
3. C7 接线后无「绕过 validate 仍判 DONE」的退化（binding 层核对过）。

## §6 与既有条款的关系

- 不推翻任何既有 RFC 条款；G-GROUNDING/G-ACCEPTANCE 的 prose 判据**原样保留**，本 RFC 只加机械化前置层。
- 与 RFC-002 槽位（Handoff Package WHAT）的关系：本 RFC 的 C1 落盘**不是**完整 Handoff Package 规范——
  只定义「派发形态的文件化」，完整 Handoff Package 生命周期（溢出续跑/引用结构）仍留给 RFC-002 槽位，
  触发条件不变。

## §7 P8 三问（Earn Every Abstraction）

1. **为什么不能复用已有的？** 既有手段是 prose 核对清单（acrs SKILL 判 DONE 核对）——它无法被机械执行，
   且 JoyCode binding L42 明示这是「退化」状态待工具化；不新增新概念，只把既有 MUST 换执行形态。
2. **新增了什么契约级能力？** 「退出码 = 放行凭据的组成部分」（C7）与「fail-closed」（C3-C5）——
   prose 时代两者都不存在。
3. **必须独立成 RFC？** 是——判据表（§3.2-3.4）是跨 skill / 跨 binding 的共享契约，
   放任何一个 skill 里都会造成单点漂移（违反 C8 铁律的初衷）。

## §8 开放槽位（带触发器，防吸收性膨胀）

| 槽位 | 内容 | 触发条件 |
| --- | --- | --- |
| 1 | `--strict` 与 curated 资产降档联动（curated 条目违例=WARNING、empirical=ERROR） | 首个 curated 资产实际进注入包时（case-005#F-002 H-1 尾项） |
| 2 | result 块落盘 `.acrs/handoff/<task_id>.result.json`（审计闭环另一半） | 首次需要 result 事后审计/续跑对照时 |
| 3 | `acrs validate --install`（校验安装完整性：skills 部署/roots.conf/JoyCode.md 标记块） | 首次出现安装损坏类 finding |
| 4 | Gate 证据文件存在性机检（evidence_ref 指向的落盘日志存在且可读） | 首个 evidence_ref 造假或漂移类 finding |

---

> 本 RFC 为 Draft，可自由修订；升级流程见 RFC-000B。实现（bin/acrs validate）与本篇判据表不一致时，
> 以本篇为准并修实现（C8）。
