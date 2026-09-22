# shared/evidence.md — Evidence Index（所有 Agent 共享）

> 承 RFC-002（Evidence Index）+ findings C-1。

## 原则
- Orchestrator 只持 **引用**，不持正文（RFC-001 §5）。
- Evidence **MUST** 来自客观来源：git diff / test log / build 输出 / Tool·MCP。不接受"我觉得"。

## 载体是 Binding，不是 Core（findings C-1）
Evidence Index 的存储介质（MCP ledger / 文件 jsonl / DB）是**可插拔 Binding**。
Core 只约束 WHAT：「Orchestrator 持引用、Boundary 解引用核验」。
> ⚠️ 本环境实证：MCP ledger（`ledger-blueprint`）调用 600s 超时不可用 → 回退文件型 `ledger.jsonl`。
> 已登记 RFC-006 合规缺口。两种载体都满足上述 WHAT。

## 一条引用的最小形状
```json
{ "task_id": "...", "kind": "test_log|patch|review",
  "ref": "evidence/xxx.log", "exit_code": 0, "summary": "一行摘要",
  "coverage_boundary": { "covered": ["..."], "uncovered": ["鉴权切面", "序列化"] } }
```
- `coverage_boundary`（case-003#F-004）：test_log 类引用附带——声明证据覆盖了什么、未覆盖什么；
  被 mock 掉的框架路径归 uncovered 并列入待联调清单，禁止 test=0 隐式扩张为"所有运行时行为已验证"。
  其他 kind 可省略。
