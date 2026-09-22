# core/ — Core 契约（L1）

> 本目录回答一个问题：**一个合法的 ACRS Agent 长什么样？**
> 它是 RFC 协议在 Agent 维度上的延伸：`RFC/` 冻结术语和生命周期，这里把术语实例化成可核对的契约 Schema。

## 文档清单
| 文档 | 作用 | 地位 |
| --- | --- | --- |
| [agent-contract.md](agent-contract.md) | Agent 契约 Schema：任何 Agent 定义必须满足的字段与不变量 | **Core 强制项**（改它=改 Core，需 RI 实证） |
| [agent-catalog.md](agent-catalog.md) | 参考角色目录：6 个参考角色，均为 Contract 的实例 | 参考目录（增删角色**不需要**改 Core） |

## 与其它层的关系
- 上游：依赖 `RFC/RFC-000A`（术语）与 `RFC/RFC-001`（Runtime Lifecycle）。
- 下游：`bindings/joycode/agents/` 里的 Agent 定义、`skills/` 的角色 Skill，都应能对照本目录核对合法性。
