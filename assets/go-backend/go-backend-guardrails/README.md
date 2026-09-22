---
provenance: curated
source_repo: https://github.com/go-kratos/kratos
source_docs: https://go-kratos.dev
source_version: main 分支（kratos v3）+ 官方文档站 v3，2026-09-21 读取
distilled: 2026-09-21
license_note: 提炼工程思想非代码；kratos 为 MIT 许可，本资产不含其源码复制
---

# go-backend-guardrails —— Go 后端工程化标准（kratos 语境）

> **ACRS 标准资产 · 首份 curated**（ASSET-GO-001，2026-09-21）。
> 源：[go-kratos/kratos](https://github.com/go-kratos/kratos)（25.9k stars，MIT）main 分支（v3）+ [go-kratos.dev](https://go-kratos.dev) 官方文档，读真实源码与文档提炼。

## 定位

从 go-kratos 框架源码与官方文档提炼的**命令式可执行约束**（MUST / MUST NOT），供 AI Agent 写 Go 后端时遵守，供 Review 逐条勾对。覆盖错误处理链、context 与超时、goroutine 生命周期、包布局分层、API 契约、依赖注入、日志与元信息七个域，共 **15 条 MUST**。技术语境为 kratos v3 风格的云原生微服务（protobuf-first、HTTP/gRPC 双协议、wire 注入）。

## curated 纪律（本资产未经过实战）

- **约束力降档**：本资产 MUST 拆进 design_checklist 时标 `DC-xx(curated)`，Critic 勾对时视为**强参考而非铁闸**；与项目 `.acrs/rules/` 实际定义冲突时项目优先（走优先级链：项目 rules > 项目本地 > assets 标准 > 通用基线）。
- **首验升级**：第一次在真实项目完整跑过且无 wrong 类反馈 → FEEDBACK.md 记首验 → 升 `empirical`（升级后约束力全档）。
- **许可纪律**：只提炼工程思想与约束，不复制 kratos 代码；来源 repo 与提炼日期已记于 frontmatter。
- **版本注意**：提炼自 v3 文档与 main 分支；kratos v2 项目参考时注意差异（v2 用自带 log 包的 Helper/Valuer，v3 已切标准库 slog；迁移语境见 go-kratos.dev/docs/migration/v2-to-v3/）。

## 文件清单与场景加载

| 文件 | 规则族 | 加载场景 |
|---|---|---|
| 本 README §MUST 总索引 | 全部 | **每次写代码 / Review / 自检必过一遍**（15 条速查） |
| [01-errors.md](01-errors.md) | ERR-01~03 | 错误定义、错误翻译与传播、错误判断、错误码兼容（写任何错误处理时） |
| [02-context-and-concurrency.md](02-context-and-concurrency.md) | CTX-01~02、CONC-01~03 | 写跨层调用、出站调用、起 goroutine / 后台任务、middleware 链、panic 防护 |
| [03-layout-and-wire.md](03-layout-and-wire.md) | LAY-01~02、DI-01 | 新建服务 / 模块、调整包结构、定义 Provider / injector、资源生命周期 |
| [04-api-and-metadata.md](04-api-and-metadata.md) | API-01~02、LOG-01~02 | 定义/修改 proto 接口、双协议注册、写日志、跨服务传元信息 |

## MUST 总索引（15 条）

| # | 规则 | 一句话要求 | 详见 |
|---|---|---|---|
| 1 | ERR-01 | 业务错误用 kratos errors 结构化构造（code/reason/message 三段式），禁止裸 error 对外 | 01-errors.md |
| 2 | ERR-02 | 错误在 biz/service 边界翻译，根因 WithCause 保链，禁止存储细节透出 | 01-errors.md |
| 3 | ERR-03 | 错误判断走 errors.Is/Code/Reason，reason 定义在 proto，禁止字符串匹配 | 01-errors.md |
| 4 | CTX-01 | context 首参贯穿全链路，传输信息从 ctx 取，禁止中途断链 | 02-context-and-concurrency.md |
| 5 | CTX-02 | 长阻塞操作挂超时/可取消 ctx，清理用 WithoutCancel，禁止无预算直通 | 02-context-and-concurrency.md |
| 6 | CONC-01 | 多协程生命周期用 errgroup.WithContext 收口，eg.Wait() 收敛 | 02-context-and-concurrency.md |
| 7 | CONC-02 | 每个协程监听 ctx.Done() 并及时返回（泄漏防护） | 02-context-and-concurrency.md |
| 8 | CONC-03 | 服务端必挂 recovery，logging 置于其外层，panic 不炸进程 | 02-context-and-concurrency.md |
| 9 | LAY-01 | 遵循 api/cmd/internal 四层布局，实现内藏 internal/，生成物不手改 | 03-layout-and-wire.md |
| 10 | LAY-02 | 依赖单向：service 不碰 data、biz 只定义接口、data 禁 import DTO | 03-layout-and-wire.md |
| 11 | DI-01 | wire 编译期注入，每层小 ProviderSet，cleanup 链管理，禁止手写单例 | 03-layout-and-wire.md |
| 12 | API-01 | proto 是唯一契约源，双协议注册同一实现，校验交给 validate 中间件 | 04-api-and-metadata.md |
| 13 | API-02 | 字段编号/enum 值不复用，删除保留痕迹，不兼容开新版本包 | 04-api-and-metadata.md |
| 14 | LOG-01 | 结构化 slog + ctx 请求级属性，敏感值不进日志（FilterKey 仅兜底） | 04-api-and-metadata.md |
| 15 | LOG-02 | 元信息走 metadata 中间件按 global/local 前缀语义传递，信任前必认证 | 04-api-and-metadata.md |

> 违反任何一条 → Review 判定不通过（curated 降档语境下：强参考命中，须给出理由或修复）。

## 与 ACRS 对接（约束力入口）

1. **声明**：项目 `.acrs/blueprint.md` 登记 `asset: go-backend/go-backend-guardrails`，标注适用任务类型（新服务 / 错误处理 / 并发 / API / Review）。
2. **注入**：总控派发时按 blueprint 把对应文件路径写入注入包，子 Agent 按场景加载（非全量）。
3. **条目化**：Architect 把相关 MUST 拆进 design_checklist（DC-xx，curated 标注）→ Backend 逐条落地 → Test 逐条覆盖 → Critic 逐条勾对（强参考档）。未进 DC 的规则只算参考，进 DC 的才是硬约束。

## 演进

- **wrong 类反馈直接改本体**（curated 无上游）；连续 2 个项目 wrong 命中同类 → 降级弃用（提炼源头不可靠）。
- 第一次真实项目完整使用无 wrong 反馈 → FEEDBACK.md 记首验 → 升 `empirical`（登记进 [../README.md](../README.md) 现有资产表，等级列改为 empirical）。
- kratos 重大版本演进（如 v3 → v4）时按源重新核对，stale 类反馈触发重提炼。
