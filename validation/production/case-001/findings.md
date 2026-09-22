# case-001 findings —— ACRS-native Skills 首批实战使用反馈

> 来源：2026-09-21 用户在 JoyCode 实际使用 ACRS-native Skills 过程中提出（非完整 case 跑通——
> Phase 3.5 的「1 个真实 Production case 跑通」条件仍待首个完整项目任务，本文件先记实战反馈型 findings）。
> 格式沿用 case-000：现象 → 根因 → 处置 → 独立暴露次数 → 归层判定（含 Core 测试）→ 终态。

---

## F-001 工程沉淀无法跨项目按需复用（知识资产分级缺失）

- **现象**：设计/开发过程中沉淀规范、资料、优质文档；希望在其他项目按需加载复用，而非全局加载——不同项目定义不一样（同名概念口径不同），全局加载会污染。
- **延伸诉求**：① 沉淀公司 dongboot 架构资产 → 新项目直接按该架构开发；② 沉淀支付领域规范（类似 fin 系列）→ ACRS 流程内直接调用经验，而非大模型自由发挥。
- **根因**：注入包（Context 构造）只装任务上下文与项目画像，缺「本项目应加载哪些领域知识资产」的声明与优先级规则；共享知识与项目本地定义冲突时无覆盖顺序。
- **既有先例（旁证，非独立暴露）**：fin-*（java-dongboot 项目化）、channel-gateway-ops（特定仓库手册）、j-quickcard doc/knowledge、pop-settle docs/。
- **处置（2026-09-21 三轮：ACRS 仓库顶层落 `assets/` 资产目录）**：分层定形——① 跨项目工程标准住 ACRS `assets/`（随仓库分发，clone 即得 skills+assets）；② 项目差异住 `<项目>/.acrs/rules/`；③ 公司架构资产住中心仓库（FinBuddy 模式）。准入门槛 = ≥1 项目真实用过 + 跨项目可复用 + 无涉密；加载 = blueprint 登记路径 → 总控注入 / 用户直读；规范经 design_checklist 条目化才有强制力。协议见 `assets/README.md`。
- **首份资产落地**：`assets/payment/java-backend-guardrails/`——fin-buddy guardrails 九文件脱敏复制（包名/中间件名通用化映射，排除 confirmation-gates.md 防与 ACRS Gate 注册表双权威），源 commit 676aab9，映射表与对接方式见该目录 README.md。
- **快速接入机制（同日补）**：`~/.acrs/path` 指针登记 ACRS 仓库根（fin 同款模式，解决跨机器路径漂移）；blueprint 标准资产登记行（相对路径+场景+加载文件）随注入包自然流入子 Agent，不动 skill；团队入口 = 根目录 `install.sh`（写指针）+ `bin/acrs`（init/path/assets/attach，attach 幂等写入项目 blueprint 登记行）。三步接入协议见 `assets/README.md` §使用方式。
- **自我进化反哺（同日补二）**：每资产 `FEEDBACK.md`（append-only：日期|项目|类型|描述）+ `acrs feedback` 命令低摩擦记录；消化 = Rule of Three（≥2 独立项目同一问题 → 派生资产路由上游改源 / 原生资产直接改），重新脱敏复制时保留 FEEDBACK.md。分工：资产级走 FEEDBACK，流程级走本 findings。协议见 `assets/README.md` §自我进化反哺。
- **P0 接入收口（同日，Critic 自评审驱动）**：全库设计评审（`docs/review/2026-09-21-acrs-self-review.md`，CONDITIONAL-GO：1C/6M/5m）四条 P0 级发现逐条核账属实后收口——① `acrs sync` 子命令上线（部署+校验 6 Skill + 6 入口到 `~/.joycode/`，单向仓库为准；首跑即抓到并修复 acrs-shared 部署副本漂移 = M1 实锤）；② README/quick-start 双路径收口（形态 B ACRS-native 主推 = case-001 主线，形态 A 行为模拟标注已实证）；③ root-prompt REJECT 状态更正（RI-002 已实证，此前误标未实跑 = M6）；④ app/agents 旧代打遗留裁决标注 + 清除 `skills/backend-java`、`skills/code-review` 悬空引用（M5）。
- **P1 清欠 M2+M3（同日，P0 收口后续）**：① M2——总控 skill §十"JoyCode 特有"内容（MCP Ledger 退化/项目画像/续跑纪律）迁至 `bindings/joycode/agents/ACRS（总控调度）.md` §JoyCode 载体注意，skills/ 层恢复平台无关（原地留 pointer）；binding 入口"见 SKILL §十"交叉引用同步改本地。② M3——acrs-shared R2/R3/R4/R11/R12 五处"来源"标注不再指向未写的 RFC-002/005，改指真实文档（agent-contract §2.1 / app/shared/evidence.md / boundary.md / reference/joycode/bugfix-reject 实证），R2 保留"RFC-002 落地后回填"注记；RFC 内部对 RFC-002/005 的规划性引用（分工声明，ROADMAP 标不冻结）不属悬空、不改。M4（catalog 4↔6 角色映射）留待 case-001 实证后回填。`acrs sync` 二次部署复核：三处变更均落 ~/.joycode 副本。
- **暴露次数**：1。
- **闸门判定**：Core 测试——平台无关，但属 Context 构造 / 知识组织范畴，非多 Agent 协作契约缺失 → 不进 Core；skill 触发机制部分依赖平台，分类有争议默认低层 → **Binding/Convention 双候选，观察期未固化**（P8：不预设「知识资产协议」新概念）。
- **终态**：**A·Closed**（无规范改动，按现有 skill + blueprint + 派发加载指示承载；登记观察：再独立暴露 1 次（真实跨项目复用撞坑）即转 B·Promoted，届时再议知识资产协议是否进 Convention）。

