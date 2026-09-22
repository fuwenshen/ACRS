# ACRS 体系自我评审（design review）

| 字段 | 值 |
| --- | --- |
| 评审对象 | 整个 ACRS 仓库（Core / RFC / skills / bindings / assets / bin / docs / validation） |
| 评审者 | ACRS Critic（独立重验，非追认） |
| 日期 | 2026-09-21 |
| 方法 | 逐文件实读（非目录名推断）；结论独立产出 |

---

## verdict + 一句话理由

**CONDITIONAL-GO**（对应 PASS_WITH_NITS 升档）——架构分层与验证纪律的设计质量高、诚实度好（全仓大量「未实测」显式声明），但新旧两代 Binding 的过渡没有收口：**官方主推的安装路径（README → bin/acrs-install.sh）装出来的是不含 ACRS-native Skills 的旧代运行时**，与 ROADMAP 当前阶段「case-001 用 ACRS-native Skills 做真实验证」的主线直接脱节，且部署副本漂移已经实际发生。修复 C1 前不应开跑 case-001。

---

## 发现清单（按严重级排序）

> 标注【事实】= 与仓库内容不符的可核对问题；【观点】= 设计取舍异议。

### C1【事实·Critical】官方安装路径与验证主线装的不是同一套体系
- **位置**：`README.md:70`、`bin/acrs-install.sh:100-108`、`ROADMAP.md:50`、`bindings/joycode/install/README.md:26-30`
- **证据**：README 首推「装进你的项目 → bin/acrs-install.sh --platform joycode-cli」；但该脚本只安装 `skills/acrs-shared` + docs + `cli/root-prompt.md`（acrs-install.sh:100-108），**不装** 6 个角色 skill（acrs / acrs-architect / acrs-backend / acrs-test / acrs-critic / acrs-solo）与 6 个薄入口（bindings/joycode/agents/ACRS *）。而 ROADMAP 当前阶段的全部价值押在「用 ACRS-native Skills 做真实任务，产出 findings（case-001 起）」。新体系的唯一安装指引是 install/README 的手动 `cp`（形态 B），无脚本、无校验。
- **动机**：新人或新项目按主 README 接入 → 跑的是没有 Gate 注册表 / 四轴分流 / SOLO 连贯路 / case-000 固化成果的旧代行为 → Validation 主线验证的不是被验证对象，体系目标受损。
- **route_back_to**： bindings/joycode/install（+ bin/）。修法二选一：① acrs-install.sh 增加 joycode-cli-native 形态（装 6 入口 + 7 skills 或写 ~/.joycode）；② README 改推 install/README 形态 B 并提供 `acrs sync` 脚本（含 diff 校验）。修完前 README 主线不得指向旧代。

### M1【事实·Major】部署副本漂移已实际发生，无对齐机制
- **位置**：`skills/acrs-shared/SKILL.md` vs `~/.joycode/skills/acrs-shared/SKILL.md`（3 处差异：L3 Binding 行、能力资产归属段、来源标注措辞）；`bindings/joycode/install/README.md:27-29`
- **证据**：实测 diff 出 3 处内容漂移（部署侧是旧版「本文件夹 = L3 JoyCode 载体」叙事）；install/README 的同步方式是手动 `cp -R`，无版本记录、无 drift 校验。acrs-shared/DESIGN.md §7 自己要求「防漂移」，但同步机制本身先漂了。
- **route_back_to**： bindings/joycode/install——把同步做成脚本（`acrs sync`：copy + diff 报告 + 部署日期登记），并在部署副本头部标注来源 commit。

### M2【事实·Major】总控 skill 的「JoyCode 特有」章节住在平台无关层
- **位置**：`skills/acrs/SKILL.md:163-167`（§十「JoyCode Binding 注意（本载体特有）」）；对照 `skills/README.md:4`（「平台无关、可被任何 binding 复用」）、`PRINCIPLES.md:7-10`（P1 Core > Binding）
- **证据**：§十 内容（无 MCP Ledger 的退化、`.acrs/blueprint.md` 画像、续跑纪律 case-000#F-001 Binding 层来源）全部是 JoyCode 载体特定。case-000 findings 自己把 F-001 归层 **Binding**，固化物却进了 `skills/`（ROADMAP ②″ 称「能力资产，平台无关」）。
- **route_back_to**： skills/acrs——§十 迁往 bindings/joycode/（cli 侧入口或 binding README），skill 本体只留一句「载体特定注意事项见对应 binding」。

