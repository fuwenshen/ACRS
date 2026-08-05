# ACRS Design Principles

> 类比 Linux Philosophy：一组**在设计变更前逐条自检**的铁律。
> 每条都不是口号——它对应一个我们真踩过的坑，附**它防止什么**和**怎么检查**。
> 当讨论又飘向 Memory / Planner / Capability / Router 这类新概念时，先来过这张表。

## P1 · Core > Binding
平台无关的**契约与不变量**进 Core；任何"某平台怎么表达/怎么调用"进 Binding。
- **防止**：把 prompt / skills / 平台调用混进规范，导致同一个 Agent 在两平台变成两个东西，可移植性归零。
- **检查**：这条能画进 Runtime Sequence Diagram 的箭头吗？能→Core；"这步在 JoyCode 怎么调"→Binding。

## P2 · Convention > Prompt
行为约束写成**平台无关的 Convention**（acrs-shared），不写死在某平台的 Prompt 里。
- **防止**：每换一个平台就重写一遍规则，且各版本悄悄漂移。
- **检查**：这是"所有 Agent 都要守的行为"，还是"JoyCode Agent 的具体措辞"？后者不进 Convention。

## P3 · Behavior > Implementation
规范只约束 **WHAT**（行为 / 不变量），不约束 **HOW**（retry / hooks / tool policy / model 选择）。
- **防止**：胖 Spec 复活——我们已经删过 `Capability`，别让运行时旋钮从别的门再溜进 Core。
- **检查**：这是"行为"还是"运行时旋钮"？旋钮属 Binding，或根本不该存在。

## P4 · Thin Entry, Focused Skills（行为是激活出来的，不是内嵌的）
入口（Agent / CLAUDE.md / AGENTS.md）只留**身份 + 路由权限 + on_init 加载清单**；能力在 Skill；
**每个 Skill 单一职责——包括 acrs-shared 自己也不许胖**（见其 DESIGN §6）。
- **防止**：每个 Agent 抄一遍规范（改一处要改十处）；以及 acrs-shared 膨胀到万 token 拖垮全体。
- **检查**：这块内容属于"入口"还是"能力"？领域能力→领域 Skill，既不进入口也不进 acrs-shared。
- **为什么薄 Agent 能成立（Activation）**：Agent 只声明 **Role**；
  `Role + Convention(acrs-shared) + Domain Skill` 经 on_init **激活**后，才成为 **Executable Agent**。
  行为是**激活出来的、不是内嵌的**——`agent.md` 只有二十几行不是"功能少"，是行为在加载时由 Convention 注入。
  - **推论**：加载 acrs-shared 是 **MANDATORY**（没激活的 Agent 只是个空 Role）。
  - **同源提醒**：这正是上面"检查"的另一面——行为该进 Convention 而非写死进 `agent.md`。
    （Activation 是本条的**解释**，不单列为独立原则；给 P4 换个名字不构成新契约——见 P8。）

## P5 · One Instance, One Context
`1 实例 = 1 Context`，无 Context Refresh；接近上限靠 **Spawn 新实例 + Handoff** 续接。
- **防止**：假设记忆能续期、上下文越滚越脏还硬撑。
- **依据**：RI-BUGFIX-002 实证——REJECT 后是 Spawn 新实例，不是唤醒旧 Context。

## P6 · Everything by Handoff
跨实例状态**只**走 Handoff Package（引用，非正文）；不依赖读父对话 / 上一个 Agent 的自述。
- **防止**：隐式共享上下文；Orchestrator 把执行历史正文越攒越多。
- **检查**：这个 Agent 拿到的东西，是不是全在它的 Handoff Package + 文件系统 + Tool 里？

## P7 · Independent Verification（INV-VERIFY）
产出某 Evidence 的实例 **≠** 验收它的实例；验收者独立重取客观信号，不采信被验者自述。
- **防止**：自证自审（单 Prompt "我觉得修好了"）。
- **注意**：隔离强度按 Binding 变——App 靠进程边界**机制强制**，CLI 单上下文只能**纪律自律**（弱隔离）。

## P8 · Earn Every Abstraction（元规则）
新增任何 Agent / Skill / 概念前，MUST 逐条答：
1. 为什么不能复用已有的？
2. 它新增了什么**契约级能力**（而不只是 Prompt 措辞不同）？
3. 它是否**真的**必须成为独立的东西（而不是 Workflow 一步 / 一条 Rule / 一个已有 Skill）？
- **防止**：几十个 Agent、几百个 Skill、没人记得为什么。
- **硬门槛**：进 Core 的东西 MUST 有 RI（Reference Implementation）实证；只靠推演的不进 Core。

## P9 · Skills 是重构的产物，不是设计的产物
Skill 只在真实开发中"同一段内容重复出现"后才抽取，**不**在架构设计阶段预先设计。
- **判据（Rule of Three）**：同类内容在真实案例中出现 **≥3 次**、且抽出后入口 Prompt **明显变短**，
  才允许新增 Skill；**没有真实案例，禁止新增 Skill**。
- **防止**：凭"我觉得需要 java-backend"预设一堆 Skill，最后 Skill 爆炸、大半没人用。
- **唯一例外**：`acrs-shared` 是设计先行的（它固化 Core 不变量，是行为地基），但它同样受
  其 DESIGN §6 的尺寸预算约束——例外只此一个，不可推广。
