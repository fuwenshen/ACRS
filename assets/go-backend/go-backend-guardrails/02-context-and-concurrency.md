> 【ACRS 资产 · curated】提炼自 go-kratos（GitHub go-kratos/kratos main 分支 + go-kratos.dev 官方文档，2026-09-21）。提炼工程思想非代码，许可纪律见 [README.md](README.md)。约束力降档：curated 资产为强参考，与项目实际冲突时项目定义优先。

# CTX + CONC 族 —— context 传递、超时控制与 goroutine 生命周期

> 覆盖：context 贯穿与超时预算、并发生命周期管理、panic 防护。核心思想来自 kratos App 与 middleware 源码。

---

## CTX-01: context 作为首参贯穿全链路，传输信息从 ctx 取

**MUST** `context.Context` 作为所有跨层调用（service → biz → data → 外部 client）的首参数一路传递；请求级数据（trace id、操作名、请求头）放进 ctx 携带，不引入 goroutine-local 式全局变量。需要传输细节（Kind/Endpoint/Operation/Header）时用 `transport.FromServerContext(ctx)` / `transport.FromClientContext(ctx)` 获取。

**MUST NOT** 中途换成 `context.Background()`/`context.TODO()` 断链，或把原生 HTTP/gRPC 类型从 ctx 拖进业务层。

**为什么**：kratos 把 Transporter 放进请求 context，中间件无需知道请求来自哪个传输即可读取传输类型/端点/规范操作名——这是双协议统一的根基；只有策略确实与传输有关时才依赖原生 context 类型。

**源依据**：go-kratos.dev/zh-cn/docs/component/transport/overview/（Context 信息节）；go-kratos.dev/zh-cn/docs/component/middleware/overview/（编写中间件节）。

**违例后果**：断链点之后的超时/取消/trace 全部失效；业务层耦合具体传输后，新增协议要改业务代码。

---

## CTX-02: 长阻塞操作必须挂超时/可取消 ctx；清理不继承请求取消

**MUST**：
1. 出站调用、停机、注册等长阻塞操作都挂在**可取消或带超时**的 ctx 上，超时在构造/边界处显式配置（kratos 惯例：`context.WithTimeout` 包住有预算的操作，如注册中心操作、优雅停机 stopTimeout；传输层的超时随客户端构造选项配置，不放生成代码里）。
2. 停机清理动作用 `context.WithoutCancel(ctx)` 派生——请求取消不应中断回收/落库等收尾。

**MUST NOT** 拿无超时的 ctx 直通可能永久阻塞的链路（网络 IO、DB、下游 RPC）。

**为什么**：kratos App.Run/Stop 源码即此纪律——每个 server 的 Stop 都有 stopTimeout 预算，注册/反注册有 registrarTimeout，且 stopCtx 用 `context.WithoutCancel` 隔离：清理阶段只受停机预算约束、不受取消信号连坐。HTTP 与 gRPC 两套监听器流量与停止过程独立，应分别配置超时。

**源依据**：go-kratos/kratos 仓库 `app.go`（Run/Stop：WithTimeout、WithoutCancel、stopTimeout/registrarTimeout）；go-kratos.dev/zh-cn/docs/component/transport/overview/（选择传输节）；go-kratos.dev/zh-cn/docs/component/api/（实现并注册服务节：超时放生成包外）。

**违例后果**：无超时链路被下游挂死拖垮整个服务；停机时清理被取消信号打断，造成半途状态与连接泄漏。

---

## CONC-01: 多协程生命周期用 errgroup.WithContext 收口

**MUST** 一个流程内并发启动多个长驻任务（多 server、后台 worker）时，用 `errgroup.WithContext(ctx)` 派生组 ctx：每个任务一个 `eg.Go`，全部由组 ctx 联动——任一任务返回错误即触发 ctx 取消，`eg.Wait()` 收敛所有退出状态后才算流程结束。

**为什么**：kratos App.Run 即此形态：`eg, ctx := errgroup.WithContext(sctx)`，随后每个 server 的 start/stop、信号监听各占一个 `eg.Go`，`eg.Wait()` 统一等待。组 ctx 把"一个塌全塌"变成机制保证而非自觉。

**源依据**：go-kratos/kratos 仓库 `app.go` Run 方法（`errgroup.WithContext` + `eg.Go` + `eg.Wait`，导入 `golang.org/x/sync/errgroup`）。

**违例后果**：裸 `go func()` 启动的任务无人等待、错误无人接住——某个 server 崩了进程还"活着"，监控全绿但流量已丢。

---

## CONC-02: 每个协程必须监听 ctx.Done() 并及时返回

**MUST** errgroup/go routine 内的每个长驻函数都要有 `select { case <-ctx.Done(): ... return }`（或等价的取消检查）退出路径；阻塞点选择可被 ctx 取消的操作（ctx 感知的 IO/锁），确保上层取消能传导到每个协程。

**为什么**：kratos App.Run 中信号监听协程的标准写法即 `select { case <-ctx.Done(): return nil; case <-c: return a.Stop() }`——先讲取消、再讲信号。这是 goroutine 不泄漏的机制保证：ctx.Done() 是所有派生协程共同的退出信号。

**源依据**：go-kratos/kratos 仓库 `app.go` Run 方法（signal goroutine 的 select 双分支）；同文件 server stop goroutine 的 `<-ctx.Done()` 前置等待。

**违例后果**：停机挂死（k8s 强杀 → 半写状态）；取消后协程继续写已关闭的连接/文件，产生数据竞争与 panic。

---

## CONC-03: 服务端必挂 recovery 中间件，logging 置于其外层

**MUST** 服务端 middleware 链包含 `recovery.Recovery(...)` 把 panic 转换为 Kratos 错误（而非让 panic 炸掉进程）；`logging.Server(logger)` 放在 recovery **外层**，使 panic 被恢复为错误后仍出现在完成日志中。kratos 官方推荐顺序：metadata → tracing → logging → recovery → validate（按"后续链路依赖什么数据/要观察什么失败"排布，无万能固定序）。

**MUST NOT** 只依赖进程级 panic 兜底；写中间件时禁止多次调用 `next`（除非主动拒绝请求）。

**为什么**：Go 的 panic 若无 recover 会终结整个进程，一个坏请求放倒全部流量；logging 在 recovery 外层才能既记录到 panic 恢复后的错误又不丢请求完成日志。kratos 中间件签名 `func(ctx, any) (any, error)` 让 panic→error 成为可组合的一环。

**源依据**：go-kratos.dev/zh-cn/docs/component/middleware/overview/（执行顺序、可用中间件、编写中间件节：recovery "把 panic 转换为 Kratos 错误"、"日志包在恢复中间件外层"）。

**违例后果**：单请求 panic 带崩整个服务；panic 请求无完成日志，排障盲区。
