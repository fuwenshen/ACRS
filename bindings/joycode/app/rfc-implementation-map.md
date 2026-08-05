# RFC ↔ 实现映射表

> 回应"每条 RFC 都要有对应落地物，而不是写完放着"。左列是 WHAT 的权威（RFC），右列是它在
> JoyCode 上的落地物。落地物**派生**权威（只在符合 RFC 范围内才对）。

| RFC / Core | 落地物 | 状态 |
| --- | --- | --- |
| RFC-000 Scope | `RFC/RFC-000-Scope.md` + 定位声明 | ✅ Frozen 思想 |
| RFC-000A Terminology | `RFC/RFC-000A-Terminology.md` | ✅ Frozen |
| RFC-001 Runtime Lifecycle | `agents/orchestrator/prompt.md`（Cycle）+ `agents/backend/prompt.md`（Loop）| ✅ 初稿 + 已渲染 |
| Core Agent Contract | `core/agent-contract.md` + `agents/*/agent.md` | ✅ Draft |
| Core Agent Catalog | `core/agent-catalog.md` | ✅ worker/reviewer 验证 |
| RFC-002 Handoff | `shared/templates/handoff.package.json` + 各 `handoff.md` | ⚠️ 未冻（D 类缺口）|
| RFC-003 Loop | `agents/backend/prompt.md` 的 Worker Loop 段 | ✅ 已渲染，RFC 待写 |
| RFC-004 Skill / Workflow | `agents/*/skills/` + `shared/`（Workflow=Convention）| ◻ 目录已留 |
| RFC-005 Evidence & Boundary | `shared/evidence.md` + `shared/boundary.md` | ✅ 已渲染，RFC 待补 C-1/2/3 |
| RFC-006 Platform Binding | `bindings/joycode/app/capability-matrix.md` + `conventions.md` | ✅ 事实冻结 |

## 两个入口的落地物分工（App/CLI 是同一平台 JoyCode 的两个入口）
- **APP（入口=Agent，原生 Runtime）**：`bindings/joycode/app/`——真 Agent 编排（Agent Call / 递归 / Resume 由平台提供）。
- **CLI（入口=Skill / Root Prompt，行为模拟）**：`bindings/joycode/cli/root-prompt.md`——单 Context 装出多 Agent 行为。
- **共享 Skill**：`bindings/joycode/skills/acrs-shared/`——两个入口都必加载的行为规范层。
- **Reference Project（真跑证据）**：`reference/joycode/bugfix/`（RI-001）+ `bugfix-reject/`（RI-002 + 可移植性实验）。
