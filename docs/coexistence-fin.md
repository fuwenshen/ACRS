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

## 6. 机制借鉴台账（2026-09-22 首轮吸收，源 fin-buddy@5ecfd07）
桥梁原则延伸：**拿已验证的机制细节，不拿流程形状与角色粒度**。吸收一律过 P8 三问 + 来源标注，分三态：

**已吸收**（防的故障模式已被真实观察，落地成本≈0）：

| 机制 | 落点 |
| --- | --- |
| 归因环境须出示证据，否则按真实缺陷打回 | acrs-shared R12 |
| 绕过签名清单（skip 参数/吞错/删弱失败测试/缩范围绕红）= 假绿 | acrs-shared R12 + acrs SKILL §六 |
| 确认链落盘，无记录的自我说服"已确认"不放行；下游闸门复用记录不重问（交互预算） | acrs SKILL §三 |
| 收口复盘扫描（判 DONE 时当场捕获 findings，防回溯债） | acrs SKILL §七 核对 ⑤ |
| 诊断先于修改（兑现失败 vs 规则真空）+ 机制优先问 | `validation/README.md` |
| Harness 自身变更的回归约束（固定模型版本/前后对比/禁凑数据） | `validation/README.md` |
| FEEDBACK 消化节奏触发器（防 inbox 堆积腐烂） | `assets/README.md` |

**挂账**（带吸收触发器——不到触发条件不进规范，防吸收性膨胀）：

| 机制 | 吸收触发条件 |
| --- | --- |
| 进化提案四态目录（inbox→proposals→applied/rejected） | 已有 FEEDBACK+findings 双通道管不住时（活跃未消化条目 >20）再评估 |
| SDD 章节级 owner / frozen 版本号（冻结接口改动须升版并标"下游重跑"） | 出现"下游消费的冻结接口被上游改"类 finding ≥1 |
| 首批风格校准（1 次校准换 N 次返工） | 有 Review 首过率数据后评估（当前无此数据） |
| 确定性代码图（GENERATED/CURATED 分离，零 LLM 成本索引） | ≥2 个接入项目出现"盲改未知影响面"类 finding；属工具层，永不进规范 |

**明确不收**：
- fin 的 CG 门禁 / Phase / 派发矩阵——与 ACRS Gate 注册表双权威（§2 冲突根源），嵌套禁令（§4）；
- build-fixer / verifier 角色粒度——ACRS 四角色已覆盖，只吸收"扫描与修复分离"思想（已体现在 acrs SKILL §六抽检）。
