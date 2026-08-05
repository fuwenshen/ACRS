# Agent Binding 模板（_template）

> 复制本目录新增一个 APP Agent。**它是 Core 契约的渲染，不是 Agent 的新定义。**
> 每个 Agent 文件夹 = 某个 [core/agent-catalog](../../../../../core/agent-catalog.md) 契约在 JoyCode APP 上的 bundle。

## 目录约定

```
<agent-name>/
├── agent.md      # 指针：本 bundle 渲染的是哪个 Core 契约（agent_type）+ 稳定元信息
├── prompt.md     # Binding：喂给 JoyCode APP Agent 的系统提示（平台相关）
├── workflow.md   # Binding：该 Agent 参与的 SOP 片段（承 RFC-004 Workflow=Convention）
├── handoff.md    # Binding：本 Agent 的 in/out Handoff Package 具体形状（承 RFC-002 WHAT）
├── rules.md      # Binding：boundary 的展开（MUST NOT 清单的可执行版）
└── skills/       # Binding：按需加载的知识包（Java/Spring/... ），用户不直接使用
```

## 铁律（每个 Agent bundle MUST 遵守）

1. `agent.md` 的 `implements:` **MUST** 指向 core/agent-catalog 中一个已定义的 agent_type。
   bundle 不得凭空发明契约——契约在 Core，这里只渲染。
2. `prompt.md` / `skills/` **MUST NOT** 出现在 Core 层。它们是平台产物。
3. 五段式（Responsibilities/Boundary/Input/Output/Handoff）以 `agent.md` 里的契约为准；
   `prompt.md` 只能是它的**忠实渲染**，不得偷偷加职责或放宽 boundary。
