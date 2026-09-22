# assets/ —— 工程化标准资产沉淀

> 定位：**跨项目复用的工程标准**住这里，随 ACRS 仓库分发——别人 clone ACRS 即得技能（`skills/`）+ 资产（`assets/`）。
> 来源：case-001 F-001（2026-09-21），工程沉淀希望跨项目按需复用、不全局污染。

## 与其他层的分工（一张表说清）

| 层 | 住哪 | 管什么 | 例子 |
|---|---|---|---|
| **标准资产（本目录）** | ACRS 仓库 `assets/` | 跨项目、跨领域可复用的工程标准 | 架构规范模板、领域规范、通用 checklist |
| 项目差异规范 | `<项目>/.acrs/rules/` | 本项目独有定义，随项目 git 走 | 错误码口径、模块边界 |
| 中心仓资产 | 独立仓库（FinBuddy 模式，路径指针定位） | 公司架构资产、脚手架 | dongboot 脚手架 |
| 流程 Skill | ACRS 仓库 `skills/` | 怎么做（流程），非知识 | acrs-architect 等 |

## 准入门槛（防烂根，P9 按需生长）

进本目录有两条来源路径，**来源等级（provenance）必须打标**：

### 路径一：empirical（实证沉淀，默认等级）
1. **≥1 个项目真实用过**才进——不预想、不囤积。
2. **跨项目可复用**：只含工程标准，不含特定项目差异定义、不含涉密业务细节。

### 路径二：curated（开源/文献提炼，2026-09-21 开）
从主流开源项目 / 权威架构文献提炼工程标准（如 Go 生态规范、K8s 设计惯例）。**约束**：
- **生产流程走体系自己**：Agent 读源（仓库/官方文档）→ 提炼成 guardrails 格式 → **ACRS Critic 评审通过**才入库（评审独立性同样适用——提炼者≠评审者）。
- **入库即打 `curated` 标**（资产 README frontmatter + 下表来源列）——它没经过实战，信任度低一档。
- **约束力降档**：curated 资产的 MUST 拆进 design_checklist 时标 `DC-xx(curated)`，Critic 勾对时视为强参考而非铁闸；与项目实际冲突时项目定义优先（走优先级链）。
- **首验升级**：第一次在真实项目完整跑过且无 wrong 类反馈 → FEEDBACK.md 记首验 → 升 `empirical`（升级后约束力全档）。
- **许可纪律**：提炼规范思想与工程约束，不复制代码；来源 repo 与提炼日期必记。

### 通用
3. **命名清晰**：`assets/<领域>/<名称>.md`（领域如 `architecture/`、`payment/`、`java-backend/`），出现第一份真实资产才建子目录。

## 使用方式（按需加载，非全局）

> **换机器/换位置**：ACRS 仓库位置登记在 `~/.acrs/path`（单行绝对路径，fin-buddy 同款指针模式）。项目 blueprint 用 `$ACRS_ROOT` 相对引用，不写死绝对路径。

**团队接入（两个入口）**：

| 命令 | 作用 |
|---|---|
| `bash install.sh`（ACRS 仓库根） | 一次性接入：写 `~/.acrs/path` 指针 + 校验结构 |
| `bin/acrs init / path / assets / attach` | 日常操作：init 同上；path 打印根；assets 列清单；**attach 把资产登记行幂等写入项目 `.acrs/blueprint.md`** |

**三步接入（新项目快速用上资产）**：

1. **登记**：在目标项目执行 `bash <ACRS仓库>/bin/acrs attach payment/java-backend-guardrails [项目目录]`（省略目录=当前目录）——脚本生成标准登记行：

```markdown
## 知识资产（ACRS assets）
- asset: payment/java-backend-guardrails
  路径: $ACRS_ROOT/assets/payment/java-backend-guardrails   # ACRS_ROOT = $(cat ~/.acrs/path)
  场景: 按该资产 README 加载表，core-must 类恒载 + 按任务场景加载
  约束力: 相关 MUST 须拆进 design_checklist（DC-xx）才为硬约束
```