### M3【事实·Major】Convention 层来源标注悬空：引用不存在的 RFC
- **位置**：`skills/acrs-shared/SKILL.md` R2（承 RFC-002）、R4（承 RFC-005）；`RFC/RFC-001-Runtime-Lifecycle.md:135`（引 RFC-002）；`bindings/joycode/cli/root-prompt.md`（引 RFC-002/005/006）；对照 `ROADMAP.md:32-33`（RFC-002 不冻结、003/004/005 待补）
- **证据**：RFC/ 目录只有 000 / 000A / 001 + runtime-sequence。acrs-shared/DESIGN.md §2 要求「每条 MUST 能追溯到已过闸门的来源」，实际多条规则追溯目标是空指针。
- **route_back_to**： skills/acrs-shared——悬空引用改为「RFC-002（未冻结，草约见 …）」式显式占位，或先落 RFC-002/005 最小骨架；DESIGN §2 增补「来源必须可解引用」检查。

### M4【事实·Major】Core catalog 角色层落后于 skills 现实，命名映射断裂
- **位置**：`core/agent-catalog.md`（仅 worker/reviewer/architect/test 四角色）；`validation/production/case-000/findings.md` 多处回链「acrs-orchestrator」（实际目录为 `skills/acrs/`）；`docs/layout.md:21`（同样写 orchestrator）；`bindings/joycode/agents/`（6 入口含总控）
- **证据**：① 新体系 6 角色（orchestrator/architect/backend/test/critic/solo）与 catalog 4 角色的渲染关系（backend=worker 渲染？critic=reviewer 渲染？solo 对应 catalog 哪个？）无任何映射表——只有旧代 `app/agents/README.md` 暗示过；② case-000/layout 的「acrs-orchestrator」指向不存在的 skill 名；③ agent-catalog 声明「orchestrator 不是 Agent 不列入」，新体系却给了它角色 skill + 入口 Agent，该裁决未被重新表述。
- **route_back_to**： core/agent-catalog.md——补「catalog 角色 ↔ acrs-* skill ↔ 入口 Agent」映射表，并裁决 solo/critic 的 catalog 地位（新增实例 or 渲染），同步修正 case-000/layout 的引用名。

### M5【事实·Major】两代 Binding 并存无裁决说明，旧代含悬空 on_init
- **位置**：`bindings/joycode/app/agents/backend/agent.md`（on_init 引用不存在的 `skills/backend-java`）；`app/agents/README.md`（「刻意不预建 architect」叙事已被新 6 入口推翻）；`bindings/README.md`（同时介绍 agents/ 6 入口与 app/ 3 bundles，未说明新旧关系）；`app/rfc-implementation-map.md`（引旧结构 shared/templates）
- **证据**：app/ 侧是 RI 时代 MVP（backend 渲染 worker、prompt 为 bugfix 导向：failing_cmd），与 acrs-backend「照冻结设计实现」语义已分叉；quick-start.md:69 称领域 skill「刻意还没建」，而 app bundle 的 on_init 正在引用它。
- **route_back_to**： bindings/joycode/app——README 顶部加状态声明（「本目录为 RI 时代 MVP，现行入口见 ../agents/；APP 原生编排仍属 🟡 未实测」），悬空 on_init 加「待建」注释或删除。

### M6【事实·Major】陈旧事实陈述与内联声明不实
- **位置**：`bindings/joycode/cli/root-prompt.md:93`（「REJECT 回环在 CLI 上未实跑（RI-001 D-1）」）vs `RFC/RFC-001:88-92`（「✅ 实证 RI-BUGFIX-002 REJECT 回环已跑通」）、`ROADMAP.md:83`（✅）；`docs/quick-start.md:28`（「root-prompt 已内联 acrs-shared 的行为规范」）——实际是摘录渲染，且 acrs-shared 已从 R1–R9 增至 R1–R13，root-prompt 未更新；`ROADMAP.md:39`（「bindings/joycode/{app,cli,skills}」——bindings/ 下无 skills/ 子目录）
- **证据**：同一事实在仓库内有相反陈述；quick-start 的 CLI 路径整体仍指向旧代（手贴 root-prompt），未提 6 入口部署形态。
- **route_back_to**： cli/root-prompt + docs/quick-start——更新已验证清单与「内联」声明，quick-start 增补现行推荐入口（与 C1 修法联动）。

### m1【观点·Minor】三套原则编号并存，跨文档引用需读者自行换算
- **位置**：`PRINCIPLES.md`（P1–P9：Core>Binding…）与 `RFC/RFC-000-Scope.md:67-85`（P-1–P-9：Platform First…）同名不同义；`RFC/RFC-000-architecture-manifesto.md:89-103` 还有 Principle 1–7 第三套。PRINCIPLES P5 引「RFC-000 P-6」、P6 引「P-9」，必须查表才能读懂。
- **建议**： RFC/README 或 PRINCIPLES 顶部加一张「治理原则（PRINCIPLES Pn）↔ Scope 原则（RFC-000 P-n）」对照表；长期考虑改名（如 SP-n / CP-n）。

