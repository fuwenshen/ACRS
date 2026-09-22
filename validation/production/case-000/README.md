# case-000 — diy-orc 六周生产缺陷史回溯归档

> **证据等级：回溯（Retrospective）**。非全流程跑通：缺陷真实发生、修复真实生效，
> 但过程发生在 diy-orc 体系内、无 ACRS 分类闸门在线留痕。本 case 是事后归档 + 闸门补审。
> 它解锁 Phase 3.5 闸门的「1 个真实 case」条件，但须标注「回溯证据」等级；
> 全流程 case 待 case-001（ACRS Skills 在真实项目上跑新任务）。

## 背景

- **生产系统**：`~/.joycode/agents/`（7 个中文 Agent）+ `~/.joycode/skills/diy-orc-agent-skill/`（7 个 Skill，882 行）
- **运行期**：2026-07 中旬 ~ 2026-09-20（约 6 周，真实 Java 项目任务驱动）
- **历史权威记录**：`~/.joycode/memories/project_orc_flowing_acrs.md`（120 行全史）
- **本次归档日**：2026-09-20

## 方法（PDCA）

1. **Collect**：从 diy-orc skill 文件的修复痕迹、记忆条目、用户通则中提取缺陷事件
2. **Categorize**：逐条过四分类闸门（Core / Convention / Binding / Usage），争议归低层
3. **回链**：每条 Closed finding 必须指向本次 ACRS-native 重设计的落地文件
4. **Promote**：≥2 次独立暴露的 finding 登记 benchmark 候选（终态 B）

## 闸门判据（摘自 validation/README.md）

- **Core 测试**：换任何平台（人团队 / Claude Code / Codex）都会犯吗？→ 才够 Core
- **两终态，禁第三态**：A·Closed（回链改哪层）/ B·Promoted（≥2 次→benchmark）
- **争议归低层**：判不准 Core 还是 Convention → Convention；Convention 还是 Binding → Binding

## findings 清单

见 `findings.md`。共 7 条：F-001 ~ F-007。