---

## F-002 多 Skill 同上下文共存是否互相干扰（疑虑型，无事故）

- **现象**：使用 ACRS skill 过程中再加载其他 skill，担心先前已加载的 skill 被影响、行为被带偏。
- **根因**：同上下文多 skill 共存时平台无隔离机制；缺显式优先级与职责边界时，存在指令冲突 / 注意力稀释 / 内容重复漂移三重风险。
- **处置（本轮，纪律性回答）**：skill 注入后常驻上下文、不会自动失效，「被顶掉」不存在；真实风险是冲突与稀释。防线 = ① 薄 agent（agent.md 不复述 skill 内容，单一来源）；② acrs-shared 统一基线层（行为规范只有一份）；③ 派发表显式指定组合（acrs-shared + 角色 skill + 领域 skill），组合是声明出来的、不是随机混载；④ 职责正交——流程归 acrs-*、领域知识归领域 skill、项目定义归 blueprint，优先级 项目 > 领域 > 通用。
- **暴露次数**：1（疑虑，无实际干扰事故）。
- **闸门判定**：skill 加载/共存机制是平台特性 → 换平台表现不同 → **Binding 候选（观察期）**；其中「优先级规则」若再暴露可升 Convention。
- **终态**：**A·Closed**（回答消解 + 现有薄 agent / 单一来源纪律承载；登记观察：发生实际 skill 冲突事故再启）。

---

# 2026-09-21 首次完整流程实战复盘（用户真实事故，非推测）

> 场景：真实项目全流程跑完（设计→评审→实现→Test→REJECT→设计修订→返工→复评）。
> 跑得顺的：result 块解析零失败、返工契约一次到位、DC 逐条核对两轮真实发生、Test 只记录不越权重写、REJECT→修订→返工→复评回退链兑现价值（评审独立性在抓真缺陷上成立）。
> 以下 8 条按用户复盘编号（#1–#7 + 环境层）对应 F-003–F-010。

## F-003（#1）派发报错后盲目原样重派，双写风险【最危险】

