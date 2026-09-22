# java-backend-guardrails —— Java 后端工程化标准（支付语境）

> **ACRS 标准资产 · 第一份**（case-001 F-001 落地，2026-09-21）。
> 源：fin-buddy `guardrails/java-dongboot` @ commit 676aab9，**脱敏复制全量**（代码级 9 文件）。

## 定位

从人读工程规范中提炼的**命令式可执行约束**（MUST / MUST NOT），供 AI Agent 写码时遵守，供 Review 时逐条勾对。技术语境为支付/交易后端（四聚合状态机、Money 金额、渠道外发时序）。

## 脱敏映射表（源名 → 资产名）

| 源（内部） | 本资产 | 说明 |
|---|---|---|
| `com.jd.*` | `com.company.*` | 组织包名，落地时替换为实际组织包名 |
| JMQ | MQ | 消息队列 |
| JSF | RPC | 内部 RPC 框架 |
| JIMDB / JimClient | Redis / RedisClient | 分布式缓存 |
| DUCC / @DuccConfig | ConfigCenter / @AppConfig | 配置中心 |
| DongSchedule / @DongJob | ScheduleCenter / @ScheduledJob | 定时任务 |
| DongGuardian / @GuardianResource | RateLimiter / @RateLimitResource | 限流 |
| DongDAL | MyBatis-Plus | 数据访问 |
| DongBoot / DongHTTP / dong-log | AppBoot / HttpClient / app-log | 框架封装 |
| DongRegistry | Registry | 注册中心 |

> 公司内使用时按上表反向还原即得真实技术栈语义。

## 裁剪说明（相对源）

- **排除** `confirmation-gates.md`：fin 编排体系专属（CG-REQ/CG-SIGNOFF 等），与 ACRS Gate 注册表双权威冲突——ACRS 下用户确认走 ACRS 自己的闸门。
- `core-must-rules.md` 第 19/20 条（CG-01/QC-01）为源编排体系 workflow 级规则，仅作参考，ACRS 下对应 ACRS Gate 注册表与接地判据。
- 源仓库的 scaffolds / feedback / AGENTS.md / conventions 附件未随资产分发，文内相对链接指向源仓库。

## 文件清单与场景加载

| 文件 | 加载场景 |
|---|---|
| core-must-rules.md | **每次写代码 / Review / 自检必加载**（18 条代码级 MUST 速查） |
| architecture.md | 新建模块、调包结构（ARCH-01~17，8 模块结构、依赖方向） |
| reference-implementation.md | 新建工程 / DomainService 形态对照（全景样例） |
| domain-modeling.md | 聚合根、状态机、值对象（DM-01~21） |
| persistence.md | PO / Repository / 事务（PS-01~16） |
| api.md | Facade / Controller / DTO / 返回码（API + RPC 规则） |
| integration.md | MQ / Scheduler / 外部调用 / 缓存 / 限流（INT-01~18） |
| code-style.md | 任何代码（CS-01~17） |
| anti-patterns.md | Review / 自检（AP-01~26 禁止模式，子 Agent 完码后必加载） |

## 与 ACRS 对接（约束力入口）

1. **声明**：项目 `.acrs/blueprint.md` 登记 `asset: <ACRS>/assets/payment/java-backend-guardrails/`，标注适用任务类型（新模块 / 领域建模 / 持久化 / 集成 / Review）。
2. **注入**：总控派发时按 blueprint 把对应文件路径写入注入包，子 Agent 按场景加载（非全量）。
3. **条目化**：Architect 设计时把本资产相关 MUST 拆进 design_checklist（DC-xx）→ Backend 逐条落地 → Test 逐条覆盖 → Critic 逐条勾对。**未进 DC 的规则只算参考，进 DC 的才是硬约束。**

## 演进

- 源仓库升级 → 重新脱敏复制并更新本 README 的 commit 记录（资产不直接改，改源）。
- 若某条规则在本资产与项目 `.acrs/rules/` 冲突：项目优先。
