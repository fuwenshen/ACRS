> 【ACRS 资产 · curated】提炼自 go-kratos（GitHub go-kratos/kratos main 分支 + go-kratos.dev 官方文档，2026-09-21）。提炼工程思想非代码，许可纪律见 [README.md](README.md)。约束力降档：curated 资产为强参考，与项目实际冲突时项目定义优先。

# ERR 族 —— 错误处理链

> 覆盖：错误的结构化定义、跨层传播、程序化判断。核心思想来自 kratos errors 包（code/reason/message 三段式）。

---

## ERR-01: 业务错误用结构化 Kratos 错误构造

**MUST** 业务失败返回 `github.com/go-kratos/kratos/v3/errors` 构造的结构化错误（`errors.New(code, reason, message)` 或状态 helper `NotFound/BadRequest/InternalServer...`），三要素各司其职：

- **code**：HTTP 状态语义（400/401/403/404/409/429/499/500/503/504）
- **reason**：稳定的业务原因码（供程序判断，如 `USER_NOT_FOUND`）
- **message**：可安全返回给客户端的文案

**MUST NOT** 对外接口裸返回普通 Go error、手拼错误字符串、或把内部细节塞进 message。

**为什么**：kratos 错误是 HTTP 与 gRPC 双协议的统一错误载体（transport 经 GRPCStatus 自动转换，gRPC detail 用 google.rpc.ErrorInfo），HTTP handler / gRPC method 无需手工编码错误映射。裸 error 只能变成 500，调用方无法程序化分支。

**源依据**：go-kratos.dev/zh-cn/docs/component/errors/（概述、创建错误节）；go-kratos/kratos 仓库 `errors/errors.go`、`errors/types.go`。

**违例后果**：调用方只能字符串匹配判断错误；HTTP/gRPC 各写一套映射；内部细节（SQL、主机名）泄漏给客户端。

---

## ERR-02: 错误在 biz/service 边界翻译，根因用 WithCause 保链

**MUST** repository 与外部 client 的错误视为实现细节：在 biz 或 service 边界翻译成稳定的 Kratos 错误返回，底层根因用 `WithCause` 挂入错误链、不得丢弃；请求上下文信息（如 request_id）用 `WithMetadata` 附加。

典型形态（示意）：存储层返回 `sql.ErrNoRows` → 边界处判 `stderrors.Is` 后翻译为 `errors.NotFound("USER_NOT_FOUND", ...)`；未知内部错误 → `errors.InternalServer(...).WithCause(err)`。

**MUST NOT** 把 sql/driver/网络库错误直接透传给客户端，也不许在翻译时丢掉原始 err。

**为什么**：kratos 官方明确"按层传播"惯例——底层错误属于实现细节，公开错误必须稳定（reason 不随存储替换而变）；WithCause 返回克隆错误、根因保留在 Go 错误链中，日志与排障仍可追到根。

**源依据**：go-kratos.dev/zh-cn/docs/component/errors/（添加上下文、按层传播错误节）。

**违例后果**：换存储/换下游导致对外错误码漂移，调用方批量返工；丢根因后线上问题只能靠猜。

---

## ERR-03: 错误判断走程序化路径，reason 定义在 proto 且向后兼容

**MUST**：
1. 错误判断用 `errors.Is`（按 code+reason 比较）、`errors.Code(err)`、`errors.Reason(err)`——**禁止比较错误消息字符串**；普通 Go 根因用标准库 `stderrors.Is/As`。
2. 业务 reason 用 proto `ErrorReason` enum 定义在公开 API 附近（error_reason.proto），构造错误时取 `ErrorReason_XXX.String()`。
3. 客户端已使用的字段编号与 enum 值**不得复用**；删除字段保留编号与名称；不兼容变更开新版本 API package。

**为什么**：消息文案会变、reason 不会——稳定 reason 是调用方程序化分支的锚点；enum 收敛在 proto 里与公开契约同源、随 API 版本演进（kratos 模板即此形态）。

**源依据**：go-kratos.dev/zh-cn/docs/component/errors/（判断错误、API reason enum 节）；go-kratos.dev/zh-cn/docs/component/api/（错误原因与兼容性节）。

**违例后果**：字符串匹配在文案改动后静默失效；复用 enum 值让旧客户端把新错误当旧错误处理，产生资损级误分支。