- **现象**：Backend 首派"审批响应无法投递"，原样重派 → 第二位进工作区发现第一位已全部写完，被迫转逐文件核对。若第一位半途断掉，重派=双写冲突。
- **根因**：派发故障协议缺失——"报错 ≠ 没做工作"是实操认知，手册无此规则。
- **处置**：总控 skill §八·5 派发故障协议（重派前 MUST 探查 git status/diff/mtime 判已做多少：完整→收编 / 半成→续接 / 未动→重派，禁盲目重派）。
- **暴露次数**：1。**闸门判定**：多 Agent 协作契约、平台无关 → Convention（skill 层），暂不进 Core（待再暴露）。**终态：A·Closed**（skill 规则承载，观察 1 次）。

## F-004（#2）派发用角色语义名，not found

- **现象**：派"ACRS Critic（评审员）"报 not found，实际注册名"ACRS Critic（架构评审）"。错名系运行时 LLM 脑补（仓库文本无污染，grep 验证）。
- **根因**：派发目标名无精确匹配纪律 + 注册名清单不在总控可读处。
- **处置**：总控 skill §八·6（注册名精确匹配、禁语义名）+ Binding 总控入口"派发名注册表"6 入口清单。
- **暴露次数**：1。**闸门判定**：名字注册表是平台特性 → Binding；精确匹配纪律通用 → skill 层。**终态：A·Closed**。

## F-005（#3）AskUserQuestion 600s 超时，流水线停摆

- **现象**：G-DESIGN 方向审卡人工闸，超时后整条流水线停摆，只能即兴降级纯文本列决策项。
- **根因**：问询超时无既定降级形态。
- **处置**：总控 skill §三"人工闸超时降级"（文本问询+默认推荐+后果一行，落盘后推进可推进部分，余下标 BLOCKED_等人，禁干等）。
- **暴露次数**：1。**闸门判定**：超时降级形态通用 → skill 层（工具名留在表述外，保持平台无关）。**终态：A·Closed**。

## F-006（#4）PASS_WITH_NITS 阻断语义未定义

- **现象**：设计评审 10 NIT，凭自由裁量拦下触碰 DC 断言明确性的 NIT-1/2/3 要求冻结前修。
- **根因**：verdict 语义表只写"放行记档"，无 NIT 分流规则。
- **处置**：总控 skill §三 + critic verdict 表：触碰冻结文档断言确定性的 NIT 必修后方可进下一态，判不定算触碰（fail-closed）；纯风格类放行记档。
- **暴露次数**：1。**闸门判定**：评审裁决语义 → Convention。**终态：A·Closed**。

## F-007（#5）接地盲区：build=0 ≠ 能启动

- **现象**：@Scheduled 30s 启动即崩，mvn compile 完全不可见，Test 阶段才炸出；Backend 返工时已即兴做过最小 context 冒烟（需求自证）。
- **根因**：接地谱系缺"可启动"证据档。
- **处置**：acrs-shared R12 加 boot smoke 档（可执行应用接地证据 MUST 含最小启动冒烟）。
- **暴露次数**：1。**闸门判定**：接地证据谱系 → Convention（R12 已是）。**终态：A·Closed**。

## F-008（#6）环境自举信息不在交接包

- **现象**：MySQL 起法/.m2-repo 路径/8080 被占换 18080——Test、Backend 返工、总控回归各自重踩一遍，最后手工补进 blueprint.md 补救。
- **根因**：注入包 schema 无 environment 字段，blueprint 无强制 prerequisites 段。
- **处置**：总控 skill §九注入包加 `environment` 字段（prerequisites/boot/notes，标必填）+ Binding 总控入口 blueprint prerequisites MUST 条目。
- **暴露次数**：1。**闸门判定**：Context 构造范畴 → skill 层 + Binding（blueprint 落点）。**终态：A·Closed**。

## F-009（#7）设计评审并发结论"走查式确认"放行真实缺陷

