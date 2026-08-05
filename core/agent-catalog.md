# ACRS — Agent Catalog（参考角色目录）

> **Layer**: Core-adjacent **参考目录**，**不是** Core 强制项。
> **Status**: Reference v0.1。
> **规则**: 本目录里的每个角色都是 [Agent Contract Schema](./agent-contract.md) 的一个**实例**。
> 增删角色**不需要**改 Core；改 Schema 才需要改 Core。

## 这个文件的地位（先读这段，避免误用）

- 这里列的 Backend / Architect / Review / Test **不是"ACRS 规定必须有的四个角色"**。
- 它们是"截至目前，我们验证过或预期会用到的角色实例"。
- **某个 Workflow 用哪几个，是那条 Workflow 的选择。** 例如 BugFix Workflow
  实测（RI-BUGFIX-001）只用到 Worker + Reviewer，**没用 Architect**——这是对的，不是缺陷。
- 标记含义：`✅ RI 验证` = 已在真实运行中跑通；`◻ 目录待验证` = 契约已写、尚无实跑证据。

---

## catalog: worker  ✅ RI 验证（RI-BUGFIX-001）

```yaml
agent_type: worker
responsibilities: >
  在单个隔离 Context 内连贯完成一段"改动类"任务：Observe→Locate→RootCause→Act→Verify
  （即 Worker Loop）。根因的理解与落地在同一 Context 内一次做透，不丢给下一个 Context 重解。
boundary:
  - MUST NOT 改测试来"造绿"（不得为了退出码 0 而篡改断言）。
  - MUST NOT 做无关重构 / 扩大改动范围。
  - MUST NOT 对自己的产出做终审判定（交给独立验证者，见 INV-VERIFY）。
  - 若发现是跨模块设计缺陷而非局部 bug：MUST 停手并 escalate，不得硬改。
input:            # 消费的 Handoff Package 字段
  - repo
  - failing_cmd
  - expected
  - constraints
output:           # 进入 Waiting-Handoff 时冻结
  - root_cause          # 一句话根因
  - patch_ref           # diff 落盘引用
  - test_log_ref        # 重跑日志引用（MUST 可解、含退出码）
  - exit_code
  - files_changed
  - escalate            # null | "design"
handoff:
  to: orchestrator
  carries: [patch_ref, test_log_ref, exit_code]   # 只给引用，不给对话正文
```

## catalog: reviewer  ✅ RI 验证（RI-BUGFIX-001）

> 本角色是 §INV-VERIFY「独立验证者」的一个实例。

```yaml
agent_type: reviewer
responsibilities: >
  在一个看不到 producer 自述的独立 Context 内，对 worker 的产出做验收判定；
  独立重取客观信号（重跑测试拿自己的退出码），不以被验者自述为准。
boundary:
  - MUST NOT 读到 worker 的对话 / 自述（只接收 Evidence 引用 + 验收判据）。
  - MUST NOT 编辑 Workspace 产物（它验收，不实现）。
  - MUST NOT 以"worker 说修好了"为通过依据。
input:
  - evidence_refs      # patch_ref / test_log_ref 等引用
  - acceptance         # 验收判据（退出码==0、改动范围相称等）
output:
  - verdict            # PASS | REJECT
  - independent_exit_code   # 自己重跑得到的退出码
  - reject_reason      # REJECT 时必填
handoff:
  to: orchestrator
  carries: [verdict, independent_exit_code, reject_reason]
```

## catalog: architect  ◻ 目录待验证

> **注意**：BugFix 场景实测**不需要**它。仅当任务是"跨模块新设计、需要冻结设计契约"时才入场。
> 它的存在**不**构成"所有任务都要先过 Architect"的理由。

```yaml
agent_type: architect
responsibilities: >
  在单个 Context 内产出一份可被独立实例无歧义实现的设计契约（design_checklist：
  每条形如"当 X → 做 Y → 期望 Z"，分支独立成条）。
boundary:
  - MUST NOT 写业务实现代码（产出的是设计契约，不是补丁）。
  - MUST NOT 输出无法被盲盒实例落地的笼统条目。
input:
  - requirement
  - constraints
output:
  - design_checklist      # 可检验完备度的条目集
  - risk_notes
handoff:
  to: orchestrator
  carries: [design_checklist_ref]
```

## catalog: test  ◻ 目录待验证

> 与 reviewer 可能重叠：当"验证"本身需要新写测试用例（而非仅重跑既有测试）时，
> 才把它独立成一个角色。若只是重跑既有测试，reviewer 已覆盖。

```yaml
agent_type: test
responsibilities: >
  为产出补充/编写可执行的验证用例并运行，产出客观退出码证据。
boundary:
  - MUST NOT 修改被测业务代码来迁就测试。
  - MUST NOT 对自己新增的测试做终审判定（仍受 INV-VERIFY 约束）。
input:
  - target_refs
  - coverage_expectation
output:
  - test_files_ref
  - test_log_ref
  - exit_code
handoff:
  to: orchestrator
  carries: [test_log_ref, exit_code]
```

---

## 关于 orchestrator（为什么它不在本目录里）

Orchestrator **不是** Agent（RFC-000A / 多轮结论：它不做 Plan/Act/Verify，只做 Route）。
它不遵循 Agent Contract Schema，因此不列入本目录。它的契约见 RFC-001 §5 与各 Binding 的
Root/Coordinator 定义。

---

## 准入闸门（新增一个 Agent Type 前 MUST 逐条回答）

> 目的：控制 Agent 数量膨胀——防止演化成"几十个 Agent、几百个 Skill，没人记得为什么"。
> 三问任意一条答不上，就**不该**新增 Agent；改用 Workflow 顺序、Rule 或 Skill 表达。

1. **为什么不能复用已有 Agent Type？** —— 若只是 Prompt 措辞/技术栈不同，那是同一契约的
   **Binding 渲染**（如 backend/frontend 都渲染 `worker`），不是新 Agent Type。
2. **它新增了什么"契约级能力"（responsibilities/boundary 的实质差异），而不只是 Prompt 不同？**
   —— 契约五段式若与既有 Type 归约后等价，就不是新 Type。
3. **它是否真的必须是 Agent（=需要独立 Context 隔离），而不是 Workflow 的一步 / 一条 Rule / 一个 Skill？**
   —— 只有"需要一个隔离 Context 连贯完成某认知域"才够格当 Agent；否则降级表达。

> 判据来源：RI-BUGFIX-001（A-1，bugfix 不需要 Architect）证明"少一个 Agent"常常更优；
> 本闸门把"能不堆 Agent 就不堆"从口号变成新增前的强制自检。
