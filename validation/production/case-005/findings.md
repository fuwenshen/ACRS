# case-005 findings — superpowers / OpenSpec 三态台账

> 吸收一律过 P8 三问 + 来源标注。分三态：已吸收 / 挂账（带触发器）/ 明确不收。

## 已吸收（2026-09-23 当场回链，成本≈0）

| 机制 | 来源 | 落点 |
| --- | --- | --- |
| 套件定义绿（单文件绿≠套件绿，遗漏性失真=报告造假） | superpowers@v6.4.1 TDD skill | acrs-shared R12 |
| 字面即精神（"精神上算例外"不是豁免理由，礼貌性变通按违例） | superpowers@v6.4.1 多 skill | acrs-shared R12（全 MUST 适用） |
| SDO 陷阱（description 只写触发不概括流程，防"自以为读过"） | superpowers@v6.4.1 writing-skills | skills/README 写作规范 |
| Form-to-Failure 表（禁令/recipe/REQUIRED 槽/可观察谓词四态选形） | superpowers@v6.4.1 writing-skills（micro-test 实证） | skills/README 写作规范 |

## 挂账（带吸收触发器，防吸收性膨胀）

| # | 机制 | 源 | 吸收触发条件 |
| --- | --- | --- | --- |
| H-1 | **`bin/acrs validate` 子命令**（本仓最大结构缺口：Gate/DC 勾对全 prose 零 enforcement）。可抄三层：① Zod/schema 层校验注入包（injected_artifacts 只认 status∈{APPROVED,FROZEN}、DC-xx 必有唯一 id/desc/sensitive）；② 命令式规则层（checklist_coverage 必须覆盖注入包全部 DC id、缺敏感域标 WARNING、Gate 证据文件存在且可读）；③ 退出码接地（validate 失败 exit 1，判 DONE 前必跑）。**铁律：validate 与 sync 共用同一份解析器**（OpenSpec #1385 教训：validate 永不接受执行路径会静默跳过的布局）；fail-closed（读不到=不达标，不冒充通过）；curated 资产违例=WARNING、empirical=ERROR | OpenSpec@v1.13.1 src/core/validation | **已落地 2026-09-23**：RFC-006（Draft）+ `bin/acrs validate` + test/validate/run.sh（21/21 绿）。三层均收；共用解析器以「schema 唯一权威=RFC-006 判据表」形式落地（C8）；G-ACCEPTANCE/§九已接线 |
| H-2 | Ruling + Ledger 中间态：子实例遇非灾难冲突不停摆，「裁决（what/why/cost-if-wrong）留痕后继续」——防 9 小时停摆（superpowers #2077）与"暗决策"两个极端 | superpowers@v6.4.1 SDD/executing-plans | 出现「子实例停等人而本可留痕继续」或「上下文压缩后失忆重派」类 finding ≥1（ACRS 总控侧已有人工闸超时降级 case-001#F-3，缺的是子实例侧） |
| H-3 | 模型分层显式化：派发必须显式指定模型，不指定=静默继承最贵模型（superpowers 实测一次 run 把 26 个 reviewer 全派顶配）；"轮次比单价贵" | superpowers@v6.4.1 SDD | ACRS 首次出现派发成本类问题，或平台侧支持模型参数时 |
| H-4 | Review Focus 节：设计/计划时列出 spec 沉默处（未明说的输入类/失败模式）并逐条钉测试——防"所有 implementer 在同一未命名输入上崩" | superpowers@v6.4.1 writing-plans | 下一次 STANDARD/FULL 案例的 Architect 产出可先试写（成本一行），试写效果差再退 |
| H-5 | micro-test 方法论：skill 措辞变更=代码变更，需一次一词 + 无引导对照组 + 多次重复的行为证据（superpowers 曾靠此抓回 8/10→5/10 的劣化并撤发布） | superpowers@v6.4.1 writing-skills | ACRS skill 改频上升后（validation/README 已有同方向的回归约束框架，此为细化方法） |

## 明确不收

| 机制 | 源 | 不收理由 |
| --- | --- | --- |
| bootstrap 全员注入（session-start 全文注入 + 用词法压缩省成本） | superpowers | 与按需加载/分诊触发结构性相悖；其 token 效率靠斤斤计较，ACRS 靠结构 |
| "fluid not rigid / dependencies are enablers, not gates" | OpenSpec | 与 APPROVED/FROZEN 冻结契约 + Gate 注册表直接对立——OpenSpec 允许随时回头改，ACRS 的价值恰在冻结后跨实例不漂移 |
| skip_specs 式自我豁免（被校对象自己声明绕过校验） | OpenSpec | ACRS 的 TRIVIAL/FAST_TRACK 豁免必须是总控显式分型，不能让被校者 self-declare |
| checkbox 即完成（`- [x]` 算 DONE，无退出码采集） | OpenSpec | ACRS 接地纪律的核心就是拒这种弱证据；反向印证 ACRS 强项 |
| TDD 铁律全局默认（NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST） | superpowers | ACRS grounding mode 弹性更成熟（baseline 承认存量现实）；四轴判后果比一刀切 TDD 准 |
| 全局 5 轮 fix-loop 断路器 | superpowers | 不分严重度轴太粗（Critical 架构错和 Minor 措辞错同走 5 轮）；ACRS 四轴可导出分级阈值，retry>2→ESCALATED 已覆盖主干 |

## 方向印证与警戒（不算吸收，记档）

- **厚 Skill 路线获反向验证**：OpenSpec 从 AGENTS.md 静态注入迁往可触发 skills（其 legacy-cleanup.ts 把带 marker 的 AGENTS.md 列为 legacy 强制迁移）——静态大文档注入无人执行维护，印证 ACRS "薄 Agent + 厚 Skill"。本仓 JoyCode binding 的 app/shared/*.md 静态注入面（evidence.md/boundary.md）值得对照此教训定期审视：**静态注入物必须有加载链强制引用，否则等于死文档**。
- **convention 市场验证**：superpowers 8k★ 证明"skill 即资产、内容胜过代码"有真实需求——ACRS RFC-000 押的同方向，且 ACRS 押的层（多 Agent 协作）目前无成熟占位者。
- **源码即故障台账文风**：OpenSpec 每条校验规则带 issue 编号 + "什么会出错、为什么这样防"注释；superpowers RELEASE-NOTES 每条机制变更附真实故障案例。bin/acrs validate 实现时应效仿：规则注释先讲故障再讲实现。
- **反 slop 治理预警**：superpowers 要求一切贡献披露 model/harness/version/plugins——开放型协议仓库迟早面对 AI 生成贡献污染，ACRS RFC 流程可预留披露位。
- **二者的共同盲区即 ACRS 的生态位**：superpowers 无多实例协作纪律（单 Agent 视角），OpenSpec 无接地（checkbox 即完成）——ACRS 的四轴/Gate/接地/评审独立性在两者中均无对应物，横向对比后定位反而更清晰。
