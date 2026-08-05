# Bootstrap Contract —— 一个开发任务如何启动 ACRS

> 只回答一个问题：**任务开始的那一刻，到底发生了什么？**
> 这不是新的一层（不与 Core/Convention/Binding 并列），而是一条**横切契约**——
> 它把"已有三层的加载时序"串成一条**每个平台都一样**的启动链。

## 北极星：对业务开发透明
ACRS 想达到的终态是——**开发者几乎感觉不到它存在，却始终按它的规则工作**。
就像 ESLint / Google Style / Spring：没人天天读规范，但规范进了流程。

- Backend 干活时**不知道**"我是 ACRS"，它只是**一直守着 acrs-shared**。
- Context 爆了、Spawn 了、Handoff 了——这些对**业务开发透明**：新实例读完 handoff 继续干，甚至不知道"刚才上下文没了"。

> ⚠️ **验证期例外**：透明是**成熟产品**的终点，不是**验证期**的目标。
> 现在我们**需要它可观测**（才能收集 findings）；先把"启动发生了什么"讲清楚，别急着把它藏起来。

## 通用公式（任何平台都一样）
```
Platform → Entry → ACRS(Convention → Domain) → Business Task
                    └── 变的只有 Entry；这条链的其余部分永不变 ──┘
```
启动链的骨架（`bootstrap`，属"启动段"）：
```
Task 到达
   ↓
① Entry        平台入口载体接住任务（Agent / root-prompt / CLAUDE.md / AGENTS.md）
   ↓
② Convention   加载 acrs-shared（MANDATORY，非可选）——行为地基
   ↓
③ Domain       按需加载领域 Skill（如 backend-java）——目前刻意还没建（P9）
   ↓
④ Start        开始业务任务
```
> ④ 之后进入 **Mental Model 运行环**（Produce→Evidence→Verify→Spawn/Handoff→Done，见 [mental-model.md](mental-model.md)）。
> Bootstrap 只管**怎么起**，运行环管**怎么跑**——两者别混。

## 启动这一步到底做了什么：Activation（行为激活）
Bootstrap 描述**步骤**；Activation 命名这些步骤**达成了什么**——把一个空壳 Role 变成有完整行为的 Agent。
```
   Role            +    Convention        +    Domain            ══▶   Executable Agent
   （身份，agent.md）    （acrs-shared，行为）     （领域 Skill，能力）        （激活后才有完整行为）

   Backend         +    acrs-shared       +    backend-java      ══▶   Executable Backend
   Reviewer        +    acrs-shared       +    code-review       ══▶   Executable Reviewer
```
- **真正决定行为的是 Convention，不是 Role。** Role 只声明"我是谁"；`Evidence / Boundary / Review / Spawn / Done Gate` 这些行为，全在加载 acrs-shared 之后才出现。
- **这解释了"为什么 agent.md 只有二十几行"**：薄不是"功能少"，是**行为在加载时注入、Agent 激活后才完整**。
- **推论**：加载 acrs-shared 是 **MANDATORY**——没激活的 Agent 只是个空 Role。
- Backend 干活时并不知道"我是 ACRS"，它只是一直守着已激活的 acrs-shared——这就是"对业务透明"的机制来源。

> 📌 Activation 是 **P4** 的解释性延伸（`Role+Convention+Domain=Executable Agent`），
> **不单列为独立原则**——给 P4 换个说法不构成新契约（P8）。此处只做文档命名。

## 各平台的启动链（入口不同，② 之后全一致）

### 🟢 JoyCode CLI（已实测）
```
root-prompt.md（已内联 acrs-shared）
   ↓  →（按需）领域 Skill
   ↓
开始任务
```

### 🟡 JoyCode APP（设计意图，`on_init` 已在 agent bundle 中定义，未在 App 实测编排时序）
```
Backend Agent
   ↓  on_init:  ← 真实存在于 backend/agent.md
        - skills/acrs-shared     （MANDATORY）
        - skills/backend-java    （按需，尚未建）
   ↓
开始任务
```

### ⬜ Claude Code（binding 未建）
```
CLAUDE.md → load acrs-shared → 开始任务
```

### ⬜ Codex（binding 未建）
```
AGENTS.md → load acrs-shared → 开始任务
```

> 结论：**平台只是入口，ACRS 才是真正开始工作的地方。** ② Convention 这一步是所有平台的公约数。

## 跨 Context 续接（透明性的关键场景）
Context 接近上限时，不刷新、不硬撑，而是重新走一遍启动链 + 读 handoff：
```
Backend#1 ──接近上限──▶ Handoff Package（引用，非正文）
                              │
Backend#2  ①Entry → ②acrs-shared → ③Domain → 读 Handoff → 继续开发
```
Backend#2 **不知道**"上一个 Context 爆了"——它只是又一次干净启动、读交接、接着干。
这就是 **P5（1 实例 1 Context）+ P6（Everything by Handoff）** 在启动契约里的体现。

## 它落在架构的哪里（为什么不是第五层）
| 启动步骤 | 归属的已有层 |
| --- | --- |
| ① Entry 机制（on_init / CLAUDE.md）| **Binding** |
| ② "必须加载 acrs-shared" 的规则 | **Convention / Core** |
| 读 Handoff 续接 | **Core**（Handoff 不变量）|

> Bootstrap **横跨三层**、不新增内容——按 **P8** 它是一条**被文档化的契约**，
> 不是与 Core/Convention/Binding 并列的第四个内容桶。
