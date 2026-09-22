# case-000 findings — 逐条过四分类闸门

> 格式：现象 → 根因 → 当时修复 → 独立暴露次数 → 归层判定（含 Core 测试）→ 终态（A·Closed 回链 / B·Promoted）。
> 回链目标 = 本次 ACRS-native Skills（skills/acrs-*）。

---

## F-001 总控「宣告 ≠ 执行」开局停顿

- **现象**：总控加载手册后只复述计划就停（宣告了下一步动作但未调用任何工具）；或用户答复澄清问题后，总控只回一句「好的，那我来派发 X」就停，未真正调用 Agent 工具。
- **根因**：LLM 在「说完计划」处有自然的回合结束倾向；单上下文 CLI 无运行时强制，宣告与执行之间无闸门。
- **当时修复**（prompt 层四处）：① 加载完手册立即继续不停；② 续跑铁律——收到答复必须在同回合推进到下一个合法暂停点；③ 回合只允许三种合法结束（Agent 派发中 / AskUserQuestion 等人 / 落终态）；④ 典型违规清单。
- **暴露次数**：1（仅 JoyCode CLI 单上下文实战）。
- **闸门判定**：Core 测试——多上下文 APP 平台有运行时强制（等返回即挂起）不犯；纯多 Agent 框架各有机制 → 非平台无关 → 不够 Core。修复手段是 prompt 注入 → **Binding**。
- **终态**：**A·Closed**（回链 acrs-orchestrator §续跑纪律，标注 Binding 层来源）。

---

## F-002 评审被总控「喂答案」污染（Critic 退化成盖章）

- **现象**：总控派 Critic 时任务书携带「已确认 / 全部落地 ✓ / 无逻辑错误」类结论；Critic 顺着追认，评审失去安全网作用。
- **根因**：注入包把「结论」当「输入」传给验证者，验证者产生锚定（confirmatory bias）；与 ACRS 可移植性实验发现的「盲验在 CLI 退化为纪律」同源——都是 INV-VERIFY（独立验证者）在弱隔离环境下的退化形态。
- **当时修复**：总控侧——任务书只写「审什么 / 依据哪份 spec@版本」，禁止携带结论，倾向只能转待核验清单；Critic 侧——任务书任何结论=待验证假设，独立重验，允许推翻，无法独立核对即 BLOCKED，不产追认式报告。
- **暴露次数**：**2**（① diy-orc 生产实战；② ACRS APP-vs-CLI 可移植性实验，独立发现同源缺陷）。
- **闸门判定**：Core 测试——任何平台的验证者（含人类审计）被喂结论都会锚定 → 平台无关；且 INV-VERIFY 本就是 Core 不变量，本条是它的操作化细则 → **Convention 固化 + Core 候选**（agent-contract §3 细则增补，走后续 RFC 流程）。
- **终态**：**B·Promoted**（≥2 次独立暴露，登记 benchmark 候选）。
- **Benchmark 候选**：同一缺陷任务书两版本（含结论 vs 只含疑问），测 Critic 抓出率差异；确定性 oracle 可设计（预埋已知缺陷，抓出=pass）。
- **回链**：acrs-shared R5 增补注入纪律；acrs-orchestrator §评审独立性；acrs-critic §〇。

---

## F-003 设计前需求没问清 = 后面全白做

- **现象**：需求存在实质分叉（数据口径 / 行为语义 / 对外契约 / 技术分叉 / 范围边界）未澄清就派 Architect → 拿假设写满一篇设计 → 整条链返工。子案例：bugfix 期望行为本身未定（未知输入该拒还是兜）就开修 → 修出症状而非根因（outstock webhook 未知 event 事件）。
- **根因**：澄清是义务而非可选，缺前置闸门时「直接开干」的路径阻力最小。
- **当时修复**：五类未定项扫描 + 分叉形状选姿态（独立→一轮摆全 / 依赖→grilling 逐个逼问 / 极低成型→brainstorming）+ STANDARD/FULL 设计前 grilling 强制前置 + bugfix 期望行为探针（A 类直修 / B 类先问）+ 用户通则拍板「前期没问清 = 后面全白做」。
- **暴露次数**：**2**（① diy-orc 生产实战多次（含 outstock webhook 踩坑）；② 用户明文通则确认）。
- **闸门判定**：Core 测试——任何编排体系（人团队同理）不问清就干都白干 → 平台无关；RFC-001 已有 DISCUSSING 态原型，缺 Intent Freeze 细则 → **Convention 固化 + Core 候选**（RFC-001 增补）。
- **终态**：**B·Promoted**。
- **Benchmark 候选**：带已知分叉的任务，测「澄清前置 vs 直接派发」的返工轮数差。
- **回链**：acrs-shared R10；acrs-orchestrator G-CLARIFY + 期望行为探针；acrs-solo §三 B 类回退。

---

## F-004 bugfix 走拆分链「修不到位」→ SOLO 连贯路

