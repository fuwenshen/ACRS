> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 核心 MUST 约束速查

> 加载时机：**写代码 / 代码审查 / 自检**时 MUST 加载；**编排 / Phase 切换**时主 Agent 自查 CG-01 / QC-01。
> 本文件是**高频违反规则的速查索引**，完整规则见各 guardrail 文件。
> 违反任何一条 → Review 直接判定不通过。

## 为什么是这 18+2 条（选录四问）

代码级 18 条 + workflow 级 2 条（CG-01 / QC-01），从全量 guardrail 规则中选出。代码级条目必须同时满足下列**至少 2 条**：

1. **违反即不可回滚**：金额精度丢失、状态机非法跳转、事务内发 MQ 等，一旦上线即造成资金 / 数据损失，无法靠回滚补救
2. **违反即金融安全风险**：DO 含业务逻辑、`@Transactional` 大事务、裸 `BigDecimal` 运算，直接触发监管 / 审计红线
3. **高频复盘命中**：evolution `metrics.md` 中累计违反次数 ≥ 3（跨 ≥ 2 个业务项目）的规则
4. **机器难以全自动检测**：即便 Checkstyle / PMD / SpotBugs 已覆盖，仍需 Agent 在写代码时内化（如 DM-04 状态流转、INT-01 提交后发送）

**淘汰 / 新增机制**：`/fin-evolve` 消化 evolution 提案时，若某条现有 MUST 连续 2 个月违反次数降为 0（已被自动门禁完全兜底），可降级出 core；若某条非 MUST 连续 2 个月 ≥ 3 次命中，考虑升级进入 core。升级 / 降级必须伴随 evolution-log 追加。

---

| # | 规则 | 要求 | L1 自动检测 | 详见 |
|---|------|------|-----------|------|
| 1 | PS-10 | 禁止 `@Transactional`，使用 `TransactionTemplate` | 已覆盖：PMD `NoTransactionalAnnotation` | persistence.md |
| 2 | DM-09 | 所有金额字段使用 `Money` 类型 | 部分：PMD `NoDoubleForMoney`（字段名需含金额语义词） | domain-modeling.md |
| 3 | DM-04 | 状态流转通过 `transferStatusByEvent()`，禁止 `setCurrentStatus()` | 不可自动化（Reviewer 必查） | domain-modeling.md |
| 4 | DM-16 | 对象转换使用 MapStruct，禁止手动赋值 | 不可自动化 | domain-modeling.md |
| 5 | CS-05 | 校验使用 `FinAssert`，禁止 `if + throw` | 不可自动化（与 CS-16 边界互补） | code-style.md |
| 6 | INT-01 | MQ 发送放在事务提交后（事务块返回之后顺序执行），禁止事务内发送 | 待下沉（候选 ast-grep） | integration.md |
| 7 | INT-09 | 外部服务调用（RPC/HTTP）在 PREPARE 阶段（事务外） | 不可自动化 | integration.md |
| 8 | DM-11 | 禁止裸 `BigDecimal` 运算，使用 `Money` 方法 | 部分：PMD 间接（`DivideWithoutRoundingMode` + `NoDoubleForMoney`） | domain-modeling.md |
| 9 | PS-01 | DO 不含业务逻辑，仅做 DB 映射 | 待下沉（候选 ArchUnit） | persistence.md |
| 10 | ARCH-02 | 依赖方向遵循 8 模块约束 | 已覆盖：ArchUnit `LayerDependencyTest` | architecture.md + `scaffolds/java-app/module-structure.md` |
| 11 | ARCH-10 | 依赖注入使用接口类型，禁止直接注入实现类 | 不可自动化 | architecture.md |
| 12 | DM-13 | 禁止加密货币精度，仅法币（CNY/USD/EUR 2 位，JPY/KRW 0 位） | 不可自动化 | domain-modeling.md |
| 13 | CS-16 | Request DTO 必须用 JSR 380 注解；HTTP 入口 `@Valid` 自动触发、RPC 入口经 `FacadeTemplate` 程序化触发，禁止手工 if-throw 做字段格式校验 | 已覆盖（间接）：PMD `ManualNullCheckAtEntryLayer` | code-style.md |
| 14 | AP-17 | Controller/RPC Impl 禁止用 `FinAssert` 做字段格式/必传校验（仅 domain 层使用） | 已覆盖（同 CS-16）：PMD `ManualNullCheckAtEntryLayer` | anti-patterns.md |
| 15 | CS-09 | 所有 Java 类、方法、属性必须有中文注释，关键逻辑必须有中文行注释 | 待下沉（候选 ast-grep） | code-style.md |
| 16 | CS-17 | 禁止魔法值，就地定义为类内 `private static final` 常量；禁止抽象独立 Constants 类；仅强业务语义才抽枚举 | 已覆盖：Checkstyle `MagicNumber` + PMD `AvoidDuplicateLiterals` | code-style.md |
| 17 | DM-21 | 聚合根 MUST NOT 暴露任何"业务包装方法"——任何 public 方法内部含 `transferStatusByEvent(...)` 即违反。状态推进 MUST 由 DomainService 直接调 `domainModel.transferStatusByEvent(Event)` 完成，由状态机校验事件合法性 | 不可自动化（Reviewer 扫描聚合根 public 方法体；候选 ast-grep） | domain-modeling.md + anti-patterns.md AP-22 |
| 18 | INT-18 | 涉及资金 / 渠道侧副作用的外发动作（渠道支付发起等）MUST 先推进到"已提交"态并落库再外发，外发后再二次落库更新回执结果；禁止先外发后落库 | 不可自动化（Reviewer 必查外发调用点前是否有 save） | integration.md + anti-patterns.md AP-26 |
| 19 | CG-01 | 执行编排 workflow 期间，遇到核心硬门禁 CG-REQ/CG-DESIGN/CG-SIGNOFF（恒触发）或项目已开启的扩展门禁（CG-TYPE/CG-STYLE/CG-BRIEF/CG-STOP）MUST 调用 `AskUserQuestion`，等待真实用户回答，回填 `manifest.md` §用户确认链；不得"自我确认"或"沿用上次"绕过 | 不可自动化（主 Agent 自律 + Reviewer 抽检 manifest） | [confirmation-gates.md](confirmation-gates.md) |
| 20 | QC-01 | 样式工具（Checkstyle / PMD / SpotBugs / CPD）MUST 在验证 Phase 集中执行（自动修复 / 批量手修 / 全套硬门禁三步走），**禁止实现 Phase 逐 CP 调用样式工具**。实现 Phase 逐 CP 硬门禁仅有：`mvn compile` + 该 CP 涉及模块的 `mvn test`。理由：逐 CP 频繁跑样式检查会被研发关闭，集中处理既能批量修又能保留金融级门禁强度 | 不可自动化（主 Agent 自律 + Reviewer 抽检是否混入样式命令） | 各 workflow Phase + [code-quality.md §6](../../feedback/java-app/code-quality.md) |