2. **解析**：blueprint 随注入包自然流入子 Agent（acrs skill 注入包机制，无需改 skill）→ 读到登记行 → `$(cat ~/.acrs/path)` + `assets/<相对路径>` 定位 → 按场景 Read 对应文件（非全量）。
3. **条目化**：Architect 把资产相关 MUST 拆进 design_checklist（DC-xx）→ Backend 逐条落地 → Test 逐条覆盖 → Critic 逐条勾对。**未进 DC 的规则只算参考，进 DC 的才是硬约束。**

## 优先级链（冲突消解）
```
项目 rules（.acrs/rules/）> 项目本地定义 > assets/ 标准资产 > 通用基线
```

## 现有资产

| 资产 | 内容 | 来源 | 等级 |
|---|---|---|---|
| [payment/java-backend-guardrails/](payment/java-backend-guardrails/README.md) | Java 后端工程化标准（支付语境）：ARCH/DM/PS/API/INT/CS/AP 六族规则 + 参考实现 + 18 条核心 MUST | fin-buddy @676aab9，2026-09-21 脱敏复制 | empirical |
| [go-backend/go-backend-guardrails/](go-backend/go-backend-guardrails/README.md) | Go 后端工程化标准：ERR/CTX/CONC/LAY/DI/API/LOG 七族 15 条 MUST（错误处理链/context/并发/包布局/依赖注入/API 契约/日志） | go-kratos 官方文档+源码提炼，2026-09-22，ACRS Critic 评审 PASS_WITH_NITS（[评审报告](../docs/review/2026-09-22-review-go-001.md)，15/15 源核实） | curated（待首验升级） |

## 自我进化反哺

资产不是死拷贝，真实使用中的发现要能回流。最小闭环 = 反馈通道 + 消化规则：

**记录**（低摩擦，两种方式）：
- 人工/Agent 命令：`acrs feedback <领域/资产> <missing|wrong|stale|new> "描述"`——append 到该资产 `FEEDBACK.md`（日期 | 项目名 | 类型 | 描述）
- Critic/评审时发现**资产规则本身**有问题（缺规则/规则错/过时），顺手记一条

**消化**（Rule of Three，与 skill 升级同判据）：
- 同一问题 **≥2 独立项目**命中 → 行动
- **原生资产**（ACRS 直接沉淀）：直接改，git 历史即版本
- **派生资产**（脱敏复制，如 java-backend-guardrails）：ACRS 侧不改内容（改源原则）→ 反馈路由上游源仓库（fin-buddy evolution）→ 源升级后重新脱敏复制（**保留 FEEDBACK.md**，资产内容与使用反馈分离）
- **curated 资产**：wrong 类反馈直接改本体（无上游）；连续 2 个项目 wrong 命中同类 → 降级弃用（提炼源头不可靠）
- 某资产被 ≥2 项目独立复用 → 候选抽成独立 skill（进 `skills/`，与下方演进条目同规则）

**分工**（防双通道）：资产级反馈走 `FEEDBACK.md`；ACRS 流程/体系级发现走 `validation/production/case-*/findings.md`。

**消化节奏触发器**（fin-buddy@5ecfd07 实地教训：其进化 inbox 堆积 11 条、applied 为 0——纯事件驱动等 Rule of Three 自然命中 = 堆积腐烂）：
- 事件驱动之外**加节奏驱动**：每个真实 case 收口（acrs SKILL 判 DONE 核对 ⑤）时 MUST 顺带扫一遍各资产未消化 FEEDBACK 条目——逐条重估计数（跨项目命中 +1）、或按 validation「诊断先于修改」给出终局，不许只 append 不清账。

## 版本与演进
- 资产随 ACRS 仓库 git 历史 evolve；项目 blueprint 引用时建议记录来源 commit（可追溯）。
- 某资产被 ≥2 个项目独立复用 → 候选抽成独立 skill（Rule of Three，进 `skills/`）。