- **现象**：改行为的 bug 走 Architect→Backend 拆分，「为什么这么改」的意图在冻结-交接中损耗，出现「逻辑写了但不顺 / 烧 token 修不到位」；中途的模糊档 BUGFIX_LITE 反复出错，最终废弃。
- **根因**：正确性藏在连续推理里，冻结文档无法无损传递 → 编排密度用错了地方。与 RI-001（ACRS reference 实验：bugfix 任务过度编排不如单上下文）同源。
- **当时修复**：连贯性密度判据（正确实现能否被一份冻结文档无歧义传给盲盒执行者？能→拆分链；不能→SOLO 单上下文端到端）；bugfix 默认归 SOLO；SOLO 免的是「设计冻结交接」而非「需求澄清」；活地图骨架 + 骨架偏差自检保连贯性可评审。
- **暴露次数**：**2**（① diy-orc 生产实战；② RI-001 独立实验）。
- **闸门判定**：Core 测试——任何平台的 bugfix 编排都应保持复现→根因→改→回归的连贯（人团队同理：改 bug 的人自己从头跟到尾）→ 平台无关；「何时不编排」的编排密度判据属 agent-catalog 范畴 → **Convention 固化 + Core 候选**（agent-catalog 增补）。
- **终态**：**B·Promoted**。
- **Benchmark 候选**：同一 bugfix 任务走拆分链 vs SOLO，测修复到位率 / 返工轮数 / token 成本。
- **回链**：acrs-orchestrator 连贯性密度判据 + entry_type 表；acrs-solo/SKILL.md 全文。

---

## F-005 漏实现设计逻辑 + 假绿放行

- **现象**：Backend 漏实现某个 event 分支，Test 在其后只验「已实现的东西」→ 漏实现天然无测试覆盖 → 假绿放行。为「本体系最常见漏网缺陷」。
- **根因**：Test 后置于 Backend，验收锚点缺失——没有任何角色拿着「设计全集」逐条勾对。
- **当时修复**：design_checklist（DC-xx）单一契约贯穿四角色——Architect 拆条目随设计冻结（硬格式：当 X→做 Y→期望 Z，event/状态/错误各自独立一条，能写出 pass/fail 明确的测试）；Backend 逐条落地；Test 逐条覆盖回传 checklist_coverage（无实现→产挂红测试暴露）；Critic 逐条打开代码勾对（已实现/缺失/偏离）；任一缺失/偏离=BLOCKER。
- **暴露次数**：1（diy-orc 生产实战；业界 TDD 验收锚点思想旁证，但闸门只认本体系独立暴露）。
- **闸门判定**：平台无关（验收锚点机制与平台无关），RFC-005 Evidence/Done Gate 已有原型 → **Convention**。
- **终态**：**A·Closed**（登记观察：再独立暴露 1 次即转 B·Promoted）。
- **回链**：acrs-shared R11（Acceptance 契约）；acrs-architect §design_checklist 硬格式；acrs-backend §逐条落地；acrs-test §四·一；acrs-critic §四·一。

---

## F-006 老项目存量失败卡死接地

- **现象**：老项目全量 test_exit_code 几乎永远非 0（存量失败），死守 full 模式让任务永远无法 DONE。
- **根因**：接地判据单一化，未区分「改动引入的失败」与「存量失败」。
- **当时修复**：接地模式谱系——full / scoped（慢测试只跑子集）/ baseline（new_failures=0 为判据，不要求存量清零）/ trivial（机械改动免全量）/ scaffold / waiver；选模式的责任在总控，随注入包下发。
- **暴露次数**：1。
- **闸门判定**：平台无关（CI 同理）；RFC-005 Evidence 原语已冻结，本条是操作化 → **Convention**。
- **终态**：**A·Closed**。
- **回链**：acrs-shared R12（接地模式谱系）；acrs-orchestrator G-GROUNDING mode 选择；acrs-backend / acrs-test / acrs-solo 各自回传义务。

---

## F-007 子 Agent 产出不可解析 → 整任务重派的浪费

- **现象**：子 Agent 完成任务但 result 块缺失/格式坏，总控只能 PARTIAL 整任务重派，重复生成全部产出。
- **根因**：输出协议（结构化 result 块）无校验-重问闭环。
- **当时修复**：result 块协议（用 result 围栏包裹、必须是回复最后一段、JSON 合法）+ 总控解析失败时定向重问「只补 result 块」（不重跑任务）→ 仍失败才 PARTIAL 重派 1 次 → 再失败 ESCALATED。
- **暴露次数**：1。
- **闸门判定**：Handoff Package（RFC-000 P-9）的输出侧操作化，平台无关 → **Convention**。
- **终态**：**A·Closed**。
- **回链**：acrs-shared R13（result 输出协议）；acrs-orchestrator §返回解析。

---

## 闸门汇总表

| # | 缺陷 | 归层 | 终态 | 暴露 |
|---|------|------|------|------|
| F-001 | 宣告≠执行停顿 | Binding | A·Closed | 1 |
| F-002 | 评审喂答案污染 | Convention（Core 候选） | **B·Promoted** | 2 |
| F-003 | 需求没问清白做 | Convention（Core 候选） | **B·Promoted** | 2 |
| F-004 | bugfix 拆分链修不到位 | Convention（Core 候选） | **B·Promoted** | 2 |
| F-005 | 漏实现+假绿 | Convention | A·Closed | 1 |
| F-006 | 存量失败卡死接地 | Convention | A·Closed | 1 |
| F-007 | result 不可解析重派 | Convention | A·Closed | 1 |

**结论**：6 条 Convention（其中 3 条 Core 候选待 RFC 增补）、1 条 Binding、0 条纯 Usage。
diy-orc 的 MCP 硬校验（状态机 reject / retry 熔断 / checklist 硬栏）未过闸门收录——
它们是 Runtime 实现手段（P3：Behavior 大于 Implementation），其承载的**行为**已由上述 findings 收编；
工具化强化留给 ACRS Binding 层后续可选实现。