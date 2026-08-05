# Runtime Sequence Diagram —— RFC-000A 的"单元测试"

| 字段 | 值 |
| --- | --- |
| **Status** | Draft |
| **Created** | 2026-07-29 |
| **作用** | 验证 RFC-000A 术语是否**足以描述整个运行时而无需引入新名词**。每根箭头都必须只用已冻结术语标注；若某根箭头画不出，说明 000A 有洞。 |
| **验收判据** | (1) 全部箭头可画；(2) 只用 000A 术语；(3) 含 Boundary 拒绝回环；(4) 不出现新名词。 |

---

## 1. 主时序图（Feature，含 Boundary 拒绝回环）

> 全程只用 000A 术语：Task / Workflow / Route / Spawn / Agent Instance / Context / Handoff Package / Evidence Index / Boundary / Done Gate / Archive。

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant O as Orchestrator<br/>(Observe→Route→Collect→Finish)
    participant L as Ledger / Workspace<br/>(Evidence Index)
    participant AI as Agent Instance<br/>(owns 1 Context)

    User->>O: Task（实现用户中心）
    Note over O: 载入 Feature Workflow (SOP)<br/>PRD→Architect→Backend→Review→Test→Done

    rect rgb(235,245,255)
    Note over O,AI: 步骤 = Route → Spawn → Handoff → Execute → Evidence → Archive
    O->>O: Route = Spawn(Architect)
    O->>AI: Spawn Architect #1 + Handoff Package<br/>{task, goal, constraints, workspace, required_output}
    activate AI
    AI->>AI: Load Skill → Loop(Observe→Plan→Act→Verify)
    AI->>L: 写 design.md（Evidence）
    AI-->>O: Handoff Package{evidence: ref(design.md)}
    deactivate AI
    Note over AI: Context Archive（关闭，不回收进 O 的 Context）
    end

    O->>L: Collect：只记 Evidence Index 引用（MUST NOT 内联内容）

    rect rgb(235,255,235)
    O->>O: Route = Spawn(Backend)
    O->>AI: Spawn Backend #1 + Handoff Package{..., evidence: ref(design.md)}
    activate AI
    AI->>AI: Load Skill → Loop
    AI->>L: 写 code / test.log / git diff（Evidence）
    AI-->>O: Handoff Package{evidence: ref(test.log, diff)}
    deactivate AI
    end

    rect rgb(255,240,240)
    O->>O: Route = Spawn(Review)  %% 独立判断 → MUST Spawn
    O->>AI: Spawn Review #1 + Handoff Package{evidence: ref(diff, test.log)}
    activate AI
    AI->>L: 解引用 Evidence Index（打开 diff/test.log 实读）
    AI->>AI: Boundary 校验 @ Done Gate
    AI-->>O: REJECT + 写 review.md（Evidence：拒绝理由）
    deactivate AI
    Note over AI: Done Gate 说 NO（存在被拒状态 → 合规）
    end

    rect rgb(235,255,235)
    Note over O: 回环：拒绝 = 新证据 → 重新 Route<br/>（原 Backend#1 已 Archive，故 Spawn 新实例）
    O->>O: Route = Spawn(Backend)   %% ← 这就是"Review→Backend"那根箭头
    O->>AI: Spawn Backend #2 + Handoff Package{evidence: ref(review.md, diff, test.log)}
    activate AI
    AI->>AI: Load Skill → Loop（按 review.md 修复）
    AI->>L: 更新 code / test.log
    AI-->>O: Handoff Package{evidence: ref(test.log)}
    deactivate AI
    end

    O->>O: Route = Spawn(Review) → Boundary PASS
    O->>O: Route = Finish
    O-->>User: Done（Evidence Index 为审计事实）
```

---

## 2. Route 决策放大图（Continue / Spawn / Finish）

```mermaid
flowchart TD
    Obs[Observe: 读 Task 状态 + Evidence Index] --> R{Route}
    R -->|正确性: 需独立判断<br/>MUST Spawn| S1[Spawn 专家 Instance<br/>= 新 Context + Handoff]
    R -->|成本: Context 近窗口上限 / 领域冲突<br/>SHOULD Spawn| S1
    R -->|默认: 无以上触发| C[Continue<br/>留当前 Context]
    R -->|Task 收敛| F[Finish]
    S1 --> Obs
    C --> Obs
```

---

## 3. 画图结论 —— 术语够不够？

**能画出来的（术语通过）：**

- ✅ 那根被反复点名的 **`Review → Backend` 回环**画得出——它在术语里是 `Boundary REJECT → review.md 成为 Evidence → O 重新 Route → Spawn Backend #2`。回环**验证了 `1 Instance = 1 Context`**：打回的不是原 Backend#1（已 Archive），而是带着 `review.md` 引用的**新实例**。无需 "Context Refresh"，无需新名词。
- ✅ Evidence 全程只走 Index 引用，Orchestrator 未内联内容——`MUST NOT accumulate history` 可视化成立。
- ✅ Handoff Package 是唯一跨 Context 通道；Review 靠"解引用 Index"读到 Backend 的产物,而非"看见 Backend 的对话"。

**画图暴露的一处待补（这正是单元测试的价值）：**

- ⚠️ **"Loop" 一词有作用域重载**：图里出现**两个**循环——Orchestrator 的 `Observe→Route→Collect→Finish`（跨 Context 的路由循环）与 worker 的 `Observe→Plan→Act→Verify`（单 Context 内推理）。000A §2.5 只定义了后者。**建议 RFC-003 明确区分 `Orchestrator Cycle` 与 `Worker Loop`,避免"Loop"被当成同一个东西。** 这不是新概念，是给已有的两处循环各自正名。

**结论**：除"Loop 作用域"一处需在 RFC-003 澄清外，RFC-000A 术语**足以描述整个运行时,未引入任何新名词**。可据此把 000A 由 Candidate 转 **Frozen**。
