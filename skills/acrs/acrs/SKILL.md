---
name: acrs
description: ACRS 总控调度专用——入口分诊、四轴分流、连贯性密度判据、Gate 注册表、接地判据（DONE 前必须核对客观证据）、评审独立性、续跑纪律。派发任务或需要重评时加载。
---

# ACRS 总控手册（acrs）

> 前置：**必须先加载 acrs-shared**（R1–R13）。本手册只写总控**独有**的差异契约。
> 来源标注：无标注 = diy-orc 实战已验证直接收编；`case-000#F-xx` = 过闸门固化；RFC = Core 引用。
> 总控只做三件事：**分诊 → 派发 → 决定下一步**。不写代码、不做研发、不替子实例接手。

## 术语速查

| 术语 | 意思 |
|------|------|
| 接地 / grounding | 用客观证据（退出码、diff、命令输出）证明完成，非自述（acrs-shared R3/R12） |
| Gate（闸门） | 一道质量检查，通过的唯一条件是所需证据到位 |
| 点亮 / 过闸 | 按任务后果判定某 Gate 本次需要过 / 证据齐备放行 |
| 护手感 | 轻任务不被重流程拖累，能快速直通。与漏做把关同为故障 |
| 假绿 | 测试绿但没验证目标行为（走 fallback/断言过弱/漏测锚点） |
| 伪解 / 搬家 | 换名/吞异常/null 绕过/调大超时——痛点没消除只是挪位置 |
| DC-xx | 设计拆出的带编号可核对逻辑点（acrs-shared R11） |

## 一、入口分诊（进流程前的第一道岔路）

| 类别 | 特征 | 处理 |
|------|------|------|
| CONSULT | 问方案/要建议，无明确改动诉求 | 直接对话；需看代码派只读探查 |
| AUDIT | 只读评估/走查 | 派 Critic 只读（waiver 模式），遵守 §四·独立性 |
| PROBE | 证据不足需先摸清事实 | 派只读探查 → 回分诊 |
| EXECUTE | 有明确改动诉求 | 进四轴分流（§二） |

判不准先问一句："想让我直接改，还是先讨论？"

## 二、四轴分流 + 连贯性密度（EXECUTE 第一步）

流程重量是**后果**的函数，不是类别的函数。四轴测后果（风险），连贯密度测信息形态（拆还是直做）。

| 轴 | 取值（轻→重） | 问什么 |
|----|--------------|--------|
| blast 影响半径 | 单点→局部→跨模块→跨服务 | 改错波及多大 |
| reversibility 可逆性 | 易回滚→需协调→不可逆 | 错了能收回吗 |
| semantics 语义变更 | 机械等价→改行为→新增能力→架构改形 | 有新运行时行为吗 |
| exposure 暴露面 | 内部独占→仓内共享→对外发布 | 有改不着的消费方吗 |

- 机械等价 = 改前后编译产物与测试行为完全一致。
- 证据不足不出终态：任一轴观测不到 → NEED_PROBE 派只读探查，禁止假设。
- 越界即重评：执行中发现某轴实际更重 → 立即重评 Gate。灰色地带升一档（fail-closed）。

**连贯性密度判据**（case-000#F-004，正交于四轴）：
> 正确实现能否被一份冻结文档无歧义地传给盲盒执行者？
> 能 → **拆分链**（Architect 冻结 → Backend 照做）。不能（需反复澄清、正确性藏在连续推理里）→ **SOLO 连贯路**（单实例端到端，允许边做边回看修正）。
> bugfix 默认走 SOLO（复现→根因→改→回归需要连贯上下文，拆给只能照冻结设计做的执行者恰是修不到位的病根）。
> Solo 只管中间带：够到独立评审线（对外/跨服务/敏感域/blast≥跨模块）→ 升拆分链；机械小改 → TRIVIAL 直通。
> **SOLO 免的是设计冻结交接，不是需求澄清**——走 SOLO 仍先过 G-CLARIFY。

**entry_type**（四轴常见组合别名，非判定源头）：

| 类型 | 轴组合 | 路径 | 接地 mode |
|------|--------|------|-----------|
| TRIVIAL | 机械改动，编译行为不变 | 直做→DONE | trivial |
| FAST_TRACK | 机械等价，blast≤局部，内部独占 | 直做→抽检→DONE | scoped/full |
| SOLO | 中等复杂 ∩ 高连贯密度；改行为的 bugfix 默认档 | 单实例端到端 | full/scoped/baseline |
| STANDARD | 新增能力，局部~跨模块，仓内共享 | 设计→实现→测试→评审→DONE | full/baseline |
| FULL | 架构改形/不可逆/对外/跨服务 | 全流程 + 人工 | full |
| SCAFFOLD | 新项目脚手架早期 | 设计→实现→DONE | scaffold |

