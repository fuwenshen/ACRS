# ACRS 与 fin 共存规则

> 一页纸口径（2026-09-21 拍板）。回答：两套体系能否同时装、单任务怎么选、边界在哪。

## 结论
**能同时安装，单任务必须单主线。**

## 1. 安装层：无冲突
- 两套 skill 并排注册、按需触发；指针互不干扰（`~/.acrs/path` vs `~/.finbuddy/path`）。

## 2. 单任务层：冲突在编排权
fin 与 ACRS 都是完整编排体系（fin 有 CG 门禁 + 自有 pipeline；ACRS 有 Gate 注册表 + 四轴分流）。
同一任务双主线 = 双权威（两套确认、两套派发），必然乱。这也是 guardrails 脱敏时排除
confirmation-gates.md 的原因（防与 ACRS Gate 注册表双权威）。

## 3. 分工矩阵

| 场景 | 主线 |
| --- | --- |
| java-dongboot 项目建新模块 / 全周期建设 | `/fin` |
| 通用任务（架构评审、bugfix、多 Agent 协作） | ACRS |
| ACRS 派发 java-dongboot 类项目 | ACRS 外层 + guardrails 资产注入（DC 条目化），不进 fin pipeline |

## 4. 嵌套禁令
ACRS 子 Agent 执行时不得再调 `/fin`（反之亦然）——防递归双主线。

## 5. 桥梁设计
ACRS 拿 fin-buddy 的**规则**（`assets/payment/java-backend-guardrails/`），不拿 fin 的**流程**。
资产升级回路：FEEDBACK → Rule of Three → 路由 fin-buddy 上游改源 → 重新脱敏复制（见 `assets/README.md` §自我进化反哺）。
