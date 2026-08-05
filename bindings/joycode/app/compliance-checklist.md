# Compliance Checklist — APP Binding 合规自检

> 一个自称遵循 ACRS 的 JoyCode APP 实现，MUST 逐条通过。判据尽量客观可核。

## Core 契约
- [ ] 每个 `agents/<x>/agent.md` 的 `implements:` 指向 core/agent-catalog 中已定义 agent_type（orchestrator 除外）。
- [ ] 每个 `prompt.md` 是其契约的忠实渲染，未加契约外职责、未放宽 boundary。
- [ ] 不存在 prompt/skills 出现在 `core/` 层。

## 不变量
- [ ] INV-VERIFY：存在 (producer, verifier) 对，且为**不同实例/不同 Context**；无"自产自审"路径。
- [ ] 1 实例 = 1 Context：无 Context Refresh；溢出只走 Spawn+Handoff。
- [ ] P-9：跨实例状态只走 Handoff Package，无依赖对话继承。

## Route / 拓扑
- [ ] 显式路由：Spawn 均显式指定 agent_type（无平台自动选）。
- [ ] CONV-TREE：每个 Agent 只 Collect 其直接子节点；无全知总控。

## Boundary / Evidence
- [ ] Orchestrator 未把证据正文内联进自身 Context（只登记引用）。
- [ ] Done Gate 三判据齐备；存在"能被拒绝"的证据态（Boundary 会 REJECT）。
- [ ] Evidence 均来自客观来源（diff/test log/build/MCP），载体标注为 Binding。

## 平台风险
- [ ] SubAgent 超时有兜底（提示用户 / 重 Spawn），父 Agent 不无限静默等待。
