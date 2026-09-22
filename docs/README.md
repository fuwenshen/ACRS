# docs/ — 面向人的导读文档

> 本目录不放规范（规范在 `../RFC/`），只回答一个问题：**人怎么理解并上手 ACRS？**
> 规范层文档与导读层文档分离：RFC 是权威源头，这里负责把它翻译成可读的路。

## 文档清单（按阅读场景选）
| 我想… | 去读 |
| --- | --- |
| 5 分钟上手，把 ACRS 用起来 | [quick-start.md](quick-start.md)（含 🟢/🟡/⬜ 状态分级，别把设计意图当保证） |
| 搞懂它怎么跑（动词环） | [mental-model.md](mental-model.md)（Task→Context→Produce→Evidence→Verify→Decision→Handoff） |
| 搞懂任务怎么启动它 | [bootstrap.md](bootstrap.md)（各平台加载链，横切契约） |
| 查目录语义 / Artifact 命名 / 谁写谁读 | [layout.md](layout.md)（路径规范：Agent 不需要猜） |
| 同时用 ACRS 和 fin | [coexistence-fin.md](coexistence-fin.md)（同装不冲突，单任务单主线） |

## 写作约定
- 每篇只回答一个问题，不做全量手册。
- 状态分级诚实标注：🟢 已实测 · 🟡 设计意图 · ⬜ 未建。
