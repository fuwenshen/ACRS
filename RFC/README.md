# RFC/ — ACRS 协议层（L1 Core）

> 本目录回答一个问题：**ACRS 的规则本身是什么？**
> 这里是全仓库的权威源头——`core/`、`skills/`、`bindings/` 的任何行为规范都能回链到这里的某份 RFC。
> 改动需走 RI 实证（见 `PRINCIPLES.md`），不允许"发现问题就直接改"。

## 文档清单
| 文档 | 主题 | 状态 |
| --- | --- | --- |
| [RFC-000-Scope.md](RFC-000-Scope.md) | 范围与边界：ACRS 管什么、不管什么 | Draft — Frozen Candidate |
| [RFC-000-architecture-manifesto.md](RFC-000-architecture-manifesto.md) | 架构宣言：四层模型与"Entry Adapter"主张（历史邀评稿） | Draft (RFC) |
| [RFC-000A-Terminology.md](RFC-000A-Terminology.md) | 术语冻结：Context/Handoff/Evidence/Boundary 等动词的唯一定义 | **Frozen (v1.0)** |
| [RFC-001-Runtime-Lifecycle.md](RFC-001-Runtime-Lifecycle.md) | 运行时生命周期：任务从进 Context 到 Handoff 的状态机 | Draft — Frozen Candidate |
| [runtime-sequence.md](runtime-sequence.md) | 运行时序图：RFC-000A 术语的"单元测试"（箭头画不出=术语有洞） | Draft |

## 阅读顺序建议
1. `RFC-000-Scope.md` → 搞清边界
2. `RFC-000A-Terminology.md` → 术语是后续一切的地基（唯一已冻结）
3. `RFC-001-Runtime-Lifecycle.md` → 动词环如何落地成生命周期
4. `runtime-sequence.md` → 用一张图验收术语完备性
