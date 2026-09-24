# case-005 — superpowers / OpenSpec 外部体系研读

> **类型**：外部 harness 研读（case-002 fin-buddy 同型）  
> **日期**：2026-09-23  
> **研读对象**：obra/superpowers **v6.4.1**（2026-09-18 tag，~8k★）、Fission-AI/OpenSpec **v1.13.1**（~4k★）  
> **研读方式**：双子 Agent 并行全文深读（skill 正文 + 源码 + 测试 + release notes），主控抽查承重论断属实后落台账  
> **证据等级**：外部观察（file:line 引用见 research-*.md，源为研读日快照）

## 背景

前轮结论：ACRS 与外部 harness 的关系是「资产互补、编排互斥」；对 fin-buddy 走过一轮三态台账（case-002）。
本轮按同工序研读两个主流体系：superpowers（单 Agent 方法论 skill 链）与 OpenSpec（spec-driven 开发工具），
回答「ACRS 演化要不要/要什么」。

## 生态位判定（先分诊，再吸收）

| | superpowers | OpenSpec | ACRS |
|---|---|---|---|
| 本质 | 单 Agent 方法论链 | spec 治理 + 机械校验 CLI | 多 Agent 协作协议 |
| 控制环 | 单上下文顺序执行 | 人审驱动 + validate 退出码 | 派发 + Gate + 接地 |
| 与 ACRS 层级 | 下一层（单人怎么走流程） | 平行（spec 怎么治理） | 上层（多 Agent 怎么协作） |

都不是竞品：**superpowers 是同方向下一层的实证（convention 可移植、内容胜过代码），OpenSpec 是 ACRS 最弱一环（机械校验）的成熟实现**。

## 闸门判据

- 同类对照（case-003#F-001 异类版）：外部机制先问「ACRS 已有什么」再问「缺什么」；
- P8 吸收判据：防的故障模式已被真实观察？不收是否降低安全性？落地成本？
- 双权威排除：对方的流程控制环（phase 链/fluid 无闸门）一律不收；
- 桥梁原则：拿已验证的机制细节，不拿流程形状与角色粒度。

## findings 摘要

| # | 结论 | 去向 |
|---|---|---|
| F-001 | 零成本吸收 2 条（套件定义绿、字面即精神 → R12；SDO 陷阱、Form-to-Failure → skills/README） | 已回链落地 2026-09-23 |
| F-002 | 挂账 5 项带触发器（validate CLI 最大缺口、Ruling/Ledger、模型分层、Review Focus、micro-test） | 见 findings.md |
| F-003 | 明确不收 6 项（bootstrap 全员注入、fluid 无闸门、skip_specs 自我豁免、checkbox 弱接地等） | 见 findings.md |
| F-004 | 方向印证与警戒（厚 Skill 路线被 OpenSpec 迁移史反向验证；AGENTS.md 静态注入已死） | 见 findings.md |

## 结论

该借鉴，但借的是**工程**（validate 三层架构、fail-closed、写作规范、分发），不是**机制路线**
（TDD 铁律、phase 链、无闸门 fluid）。superpowers 证明了 ACRS 的核心赌注（convention 层可移植、
薄 Agent 厚 Skill）有市场；OpenSpec 给出了 ACRS 从「prose 唯一凭据」走向「退出码唯一凭据」的完整可抄路径。
下一步动作：为 `bin/acrs validate` 立项 RFC（F-002 第一条）。
