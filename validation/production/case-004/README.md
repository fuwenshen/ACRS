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

## findings 清单
见 `findings.md`（7 条：1 Core Candidate + 2 Convention + 1 Binding + 2 Usage + 1 琐碎）。

## Case Run Ledger（首账）
见 `findings.md` 末尾。