### m2【观点·Minor】FEEDBACK 反哺闭环的团队汇聚与「独立项目」判定无机制
- **位置**：`assets/README.md:57-71`；`bin/acrs:80-107`
- **证据**：`acrs feedback` append 到本地 clone 的 FEEDBACK.md；多人各自 clone 时反馈不回流则 Rule of Three 的「≥2 独立项目」永远无法被任何单点观察到。项目名取 `basename $PWD`，同仓库不同目录会记成不同项目（假独立暴露），反之同一目录两次会被误判同一项目。「≥2 独立项目」的「项目」未定义。
- **建议**： 定义「项目」= git remote 或显式 --project 参数；文档写明团队协作模式（PR 回流 / 中心仓）。当前 0 真实反馈，属观察期，不阻塞。

### m3【观点·Minor】派生资产重新脱敏复制时缺 FEEDBACK 核验步骤
- **位置**：`assets/README.md:66-68`
- **证据**：「源升级后重新脱敏复制（保留 FEEDBACK.md）」——无「复制后逐条核对 FEEDBACK 未消化条目是否已被上游修复」的闭环，wrong 类反馈可能被静默冲掉。
- **建议**： 重复制流程加一步：diff 新旧资产 + 逐条标注 FEEDBACK 未消化条目的状态（已修/仍存在）。

### m4【事实·Minor】ROADMAP 残留与 P9 冲突的预设计表述
- **位置**：`ROADMAP.md:40`（「⬜ 领域 Skill：java-backend、code-review（下一步 #2，本 ROADMAP 后紧接）」）vs `PRINCIPLES.md:57-63`（P9：没有真实案例禁止新增 Skill）
- **证据**： 预设 skill 名单与 P9 字面冲突（实际未建，是旧文本残留）；该行「下一步 #2」与文末「当前下一步」列表也不一致。
- **建议**： 删除或改写为「出现 ≥3 次重复后按 P9 抽取，候选：java-backend、code-review」。

### m5【事实·Minor】.DS_Store 入库
- **位置**： `bindings/`、`skills/`、`reference/`、`assets/payment/` 下多个 .DS_Store 文件
- **建议**： git rm --cached + .gitignore 补 `.DS_Store`。

---

## 三层分离健康度

- **Core（RFC/ + core/）**：抽象总体克制——单一不变量 INV-VERIFY + 五段式 Schema + 「catalog 非强制」的自我防膨胀设计是亮点，接地铁律（P1–P4 映射）真实执行；但 catalog 角色层已落后 skills 现实、部分 RFC 引用悬空，Core 是三层里「最健康但开始积灰」的一层。
- **Skill（skills/）**：确实薄（角色入口 23–46 行），acrs-shared 有 DESIGN.md 尺寸预算与趋势监控，治理意识罕见地好；但总控 skill §十 混入 JoyCode 特定内容，是三层分离最明确的一处违例（M2）。
- **Binding（bindings/）**：新 6 入口本身合格（只做翻译、无长逻辑）；但本层是问题重灾区——新旧两代并存无裁决、安装器装旧代、部署副本漂移、root-prompt 陈旧。体系当前的主要债务全部堆在 Binding 层的「过渡未收口」。

## 完备性 vs 过度设计（以「尚未跑通」为前提）

- **超前了（YAGNI 违背，均为观点）**：app/ 原生编排整套（capability-matrix 的递归 SubAgent/Resume 时序、rfc-implementation-map）——零实测且已被新体系绕开；benchmark 契约章节（validation/README:73-80，planted defect/oracle 设计精细）在 0 个 production case 时偏早；「资产 → Skill 升级通道」在首份资产 0 次复用时已写入 ROADMAP Phase 4。
- **克制得好的**：Phase 3.5 产品化闸门、Benchmark 不预造、capability support matrix 明确「≥2 平台才建」、lifecycle/faq 暂不写——这些「不做什么」的决策是仓库最成熟的部分。
- **真缺口**：case-001 尚无 README/登记（production 线只有 findings.md，validation/README:66 的目录约定是 case-XXX/findings.md，勉强合规但缺 case 登记信息）；无任何 CI/lint 级的机械校验（如 RFC 引用可解性、skill 与部署副本 diff）——本次多条 Major 本可被脚本拦住。

## 最值得做的一件事

**统一接入路径并收口旧代（C1 + M1/M5/M6 合并为一次「接入收口」提交）**：让 README 主推的安装方式装出的就是 ROADMAP 验证主线要验证的那套 ACRS-native Skills（升级 acrs-install.sh 或改推 install 形态 B + `acrs sync` 脚本），同时给 app/ 旧代打遗留标注、更新 root-prompt/quick-start 的陈旧事实。这件事不做，case-001 跑通与否都无法解释「验证的到底是哪套体系」——它是 Validation 阶段一切结论的效力前提。
