# ACRS Reference Implementation — BugFix (RI-BUGFIX-001)

一条 **BugFix** 的端到端参考实现，用**真实运行**检验 RFC-000/000A/001 定义的 WHAT 能否在 JoyCode 上成立。

## 定位（已拍板，可否决）

- **RFC 是 WHAT 的唯一权威**（可移植 Core Spec，见 RFC-000 §5）。
- **本 RI = 可执行的合规夹具（conformance fixture）+ 验证仪器，权威是"派生"的**——
  RI 只在它**符合 RFC** 的范围内才算对；发现 RI 与 RFC 冲突时，改 RI 或按 findings 修 RFC，不反过来让 RI 凌驾 RFC。
- **JoyCode 的 binding 对照本 RI；其他平台的 binding 对照 RFC**——避免 JoyCode 平台特性泄漏进平台无关的 Core Spec。
- **"Official Reference Implementation" 头衔要靠跑通验证挣得，不预先宣布。** 当前状态：`Validated for BugFix happy-path`。

> 为什么不直接把 RI 当跨平台基准：那会让"对照物"里混入 JoyCode 的 `Agent` 工具语义、
> 文件型 ledger 等实现细节，与 RFC-000 §5 的两层模型（Core 平台无关 / Binding 随平台）冲突。

## 目录

```
reference/joycode/bugfix/
├── README.md                    ← 本文
├── RUN-LOG.md                   ← 真实运行的时序与证据
├── findings.md                  ← 实测结论 → 喂给 RFC-001/002 修订（Step 2 输入）
├── binding-v0/                  ← binding v0：把 RFC 的 WHAT 落成 JoyCode 上的 prompt/约定
│   ├── workflow-bugfix.md       ← BugFix Workflow(SOP)：Route 剧本 + 与失败模式的分水岭
│   ├── orchestrator.md          ← Orchestrator prompt（只 Route/Collect，不实现）
│   ├── worker.md                ← Worker prompt（单 Context 跑完 Worker Loop）
│   ├── reviewer.md              ← Reviewer/Boundary prompt（独立解引用 + 独立重跑）
│   └── evidence-index.md        ← Evidence Index 约定（载体是 Binding）
├── fixture/                     ← 被测真实项目（库存台账，含可复现 bug）
│   ├── inventory.py             ← 出库漏释放预留的 bug（已被本次运行修复）
│   ├── test_inventory.py        ← 回归测试（修前 1 条必失败）
│   └── run_tests.py             ← 零依赖运行器，退出码即接地证据
└── evidence/                    ← 运行产出的客观证据（日志/diff/ledger）
```

## 如何复现

fixture 已被本次运行修复（当前 4/4 通过）。要复现"失败→修复"全过程：

```bash
cd reference/joycode/bugfix
cp evidence/inventory.before.py fixture/inventory.py   # 还原到 buggy 版本
cd fixture && python3 run_tests.py                      # 应 exit=1，1 条失败
# 然后按 binding-v0/ 的 prompt，扮 Orchestrator 派 Worker/Reviewer 重走一遍
```

## 本次验证结论（详见 findings.md）

- ✅ bugfix 全程在**单一 Worker Context** 连贯完成，只为独立验证 Spawn Reviewer——**未重演** Architect→Backend→Test 的过度编排失败。
- ✅ 子 Agent 隔离、不继承父对话；Orchestrator Context 不随 worker 数增长。
- ⚠️ 需修 RFC 措辞 3 处（Evidence Index 载体可插拔 / 解引用≠内联 / Orchestrator 只读核验）。
- ❓ REJECT 回环、溢出续接、Handoff 字段充分性**未验证**——RFC-002 暂不能仅凭此次实跑冻结。
