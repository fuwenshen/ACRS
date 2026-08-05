# ACRS Mental Model —— 一个动词环

> 结构（Agent/Skill/Binding/Core）回答"由什么组成"；**心智模型回答"它怎么跑"**。
> 记不住结构没关系，记住这个环就懂了 ACRS。

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │ REJECT
   Task ──▶ Context ──▶ Produce ──▶ Evidence ──▶ Verify ──▶ Decision
   任务      隔离边界     干活        留证据       独立验     判决  │
                                                              │ ACCEPT
                                                              ▼
                                                          Handoff ──▶ Done
                                                          交接状态     完成/进下一环
```

**一句话**：任务进到一个**隔离的 Context** 里干活，产物必须落成**可核对的 Evidence**，
交给**独立的 Verify** 判决——**通过就 Handoff 转移状态、不通过就丢弃重来（Spawn 新 Context）**。

## 每个动词 = 一条 Core 不变量（不是随口编的）
| 动词 | 含义 | 对应 Core 不变量 |
| --- | --- | --- |
| **Context** | 每段工作在隔离边界内，互不串味 | Boundary |
| **Produce** | 在边界内产出改动 | —— |
| **Evidence** | 产物必须留可核对证据（退出码/diff/日志），不认"我觉得好了" | **INV-VERIFY** |
| **Verify** | 由**独立**方核对证据，不是自证 | Evidence / 评审独立性 |
| **Decision** | 判决只认证据；REJECT 不修补，**丢弃重来** | Loop |
| **Spawn** | REJECT 后起**全新 Context** 重做，不在污染上下文里打补丁 | Spawn |
| **Handoff** | ACCEPT 后状态**只经交接包**转移，跨实例不共享内存 | Handoff / Context |

## 为什么是"丢弃重来"而不是"改一改"
这是 ACRS 和普通"AI 写完你 review"最大的区别：
Verify REJECT 后，**不在同一个被污染的上下文里让它自己改**（那会一路合理化错误），
而是带着 Findings **Spawn 一个干净 Context 重做**。
—— 环上那条从 Decision 绕回 Context 的回边，就是质量的来源。

## 这个环和 Entry Adapter 的关系
- **本环（怎么跑）**：平台无关，任何 binding 上都是这个环。
- **Entry Adapter（凭什么跨平台）**：换平台只换"入口怎么把任务喂进这个环"，环本身一行不改。

> 两张图配合看：Mental Model 说 ACRS **做什么**，Entry Adapter 说它**凭什么到处能做**。
