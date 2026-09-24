# case-007 — DDD 精髓资产化 + 首个真实 attach 落地

> **类型**：资产建设 run 归档 + 机制实证（attach 链首环）
> **日期**：2026-09-24
> **任务**：学习团队 DDD 规范（JoySpace《DDD模板工程-Trade 设计方案》+ trade-demo/fin-buddy reference-impl），产出学习总结/应用指南/标准资产三件，并完成 ACRS 首个真实 `acrs attach`。

## 产出

| 交付物 | 位置 |
|---|---|
| 团队分享学习总结（精髓+骨架代码引用） | 本地非资产文档，不随仓分发（落位约定见本地 notes/README.md） |
| 应用指南（新项目严格遵循/旧项目渐进借鉴/跨语言思想） | 同上 |
| DDD 精髓标准资产（DDD-01~15 原则层条款） | `assets/ddd/ddd-essence/{README,core-must}.md` |
| 首个真实 attach（myACRS-pj） | `myACRS-pj/.acrs/blueprint.md` 知识资产段（`asset: ddd/ddd-essence`） |

## 机制实证：attach 链首环闭合

case-002#F-006 留下的「待首个真实项目挂载」缺口，本次闭合首环：`acrs attach ddd/ddd-essence /Users/fuwenshen.168/ai_workspace/myACRS-pj` 幂等写入 blueprint 资产段成功（grep 验证单条，无重复）。**全链（attach→注入包→Architect 拆 DC→Critic 勾对）待 myACRS-pj 下一次真实派发时实证**，届时在本 case 追加 DC 勾对记录。

## Findings

- **F-1（候选，体系级）：`bin/acrs attach` 写入失败仍 exit 0 并打印成功文案（fail-open）**。实证：沙箱拒写（Operation not permitted）时，blueprint 未变更，但 stdout 输出「[acrs] 已接入资产 …」且 exit code=0。这违背 ACRS 自身的接地判据（acrs-shared R12——「注释声称门禁有效 ≠ 门禁有效」，工具同理：声称成功 ≠ 写入成功）。修法建议：`cmd_attach` 对写重定向显式检查（`>> "$bp" || { echo 失败; exit 1; }`），并把成功文案的 echo 依赖写入成功后再打印；顺手排查 `bin/acrs` 其他子命令有无同类 fail-open。