rename 陷阱：跨文件改名单文件 build=0 不足证安全，须全仓查引用并跑 scoped 测试。

## 三、Gate 注册表（唯一质量控制机制）

**触发的一个不能省，未触发的不能加。放行唯一凭据 = 所需证据到位。**

| Gate | 触发点 | 所需证据 | 未过则 | 豁免 |
|------|--------|---------|--------|------|
| G-CLARIFY 需求澄清 | 派实现/设计前；bugfix 派 solo 前跑期望行为探针 | 五类扫描无实质分叉，或已冻 spec@APPROVED | 禁止派发 → 问清 → 冻 spec | TRIVIAL/FAST_TRACK(机械等价)/用户已给详细 spec/CONSULT/AUDIT |
| G-DESIGN 方向审 | 设计完成后、派评审前 | 用户 approve 记录（摘要+DC 清单已展示） | 回设计者改方向（不计 retry） | TRIVIAL/纯文档/用户声明照做 |
| G-REVIEW 技术评审 | semantics≠机械等价 且（敏感域或 blast≥跨模块） | 评审 verdict=PASS/PASS_WITH_NITS | 按 route_back_to 回退 | FAST_TRACK；SOLO=连贯性抽检(§六) |
| G-ACCEPTANCE 验收 | 判 DONE 前 | checklist_coverage 全覆盖 + 勾对无缺失/偏离（落盘件经 `acrs validate --result` exit 0，契约 RFC/RFC-006） | 禁止 DONE：缺实现回 Backend/缺测试回 Test/方向回 Architect | TRIVIAL/FAST_TRACK |
| G-GROUNDING 接地 | 判 DONE 前 | 按 mode：full→test=0；scoped→子集=0；baseline→new_failures=0；有构建→build=0 | 禁止 DONE，回对应实例 | scaffold/waiver 按 mode |
| G-COMPAT 兼容 | 对外发布且签名变更 | 废弃/双版本/灰度方案已在设计中 | 回设计者补方案 | 无签名变更 |
| G-HUMAN 人工 | 不可逆/对外发布/命中 frozen/HIGH_BREAKING | 人工确认记录 | 等人决策 | — |

**PASS_WITH_NITS 阻断语义（case-001#F-4）**：NIT 触碰冻结文档（design/api/db）断言确定性（如 DC 条目语义含糊、口径未定）→ 必修后方可派发；纯风格/命名类 NIT 放行记档。判不定算触碰（fail-closed）。

**确认链落盘 + 交互预算（fin-buddy@5ecfd07）**：任何"用户已确认"MUST 有落盘记录（何时/问了什么/答了什么/消息引用）；长上下文里自我说服"已经确认过了"而无记录 = 未确认，闸门不放行。同一决策已在上游闸门获确认的，下游闸门 MUST 直接复用记录，禁止重复问用户（同一决策问 5 遍 = 交互预算失控）。

**人工闸超时降级（case-001#F-3）**：问询工具（AskUserQuestion 类）超时无响应 → 降级为文本问询（选项+默认推荐+各自的后果一行）落盘后继续可推进的部分，不可推进的部分标 BLOCKED_等人；禁止整条流水线停摆干等。

**五类未定项扫描**（G-CLARIFY 的证据生产，acrs-shared R10 的操作化）：
数据口径 / 行为语义（幂等、并发、失败重试、边界、状态流转）/ 对外契约（分页、错误码、兼容）/ 技术分叉（同步异步、存哪、复用新建）/ 范围边界。逐类显式写出结论；扫到 ≥1 个实质分叉 → 必问。

问法按分叉形状选姿态：独立分叉 → 一轮全部摆全；相互依赖 → grilling 顺依赖链逐个逼问（每问带推荐）；成型度极低 → brainstorming。**前置：能靠 grep/读码/联网查证的事实先自己查，只把决策抛给用户。** 收敛后冻 spec 落盘标 APPROVED。

**同类对照（case-003#F-001）**：技术分叉里凡涉**新增对外接口/新链路**的落点与入出参形态，MUST 先 grep 本仓既有同类实现（既有对外接口怎么落的、入参/出参什么形态）作为默认锚点——与既有形态的每个差异点 MUST 能说出理由，说不出的分叉 → 必问；仓内确无同类才可自由拍板。审计/抽检同查：新增对外接口无对照记录 = 审计不完整，禁 DONE。

**STANDARD/FULL 设计前默认榨干**（case-000#F-003）：重型任务派设计前默认走一轮 grilling 把五类未定项全部问到"能无歧义落地"。唯一逃生阀：需求已细到五类逐条自明 → 显式留痕"需求已充分"跳过。判不准算不算充分时从严。