> **CG-01 / QC-01 是 workflow 级 MUST**（不是代码级），加载场景：编排 / Phase 切换时由主 Agent 自查；其他 18 条仍为代码级 MUST。
> **CG-01 例外**：autonomous / ralph 模式下核心硬门禁（CG-REQ/CG-DESIGN/CG-SIGNOFF）仍 MUST 走；扩展门禁按项目配置，默认关闭（详见 confirmation-gates.md §自治模式例外）。
> **QC-01 例外**：refactor 工作流的存量基线扫描属于"探测存量"，不算逐 CP 调用，允许；其他场景一律禁止逐 CP 跑样式工具。

**Agent 读本表的姿势**：

- **已覆盖** = L1 已覆盖，违规会被 `mvn verify` 硬卡死。Executor / Reviewer 可以信任机器兜底
- **部分** = 机器覆盖不完全，Reviewer 仍 MUST 人工检查剩余命中路径
- **不可自动化 / 待下沉** = 必须 Reviewer 子 Agent 扫描，Executor 不能只靠自觉
- 完整覆盖矩阵见 [`AGENTS.md` §2.6](../../AGENTS.md)

---

## 使用说明

1. **Executor 子 Agent**：Prompt 中显式列出上表对应场景涉及的规则（如编写支付流程 → PS-10、DM-09、DM-04、INT-01、INT-09、CS-09、CS-16）
2. **Reviewer 子 Agent**：逐条对照本表扫描变更文件；命中即要求修复
3. **自检**：生成代码前、commit 前各跑一次本表

完整规则族（超出本速查）见 `guardrails/java-app/` 下各文件：
- `architecture.md` — ARCH-01 ~ ARCH-17（含 ARCH-16 adapter 按需组装 / ARCH-17 Gateway 接口位置）
- `reference-implementation.md` — 参考实现 source of truth（8 模块目录树、包命名、类命名全景样例 + DomainService 形态、ResultInfo / Reason 数据载体、三段式）
- `domain-modeling.md` — DM-01 ~ DM-21
- `persistence.md` — PS-01 ~ PS-16
- `api.md` — API-01 ~ API-20（API-15 已废止）+ RPC-01 ~ RPC-06
- `integration.md` — INT-01 ~ INT-18
- `code-style.md` — CS-01 ~ CS-17
- `anti-patterns.md` — AP-01 ~ AP-26
