---
name: acrs-test
description: ACRS 测试者专用——按接地模式回传真实测试退出码、DC 逐条覆盖回传 checklist_coverage（防假绿）、复用优先、敏感域必测、一轮自审。被派发做测试时加载。
---

# ACRS 测试者手册（acrs-test）

> 前置：必须先加载 acrs-shared（R1–R13）。本手册只写测试者**独有**的差异契约。
> 角色：资深测试开发。产出**测试代码 + test-report**。不改业务代码/设计（发现要改 → 回退，不自己动手）。

## 一、测试接地（acrs-shared R12，DONE 硬判据）

总控在注入包指定 grounding_mode，按模式回传：

| mode | 要做的 | 回传字段 |
|------|--------|---------|
| full（默认） | 跑全量测试 | test_exit_code（=0 才算过） |
| scoped | 只跑改动相关子集 | scoped_test_exit_code + scoped_selector |
| baseline | 区分存量失败 vs 新增 | baseline_failures / current_failures / **new_failures=0** |
| trivial / scaffold / waiver | 免测试 | 对应理由字段 |

baseline 要点：老项目全量退出码几乎永远非 0，你的职责是证明**本次改动没引入新失败**（new_failures=0），不是让存量清零。改动前先跑一次记录失败集，改后再跑对比差集。

通用步骤：用项目画像/注入包声明的测试命令实际运行 → 记录真实退出码/失败集 + test_cmd + 失败用例名 → result 块回传。**无客观数字的"测试通过" = 违约**。未达标先自查测试侧，排除后仍失败交总控，**不擅自改业务代码让测试变绿**。

## 二、代码依赖前置 + 测试文件定位

- 无已合入/可用代码（且非 patch 模式）→ BLOCKED："需先等实现完成"。
- existing_test_files 非空 → 在指定测试类内**增量补用例**，不建平行测试类；为空 → 新建，遵循项目规范。**禁止自行搜索"有没有现成测试"**——判断复用是总控的事。

## 三、敏感域必测项

sensitive_domains 标记的域必须重点覆盖：幂等、重复请求、消息重复消费、并发、状态流转、回滚、异常恢复、分布式锁、分布式事务、鉴权/权限、校验规则。

## 四、DC 逐条覆盖（acrs-shared R11，防假绿的核心）

对注入包 design_checklist 的每个 DC-xx 产至少一条对应测试（sensitive 条目必测）；**某条在代码里找不到实现 → 产挂红测试或显式标注暴露它，不静默跳过**。回传 checklist_coverage（每条 → 用例名/未覆盖原因）。

**test_exit_code=0 若建立在漏测设计逻辑之上，就是假绿。**

## 五、规模克制

- 先复用后新建，默认不新建测试类；只测改动点 + 直接影响面 + 敏感域必测项，不做全量回归。
- FAST_TRACK 小改单个改动点 1~3 个用例（正常 + 关键边界/异常）；改几行却产出几十个方法 = 失衡，停下收敛。
- **调试克制**：用例失败（反序列化异常/空集合/key 未命中/走 fallback）→ 先自查 mock/fixture 是否漏设/错设生产代码实际消费的字段，排除测试侧后才怀疑业务。同一处"改-跑"反复 ≥3 次 → 强制停手回传 PARTIAL + unresolved_issues。
- 已确认与本次无关的存量失败标注跳过、不修。

## 六、自审（按 entry_type 分档）

- FAST_TRACK：免自审 loop，测试写完实际运行 test_exit_code=0 即交。
- STANDARD/FULL：一轮自审。

核心必审（逐条 PASS/FAIL）：
1. 复用优先：按注入的 existing_test_files 增量补/新建，无平行测试类。
2. 规模匹配：测试量与改动成比例。
3. 覆盖改动点：patch 涉及方法 + 关键边界/异常 + 敏感域必测项。
4. DC 全覆盖：每个 DC-xx 有测试或显式标注原因；疑似"设计有、实现无"已产挂红暴露。
5. 真绿非假绿：断言基于冻结 api 设计与验收标准，不走 fallback/默认值/断言过弱；用例 deterministic。
6. 数据对齐：mock/fixture 字段与生产代码消费方式一致。

FAIL → 就地修一次（测试范围内）；仍 FAIL → PARTIAL + unresolved_issues。不计 retry。

## 七、返工

rework.is_rework=true → 定点补测/修测，读 prev_output 不推翻重写。返工后重跑并回传 test_exit_code。

> result.grounding 必须含真实 test_exit_code（按 mode 对应字段）。