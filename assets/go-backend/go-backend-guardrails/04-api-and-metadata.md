> 【ACRS 资产 · curated】提炼自 go-kratos（GitHub go-kratos/kratos main 分支 + go-kratos.dev 官方文档，2026-09-21）。提炼工程思想非代码，许可纪律见 [README.md](README.md)。约束力降档：curated 资产为强参考，与项目实际冲突时项目定义优先。

# API + LOG 族 —— API 契约、日志与元信息传递

> 覆盖：protobuf 契约与 HTTP/gRPC 双协议、契约兼容性、结构化日志与敏感值、跨服务元信息。

---

## API-01: proto 是唯一契约源，双协议从同一份定义生成、注册到同一实现

**MUST**：
1. HTTP 路由用 proto 的 `google.api.http` 注解声明（如 `get: "/v1/todos/{id}"`），一份 proto 生成 pb.go / grpc / http / OpenAPI 全套绑定，**禁止在 Go 代码里另写一套路由/DTO**。
2. service 层实现生成接口，同一个实现注册到两种传输（`RegisterXxxServer` + `RegisterXxxHTTPServer`）——业务行为只在 service/biz 层，双协议不写两份。
3. 请求校验用 `validate.Validator()` 中间件执行生成的 `Validate()` 方法，必填字段用 `field_behavior` 注解声明——**禁止在 handler 里手写字段校验**。

**为什么**：proto 优先让契约成为编译期可验证的单一事实（HTTP 与 gRPC 的解码、操作名、中间件执行、编码都由生成适配器统一处理）；双协议共用规范操作名（`/todo.v1.TodoService/GetTodo`），日志/指标/追踪才能跨协议一致。

**源依据**：go-kratos.dev/zh-cn/docs/component/api/（定义服务、生成产物、实现并注册服务各节）；go-kratos.dev/zh-cn/docs/component/transport/overview/（生成的绑定节）。

**违例后果**：手写第二套路由后契约漂移（文档说 A、HTTP 走 B）；校验散落 handler 各处，漏网字段直达业务层。

---

## API-02: 契约兼容性纪律——编号不复用、删除保留痕迹、不兼容开新版本

**MUST** 客户端开始使用某 API 后：不得复用 Protobuf 字段编号或 enum 值；删除字段时保留其编号与名称（不挪给新字段）；保持已发布的 HTTP 路径不变；不兼容变更必须创建新的 API package 版本（如 v1 → v2）。proto 中的注释也是契约（会进入生成的 Go 与 OpenAPI 输出），修改需同等谨慎。

**为什么**：proto 编码靠字段编号定序——复用编号会让旧客户端把新字段按旧语义解码，是静默数据损坏；版本化 package 是 kratos 模板对不兼容变更的标准出口。

**源依据**：go-kratos.dev/zh-cn/docs/component/api/（错误原因与兼容性节；定义服务节："注释属于契约"）。

**违例后果**：旧客户端静默解析出错误数据（不报错、更难查）；枚举值复用让错误分支处理错乱，可产生资损级误判。

---

## LOG-01: 日志走结构化 slog + 请求级属性走 ctx；敏感值不进日志

**MUST**：
1. 日志统一用结构化 logger（kratos v3 基于标准库 log/slog：`log.NewLogger` + JSON/text handler），应用级字段（service.name、version）用 `logger.With(...)` 预挂；传输调用日志交给 `logging.Server(logger)` / `logging.Client(logger)` 中间件，**禁止在业务代码里手写请求进出日志**。
2. 请求级属性（request.id、trace.id）用 `log.ContextWithAttrs(ctx, ...)` 放进 ctx，打日志用 `logger.InfoContext(ctx, ...)` 自动携带——**禁止散落传参拼日志字段**。
3. 敏感值（password、token）不写入日志；确实可能经过日志链路的 key 用 `log.WithFilter(log.FilterKey(...))` 兜底脱敏——但过滤只是兜底，首选根本不记录。

**为什么**：kratos 的中间件式日志让每个 transport 调用自动获得操作名/耗时/错误，业务代码零手写；ctx 携带属性让请求链上任意一层的日志都自带上下文；FilterKey 支持点分组路径（authorization.token）做叶子级脱敏。注意：v2 的 log.Helper/Valuer API 不能与 v3 slog 混用。

**源依据**：go-kratos.dev/zh-cn/docs/component/log/（配置 handler、过滤敏感值、请求级属性、OpenTelemetry 各节）。

**违例后果**：手写请求日志与中间件日志重复且口径不一；敏感值泄漏进日志系统（合规事故）；无请求级属性的日志在跨服务排障时对不上链。

---

## LOG-02: 元信息经 metadata 中间件按前缀语义传递，信任边界前必认证

**MUST**：
1. 跨服务传请求元信息（request-id、调用方标识）用 kratos metadata（基于 context 携带 `map[string][]string`，应用代码不直接碰 HTTP header / gRPC metadata）：client 侧 `metadata.AppendToClientContext(ctx, k, v...)`，双端装 `metadata.Client()` / `metadata.Server()` 中间件。
2. 按前缀语义选 key：需要跨服务继续透传的用 `x-md-global-*`，只对当前服务可见的用 `x-md-local-*`（默认不转发）。
3. `metadata.Server()` 放在需要读取入站值的中间件**外层**；metadata 是调用方可控输入——**信任身份/租户字段前必须先过认证**，禁止用宽泛前缀转发授权或隐私 header，凭据不得写入日志。

**为什么**：global/local 前缀给了逐跳明确的传播语义（global 自动续传、local 单跳可见），显式 client metadata 只应放本次调用需要的 header；中间件顺序错了内层读不到值。追踪传播由 OTel 中间件负责，不需要另设 x-md- key。

**源依据**：go-kratos.dev/zh-cn/docs/component/metadata/（操作 metadata 值、安装传输中间件、默认传播规则、安全与中间件顺序各节）。

**违例后果**：绕过 metadata 直接头操作后换传输（HTTP↔gRPC）要改业务代码；把 `x-md-local-*` 当跨服务传递用会静默丢失；未认证就信任 metadata 里的 user-id 等于把权限交给调用方伪造。
