# ddd-essence —— DDD 精髓标准资产（跨语言/跨项目形态）

> **ACRS 标准资产**。源：团队规范《DDD模板工程-Trade 系统模块、包、类名设计方案》（JoySpace）+ fin-buddy `reference-impl`/trade-demo 基准工程提炼，2026-09-24 收编。
> 性质：empirical 提炼（源为部门级实战模板工程）。

## 定位

从团队 DDD 模板工程提炼的**载体无关原则层约束**（DDD-01~15，命令式 MUST），覆盖：依赖方向、端口位置、契约纯度、入口纪律、编排与规则分离、状态唯一推进、类型即契约、资损防御、事务边界、并发防御、持久化隔离、规则资产化。**适用于任何语言、任何项目形态**——旧项目借鉴、非 Java 项目移植、新 Java 项目与 guardrails 配套使用。

## 与 java-backend-guardrails 的分工

| 资产 | 语境 | 用法 |
|---|---|---|
| **本资产（ddd-essence）** | 原则层，跨语言跨形态 | 恒载心智模型 + 任何项目可挂 |
| assets/payment/java-backend-guardrails | Java 全量条款（ARCH/DM/PS/AP/INT/CS/API 六族） | **Java 新项目与本资产同挂**，guardrails 给代码级硬规约，本资产给判断力 |

冲突时项目 `.acrs/rules/` > guardrails（Java 语境）> 本资产（原则层）。

## 文件清单与场景加载

| 文件 | 加载场景 |
|---|---|
| core-must.md | **任何写码/设计/评审任务恒载**（DDD-01~15 原则层 MUST） |

## 约束力入口（同 guardrails 三步）

1. **声明**：`acrs attach ddd/ddd-essence` 写入项目 blueprint 资产段。
2. **注入**：总控派发时把 core-must.md 路径写入注入包（恒载，非按需）。
3. **条目化**：Architect 把相关 DDD-xx 拆进 design_checklist 并标来源（`DC-xx←DDD-07`）→ Backend 落地 → Test 覆盖 → Critic 勾对。**未进 DC 只算参考。**

## 演进

源规范升级（JoySpace 文档/trade-demo）→ 本资产同步重提炼；FEEDBACK 双通道反哺照 `assets/README.md` 通用约定。
