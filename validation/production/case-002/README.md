# case-002 — fin-buddy 机制首轮吸收归档

> **证据等级：外部观察（External Observation）**。非 ACRS 生产事故：借鉴机制来自 fin-buddy
> （java-dongboot 部门级 harness 仓库）@5ecfd07 的 evolution/ workflow/ guardrails/ 实地研读，
> 其防的故障模式在该体系真实存在（含其进化 inbox 堆积 11 条、applied 为 0 的失败观察）。
> 源仓库不随 ACRS 分发，本规则集自包含可执行；本机克隆位置属维护者本地指针（memory / `~/.acrs/`），不入库。
> 吸收一律过 P8 三问 + 来源标注。

## 背景

- **发起**：2026-09-22 用户要求"作为总设计师评估 fin-buddy，直接借鉴 + 自身优化演进，不违背 ACRS 宗旨"
- **方法**：PROBE 只读探查（README/AGENTS/orchestrate/gates/tools/进化/基准/复盘/runs 实录）
  → 按 PRINCIPLES P8（最小增量）评估 → 决策：**不新建平行进化系统**（已有 FEEDBACK+findings 双通道），只补操作细节
- **吸收分三态**：已吸收（防的故障可观察 + 落地成本≈0）/ 挂账（带触发器，不到条件不进规范，防吸收性膨胀）/ 明确不收（与 ACRS 不变量冲突）

## 闸门判据

- **Core 测试**：吸收的条款必须平台无关（fin-buddy 内容层如 java-dongboot 规约一律不收）
- **双权威否决**：任何与 ACRS Gate 注册表 / 角色粒度平行的机制不收（`docs/coexistence-fin.md` §1-5 铁律）
- **防膨胀**：吸收前过"现有规则已覆盖？可下沉为机制？新增后核心清单仍克制？"三问

## findings 清单

见 `findings.md`。4 条：F-001（7 项吸收回链）/ F-002（4 项挂账带触发器）/ F-003（2 类不收）/ F-004（借鉴源自身的失败观察收编为警戒）。
