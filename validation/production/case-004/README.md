# case-004 — 资产三步接入 Feature 全链（F04）

> **类型**：STANDARD Feature（登记/核验/确认三接口 + 8 模块 DDD 工程）。
> **来源**：2026-09-22 用户回报最终交付报告（G-CLARIFY → G-DESIGN → Backend → Test 90/90 → Critic
> REJECT → 修复 → 复审翻绿 → DONE，全链含真实回退闭环）。
> **脱敏**：项目住 `~/ai_workspace/F04_temp`，此处只留结论与分类，不复业务细节。

## 体系正例验证（本 case 最有价值的部分）
- **case-003#F-004 覆盖边界声明首次真实生效**：交付报告 §11.3 显式列出未验证边界（H2 行锁 vs
  MySQL FOR UPDATE 语义差异、MockMvc 未覆盖 servlet/网络层、DC-15 不可达分支白盒覆盖）并挂待联调清单。
- **case-001#F-003 派发故障协议第 2 次暴露且正确执行**：审批会话中断 → 派发两次 → 探查发现误建
  asset/ 残留目录 → 清理收编，未盲目重派（协议从纪律变成实测正例）。
- **确认链落盘**：DongBoot parent → spring-boot-starter-parent 替换经查证（内网制品不全）+ 用户批准 + spec §6 声明。
- **REJECT 回退链**：Critic 拦下 BLOCKER（source 校验遗漏）→ Backend 修复 → 复审翻绿，错误沿依赖正确回流。
- **需求边界控制正例**：需求"零新增基础设施"被严格执行——8 模块 DDD 工程 + H2，未自行引入 MQ/Redis/新服务/新状态中心。

## RFC-000B 首次真实运行定性（外部评审校准，2026-09-22）

**PASS WITH CALIBRATION**：首次真实闭环完成——Candidate 识别 ✅ / Evidence 收集 ✅ / Findings 分类 ✅ /
Admission 流程触发 ✅；**Core Candidate 判定边界待校准**（以 B-1 Admission Review 实测：RFC-000B 能否
对"单项目工程 Bug vs 项目级 Convention vs Binding vs 跨项目架构不变量"给出稳定、可复现的分类结果）。
注意：P8/RFC-000B §4"有资格 ≠ 现在就进"已在协议中生效（B-1 仅登记 Pending 未晋升），无需修协议；
校准点是**Review 尺度**，不是协议缺陷。

## findings 清单
见 `findings.md`（7 条：1 Core Candidate + 2 Convention + 1 Binding + 2 Usage + 1 琐碎）。

## Case Run Ledger（首账）
见 `findings.md` 末尾。