- **现象**：设计评审独立推演"9 个并发窗口全部闭环"，但代码评审随后打出的 MAJOR-1 根因就在冻结设计 §6.3（重算口径含在途占额）——代码评审靠穷举交错抓到，设计评审靠走查放过。
- **根因**：并发结论无"反例构造"要求，"已闭环"三字即可过。
- **处置**：critic skill §三·5——并发结论 MUST 附每窗口反例交错推演，只写"已闭环"无数值或交错论证 = 至少 MAJOR。
- **暴露次数**：1。**闸门判定**：评审深度标准 → Convention。**终态：A·Closed**（下一 case 验证评审是否真实执行）。

## F-010（环境层，次要）测试环境可移植性差

- **现象**：① Docker 不可用降级项目内 mysqld，测试硬编码 127.0.0.1:3307；② 测试命令依赖 `-Dmaven.repo.local=$PWD/.m2-repo`，不写 pom 对新会话不友好。
- **处置**：随 F-008 的 blueprint prerequisites 承载（依赖服务/端口/工具链参数显式化），项目侧改进留各项目；ACRS 不新增规则。
- **暴露次数**：1。**闸门判定**：项目环境配置 → 不归体系。**终态：A·Closed**（随 F-008 机制覆盖）。

## F-011 资产来源单一：只认实战沉淀，开源/文献提炼无路径（用户提出）

- **现象**：用户问能否从主流架构设计 / GitHub 主流开源自我成长生产资产。现有准入门槛第 1 条"≥1 项目真实用过"把这条路挡死——Go 等语言域无实战项目则永远零资产（冷启动死锁）。
- **根因**：准入协议只有 empirical 单路径；无实战验证的知识与踩坑沉淀的知识无信任分级，放开即破坏"防烂根"。
- **处置（同日）**：assets/README 准入协议扩为双路径——路径二 **curated（开源/文献提炼）**：① 生产流程走体系自己（Agent 读源→提炼→**ACRS Critic 独立评审**才入库）；② 入库打 `curated` 标（信任低一档）；③ 约束力降档（DC 条目标 `DC-xx(curated)`，强参考非铁闸，项目定义优先）；④ **首验升级**（真实项目完整跑过+无 wrong 反馈 → 升 empirical 全档约束力）；⑤ 许可纪律（提炼思想不复制代码，来源必记）；⑥ 消化规则补 curated 分支（wrong 直接改本体，连续 2 项目同类 wrong → 弃用）。
- **暴露次数**：1（能力边界问答驱动，非事故）。**闸门判定**：资产协议层演进，不动 Core/skill。**终态：A·Closed**（协议落地）。
- **首份 curated 资产产出闭环（2026-09-22，用户发起"用 Go 跑通资产成长环节"）**：全流程实战验证 curated 协议——① 总控分诊 STANDARD + G-CLARIFY 两分叉 AskUserQuestion 拍板（源=go-kratos，范围=后端工程核心 12-15 条）；② 派 ACRS Solo 读源生产（WebFetch 实读 go-kratos.dev 文档 9 页 + main 分支源码，**非记忆编写**），产出 6 文件 15 MUST（ERR/CTX/CONC/LAY/DI/API/LOG 七族），骨架偏差如实回传（5 文件并 4、生成物纪律并入 LAY-01）；③ 派 ACRS Critic 独立评审（提炼者≠评审者），**15/15 源依据全量核实为真**，verdict PASS_WITH_NITS，必修项仅 MINOR-1（资产表登记，总控即补）；④ 资产表登记 curated 标 + 待首验升级注记。**F-011 解决的冷启动死锁实证解除：Go 域零资产 → 15 条带源可溯的约束**。协议本身经受住首跑：评审独立性、许可纪律（无代码复制）、源可溯三关全过。登记观察：首验升级条件 = 首个真实 Go 项目完整跑过 + 无 wrong 反馈。
