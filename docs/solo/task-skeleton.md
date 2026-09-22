# ASSET-GO-001 骨架 —— Go 后端 guardrails（curated）

## 核心流程
1. 读注入包（协议 + Java 格式参照）✅
2. 研究 go-kratos 官方文档 + GitHub 源码，按域采集证据（每条 MUST 落实到具体文件/文档 URL）
3. 组织 4 个规则文件（7 族 → 4 文件）+ README + FEEDBACK
4. 自检：ls + MUST 计数 + 源依据抽查

## 规则族规划（目标 12-15 条）
- ERR 错误处理链：proto 定义 reason、errors.New/NewFederation 分层、wrap 惯例（≈3 条）
- CTX context 传递与超时：context 作为首参、超时中间件（≈2 条）
- CONC 并发生命周期：errgroup 派生 ctx、goroutine 泄漏防护（≈2 条）
- LAY 包布局分层：cmd/internal/biz/data/service 四层、依赖方向（≈2 条）
- API 契约：proto 单一来源、HTTP/gRPC 双协议注解（≈2 条）
- DI wire 边界：Provider 收口、禁止手写单例（≈1 条）
- LOG 日志与元信息：log.Helper + WithContext、metadata 透传（≈2 条）

## 文件规划
- README.md（provenance: curated frontmatter + 加载表 + MUST 总索引）
- 01-errors-and-logging.md（ERR + LOG）
- 02-context-and-concurrency.md（CTX + CONC）
- 03-layout-and-wire.md（LAY + DI）
- 04-api-contract.md（API）
- FEEDBACK.md（空表初始化）

## 边界
- 每条 MUST 必须有真实源依据；抓不到源依据的规则宁可砍掉
- 提炼思想不抄代码
- curated 标注 + 约束力降档说明必须写进 README
