# 路径规范与导读（Layout Spec）

> 目的：**Agent 不需要"猜"**。哪个目录承担什么语义、Artifact 文件叫什么名、谁写谁读、活多久——全部固定下来。
> 本文是规范层文档；想快速理解整个体系，先读 [mental-model.md](mental-model.md)。

## 1. 目录语义（每个目录的语义必须固定）

ChatGPT 评审建议的九目录语义，按本仓库现状映射如下——**语义照收，目录不照搬**：

| 语义槽 | 本仓库位置 | 是什么 | 状态 |
| --- | --- | --- | --- |
| 定义规范 | `RFC/` | 协议 RFC（Scope / Terminology / Runtime Lifecycle） | ✅ |
| 稳定核心概念/Schema | `core/` | agent-catalog、agent-contract（含 INV-VERIFY） | ✅ |
| 行为约束（conventions） | `skills/acrs-shared/` | 所有 Agent 必守的行为（R1–R13）——L2 Convention 层 | ✅ 由 Skill 承载 |
| 可加载能力 | `skills/` | acrs-architect / backend / critic / test / solo / orchestrator | ✅ |
| 平台适配 | `bindings/` | 某平台怎么加载/执行 Skill（当前仅 joycode） | ✅ |
| Reference Implementation | `reference/` | 各平台的参考实现 | ✅ |
| 完整运行案例（examples） | `validation/production/` | 真实项目案例（case-000…） | ✅ 由 Validation 承载 |
| 合规检查（compliance） | `validation/` | Findings 分类闸门、验证方法论 | ✅ 由 Validation 承载 |
| 验证结果 | `validation/` | 验证产出与结论 | ✅ |
| 导读文档 | `docs/` | 给人读的入口（quick-start / mental-model / bootstrap / 本文） | ✅ |
| 安装工具 | `bin/` | `acrs-install.sh` | ✅ |

**规则**：新内容落位前先查这张表；表中没有的语义，先在 RFC 里立项再建目录，**不预造空目录**。

## 2. Artifact 命名规范

**核心原则：文件名表达 Artifact 类型，不表达生成它的 Agent。**

```
✅ handoff.yaml        ❌ backend-handoff.yaml
✅ review.yaml         ❌ review-result.json
✅ result.md           ❌ backend-result.md
```

理由：同一类型 Artifact 可能由不同 Agent 产出——Handoff 不只 Backend 会写，
未来 Architect / Security / Test 都会产生 Handoff。文件名按 Agent 命名会在角色扩张时爆炸。

统一命名（格式固定，禁止 `.json` / `.md` 混用变体）：

| Artifact | 文件名 | 说明 |
| --- | --- | --- |
| handoff | `handoff.yaml` | 只带引用（路径/退出码/一行摘要），承 R2 |
| evidence | `evidence.yaml` | 客观来源引用（git diff / test log / build 输出），承 R3 |
| review | `review.yaml` | 评审结论 + 分级 issues + verdict，承 R5 |
| result | `result.md` | 面向人读的任务结果，承 R13 |

## 3. 谁读 / 谁写 / 生命周期

每个 Artifact 的生产者、消费者、存活期固定如下：

| Artifact | Producer | Consumer | 生命周期 |
| --- | --- | --- | --- |
| task | Root / User | Agent | Task 生命周期 |
| handoff | Parent Agent | Child Agent | 一次交接 |
| evidence | Agent | Reviewer | 当前任务 |
| review | Reviewer | Parent Agent | 当前 Review |
| result | Agent | Parent / User | Task 完成 |
| archive | Runtime / Agent | Audit | 长期 |

这张表是 ACRS 具备"可执行协议"味道的最低要求：**读写权限与存活期不写清楚，
Agent 就会各写各的、互相踩踏、无人清理。**

## 4. 业务代码目录 ≠ ACRS 工作目录

**铁律：Agent 协作状态永远不落进业务代码目录。**

```
Project/
├── src/                  ← 业务代码
├── test/
├── pom.xml
└── .acrs/                ← Agent 协作状态（可整体删除，不伤业务）
    ├── task/
    ├── handoff/
    ├── evidence/
    ├── review/
    ├── result/
    └── archive/
```

- `.acrs/` 是**运行时工作目录**：由 `bin/acrs-install.sh` 创建，进 `.gitignore`（除非项目决定留档 audit）。
- 判据：把 `.acrs/` 整个删掉，项目必须照常构建运行——否则就是越界，算 P-级违规。
- 反例（禁止）：`src/main/java/.../handoff.yaml`、`docs/evidence.md` 散落在业务树里。

## 5. 一句话导读（新人/新 Agent 从这进）

- 想懂"它怎么跑" → [mental-model.md](mental-model.md)
- 想懂"目录怎么摆、文件怎么命名" → 本文
- 想上手 → [quick-start.md](quick-start.md)
- 想懂加载链 → [bootstrap.md](bootstrap.md)