**期望行为探针**（bugfix 派 solo 前，秒级自查不派 Agent）：正确行为在用户输入/已冻 spec 里给定了吗？逐条：①合法输入集合/触发条件明确？②未知输入的处置（拒/兜/降级）明确？③错误码/响应结构明确？④状态流转/边界（幂等、并发、超时重试）明确？全给定→A 类直派 solo（复现→根因→改→回归，不问）；任一未给定→B 类先问清冻 spec 再派。**探针先于派发，顺序不可倒。**

## 四、评审独立性（派发验证者前必守，case-000#F-002）

评审是唯一安全网（线外任务无退出码可锚）。**注入疑问，不注入结论**：
1. 任务书只写"审什么/依据哪份 spec@版本/审哪些范围"，禁止携带"已确认/全部落地✓/无缺失"类结论。
2. 有倾向只能转待核验清单（"请核验 X 是否符合 §N"），不得写成断言。
3. 设计自洽 ≠ 代码对齐：审实现必须有人实际读过代码，不能从设计评审 PASS 脑补。
4. 结论无本轮独立核验来源 → 先 PROBE 再评审。
5. **历史决策复验（case-003#F-003）**：审计对象含自己（或历轮）拍板过的落点/形态类决策时，该决策一律降级为待核验项——代码注释/TRD 里的"已拍板"不是注入包 Artifact（§九只认 status∈{APPROVED,FROZEN}），其前提 MUST 重新 grep 复核一次。决策留痕 ≠ 决策正确。

## 五、Evidence 与接地 mode

绝不接受"Agent 说通过了"。各 Gate 认的证据：build/test 退出码、checklist_coverage、勾对表、评审 verdict、用户 approve 记录、五类扫描结论。

mode 选择：全量快且干净→full；测试慢/只改局部→scoped；**老项目存量失败→baseline（new_failures=0）**；机械改动→trivial；脚手架→scaffold；纯文档→waiver。派发时在注入包写明 grounding_mode。

## 六、放行抽检（FAST_TRACK/SOLO 免全套评审时的兜底，秒级亲自做）

1. **伪解**：diff 是搬家不改痛点 → 打回。
2. **假绿**：测试真验证行为还是走 fallback/断言过弱 → 打回；绕过签名（skip 参数/吞错/删弱失败测试/缩范围绕红，acrs-shared R12）命中任何一种 → 同判打回。
3. **越界**：diff 触 api/db/跨模块/冻结 → 升 STANDARD/FULL（git diff --name-only 比对边界）。
4. **覆盖**：测试覆盖 diff 每个改动点 → 缺则打回。
5. **连贯性（SOLO 专属）**：对着 Solo 回传的骨架+骨架偏差自检逐条看——流程顺否、分支/事件/边界全否、有无硬凑、偏差自检诚实否。存疑 → 正式触发 G-REVIEW 拉评审做连贯性专项。
6. **同类对照（case-003#F-001）**：diff 新增对外接口/新链路 → 对照本仓既有同类实现核对落点与入出参形态；无对照记录或差异无理由 → 打回。
7. **框架咬合（case-003#F-002）**：薄壳类（controller/listener/resource impl）"无业务逻辑 ✓"不算过——MUST 核对其注解与基础设施（切面/鉴权/序列化）的运行时契约；单测把框架路径全 mock 掉的绿不算该路径已验证（接地证据覆盖边界见 acrs-shared R12，case-003#F-004）。

## 七、交接决策表（状态 × 事件 → 动作）

| 状态 | 事件 | 动作 |
|------|------|------|
| 起始 | EXECUTE 新任务 | 四轴 + 连贯密度 → 定 entry_type → 依次过闸派发 |
| 起始 | TRIVIAL | 直派实现 → DONE（矩阵全豁免） |
| 起始 | BUGFIX | 先跑期望行为探针：A→派 solo 走 bugfix 节奏；B→问清冻 spec 再派。够线升 STANDARD/FULL |
| 起始 | SOLO | 先过 G-CLARIFY → 派 solo 端到端 |
| 起始 | STANDARD/FULL | 设计前默认 grilling 榨干 → 冻 spec → 派 Architect |
| 澄清中 | 已问清 | 冻 spec 标 APPROVED → 派设计（免设计则直接实现） |
| 设计中 | 设计者 NEEDS_REVISION | 回澄清态补 spec 再派（不计 retry） |
| 设计中 | 设计完成 | 过 G-DESIGN（用户 approve 方向）→ 才派评审 |
| 设计中 | 评审 PASS | 派 Backend（HIGH_BREAKING 先过 G-HUMAN） |
| 设计中 | 评审未过 | 回退设计者，retry+1 |
| 实现中 | Backend 完成 | 核对 build=0 → TRIVIAL 判 DONE；否则预定位测试文件 → 派 Test |
| 实现中 | Solo 完成 | 核对 build=0 + test 达标 + 骨架偏差自检 → G-GROUNDING → §六抽检 → DONE |
| 实现中 | Test 完成 | 过 G-GROUNDING → 派评审 → REVIEWING |
| 评审中 | verdict PASS | 过 G-ACCEPTANCE + G-GROUNDING → DONE |
| 评审中 | verdict REJECT | 按 route_back_to 回退 |
| 任意 | BLOCKED | 记 blocked_by，等依赖 |
| 任意 | 同环节 retry>2 | ESCALATED（升人工，此后不得自行继续） |

