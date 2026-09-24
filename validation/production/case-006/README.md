# case-006 — RFC-006 首个真实派发案例（validate --json）

> **类型**：机制实证（RFC-006 §5 升 Frozen Candidate 判据）  
> **日期**：2026-09-24  
> **任务**：为 `bin/acrs validate` 实现 `--json` 输出模式（真实功能：喂总控程序化消费链）  
> **链路**：总控（本会话）→ Backend 子实例（general-purpose agent）

## 完整运行记录（判据逐条对照 §5）

| §5 判据 | 实证 | 证据 |
|---|---|---|
| 1. 实现通过正反例测试 | 26 PASS / 0 FAIL（含子实例新增 5 项 --json 测试） | `bash test/validate/run.sh` exit 0 |
| 2a. 注入包按 C1 落盘 | `.acrs/handoff/add-json-output.json`（.gitignore 外，本次随案例归档说明） | 文件在仓 |
| 2b. validate 在派发前实际运行且结论参与决策 | **拦截一次**：injected_artifacts 含 status=DRAFT_FOR_SELF → V1.4 ERROR exit 1 → 总控不放行派发，修正（移除 Draft 资产）后复验 exit 0 才派发 | 拦截/放行两次运行均真实发生（本会话） |
| 2c. result 落盘 + validate --result 参与判 DONE | `.acrs/handoff/add-json-output.result.json` → exit 0 | 总控亲测（不信子实例自述，复跑 test + 三条 DC 逐条亲验） |
| 3. C7 接线后无绕过退路 | 本案例判 DONE 全程经 validate；G-ACCEPTANCE 行已含「落盘件经 acrs validate --result exit 0」 | skills/acrs/acrs/SKILL.md Gate 注册表 |

## DC 勾对（总控亲测）

- DC-01 ✓ `--json` 正例：单行 `{"ok": true, ...}` exit 0
- DC-02 ✓ ERROR 反例：`errors: ["[V1.1] 必填字段缺失或为空: task_id"]`，ok:false exit 1
- DC-03 ✓ 人类模式输出不变，既有测试全绿

## 观察与发现

- **validate 参与决策的首次真实拦截**：V1.4（DRAFT_FOR_SELF）拦下了「注入 Draft 资产」的纪律违例——这不是演练，是总控自己差点犯的错（想给子实例注入 RFC-006 全文，Draft 资产不满足注入纪律），被自己前一天立的机器规则拦住。**机制强制 > 纪律自律的活体证明。**
- 子实例中途自报一次测试失败（fixture 不在 C1 标准布局致 W1.2 意外触发），自主定位修复——注入包 environment 的 run_steps 起了作用。
- W1.2 的上推三级逻辑在 /tmp fixture 下触发误报属预期（无 --root 时的边界），正例（C1 布局）不受影响。

## 结论

RFC-006 §5 三判据全部满足 → 升 **Frozen Candidate**。下一个真实派发案例继续走本链路积累 RI。
