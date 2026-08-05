# PORTABILITY — 同一 BugFix，App binding vs CLI binding（真实运行对比）

> **实验目的**（回应"选同一 BugFix、同一 ACRS Core，分别跑 App 与 CLI，只换 Binding，不改规范"）：
> 检验 ACRS Core 的可移植性——同一 fixture、同一套 Core 契约（agent-contract §2 五段式 + INV-VERIFY），
> 只把 Binding 从"APP 真隔离子 Agent"换成"CLI 单上下文 Root Prompt 模拟"，看**哪些属性可移植、哪些退化**。
> **没有改动任何 RFC / Core 文件。**

## 两次运行（同一个 fixture：两对称 bug 相互掩盖）

| 维度 | APP binding（RI-BUGFIX-002） | CLI binding（本实验） |
| --- | --- | --- |
| 执行形态 | 4 个真实 spawn 的隔离 Context（worker#1/review#1/worker#2/review#2）| 1 个 Context，Root Prompt 串行扮演三角色 |
| 最终退出码 | 0（3/3）| 0（3/3）|
| **是否触发 REJECT 回环** | ✅ 是（Reviewer#1 抓到被解开的 unreserve）| ❌ 否，一次改全两个 bug |
| Done Gate | 独立 PASS 后 Finish | 重跑 PASS 后 Finish |
| 证据 | `../evidence/`（两轮 worker/reviewer 日志）| `evidence/cli-final-test.log` + `cli.patch` |

## 核心发现：INV-VERIFY 其实是**两个子属性**，可移植性不同

Core 的 INV-VERIFY（agent-contract §3）在真隔离下同时给了两样东西，本实验把它们**拆开**了：

| INV-VERIFY 的子属性 | CLI 单上下文能否移植 | 证据 |
| --- | --- | --- |
| ①**独立重取客观信号**（自己重跑测试拿真实退出码，不采信自述）| ✅ **可移植**，且真跑了 | CLI 扮演 Reviewer 时确实重跑 `run_tests.py` 拿到 OS 退出码 0 |
| ②**验收者对改动无先验 / worker 视野受限**（进程边界天然保证的"盲验"）| ❌ **退化**为"角色扮演的自律" | 同一上下文里，Reviewer 的记忆里就有 Backend 刚才的每一处改动 |

**为什么 REJECT 没触发**：本 fixture 靠"scoped worker 只看到局部 → 独立全量 reviewer 抓到被解开的回归"来自然制造 REJECT。
CLI 单上下文的 Backend 读代码时两个 bug 尽收眼底，自然一次改全——**制造 REJECT 所依赖的"视野隔离"消失了**。

## 结论

1. **Core 契约本身可移植**：五段式契约 + "重取退出码"的验证纪律，在 CLI 上原样成立且真跑通。
   同一 Core、只换 Binding、不改规范——这一点**证伪了"规范里混入平台细节"的担忧**（本实验没碰任何 RFC）。
2. **但 INV-VERIFY 的"隔离强度"是 Binding 相关的**：APP 靠进程边界**机制强制**盲验；
   CLI 只能**纪律性自律**，能不能真拿到 REJECT 取决于扮演是否克制，而非机制保证。
3. → **这不是 Core 的 bug，是一条应写进 RFC-006 的 Binding 合规差异**：
   *CLI binding 提供的 INV-VERIFY 是"弱隔离"（signal-independent 但非 knowledge-independent）。*
   若某任务的正确性高度依赖盲验（如"修一处解开另一处"的回归），**该任务 SHOULD 路由到 APP binding**，
   或在 CLI 上以补偿机制（如强制清空上下文重开一个会话做 review）弥补。

> 一句话：**Core 过了可移植性测试；INV-VERIFY 需要在 RFC-006 里按 Binding 标注隔离强度。**