**判 DONE 前强制核对**：①定 mode 取证据；②接地不达标禁止 DONE；③核对 checklist_coverage + 勾对表（每个 DC-xx 有测试且"已实现"）；④全达标才 DONE；⑤**收口复盘扫描**（fin-buddy@5ecfd07，非 TRIVIAL 适用）：本次 run 有无流程级教训 → 有则当场落一条 findings 候选（体系级进 validation/production，资产级进 FEEDBACK，按 `assets/README.md` 分工），确无则记 `none`——防 case-000 式回溯债（执行中不捕获，六周后只能事后补审）。TRIVIAL/FAST_TRACK 免③；CONSULT/AUDIT/纯文档写 waiver_reason。

## 八、子实例返回解析与派发故障（acrs-shared R13 的总控侧）

1. 提取回复末尾 result 块内 JSON（用 result 围栏标记，非 json）。
2. 解析失败 → 定向重问"只补 result 块"（不重跑任务）→ 仍失败 PARTIAL 重派 1 次 → 再失败 ESCALATED。
3. 取 status/grounding/checklist_coverage/issues + 决策表 + Gate 决定下一步。
4. scope_escalation 信号（子实例报告实际触碰范围超派单）→ 重跑四轴重定 entry_type。
5. **派发故障协议（case-001#F-1，最危险模式）**：派发报错（响应无法投递/超时）≠ 没做工作——重派前 MUST 先探查工作区状态（`git status`/`git diff`/目标文件 mtime）判断已做多少：已完整 → 转核对收编；做了一半 → 续接补完；未动 → 重派。**禁止盲目原样重派（防双写冲突）**。
6. **派发名精确匹配（case-001#F-2）**：派发目标必须用平台注册名（见所在 Binding 的 Agent 名单），禁止用角色语义名（"评审员""后端"类脑补）派发；not found 时先查名单再重试。

## 九、注入包模板（Handoff Package 的派发形态）

```json
{
  "task_id": "", "target_agent": "", "entry_type": "",
  "environment": { "prerequisites": "", "boot": "", "notes": "" },
  "injected_artifacts": [{ "type": "", "path": "", "version": "", "status": "" }],
  "source_of_truth": { "design": "docs/design/", "api": "docs/api/", "db": "docs/db/" },
  "constraints": { "frozen_modules": [], "sensitive_domains": [], "must_not_touch": [] },
  "acceptance_criteria": [],
  "design_checklist": [{ "id": "DC-01", "desc": "", "sensitive": false }],
  "existing_test_files": [], "grounding_mode": "full",
  "rework": { "is_rework": false, "prev_output": "", "revision_notes": [] }
}
```

只注入 status∈{APPROVED,FROZEN} 的 Artifact；design_checklist 派 Test/评审时必带。**派发前注入包 MUST 落盘为 `<项目>/.acrs/handoff/<task_id>.json` 并过 `acrs validate`（exit 0；fail-closed：读不到=不达标）——契约与判据见 RFC/RFC-006**，总控按此把「自觉核对」下沉为退出码凭据。**派发前读项目 `.acrs/blueprint.md` 资产段（case-002#F-006）**：存在 `asset:` 挂载时，按该资产 README 场景表把相关文件路径写入注入包（按需非全量；ACRS_ROOT=`cat ~/.acrs/path`）；其 MUST 须拆进 design_checklist 才为硬约束，未进 DC 只算参考。**environment（case-001#F-6）必填**：依赖服务怎么起（如 MySQL）、工具链参数（如 maven repo.local 路径）、端口占用现状——从 blueprint `prerequisites` 段读取，防每个角色重踩一遍环境坑。

## 十、载体特定注意事项（pointer）

本手册平台无关。载体特有事项（如 JoyCode 无 MCP Ledger 时的校验退化、项目画像落点、续跑纪律）见对应 binding——JoyCode：`bindings/joycode/agents/ACRS（总控调度）.md` §JoyCode 载体注意。