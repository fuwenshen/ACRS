> 【ACRS 资产 · curated】提炼自 go-kratos（GitHub go-kratos/kratos main 分支 + go-kratos.dev 官方文档，2026-09-21）。提炼工程思想非代码，许可纪律见 [README.md](README.md)。约束力降档：curated 资产为强参考，与项目实际冲突时项目定义优先。

# LAY + DI 族 —— 包布局分层与依赖注入边界

> 覆盖：kratos 项目布局（api/cmd/internal 四层）、依赖方向铁律、wire 编译期注入。核心思想来自 kratos 项目模板与官方布局文档。

---

## LAY-01: 遵循 kratos 四层布局，api/ 为公开契约、实现全部内藏 internal/

**MUST** 服务按 kratos 模板布局组织：

```
api/<domain>/<version>/    # proto 源 + 生成 stub，公开契约（如 api/todo/v1/）
cmd/<app>/                # 入口 main.go + wire injector
internal/conf/            # 配置 proto 与生成绑定
internal/server/          # HTTP/gRPC server 构造与注册
internal/service/          # transport 适配层（每资源一文件）
internal/biz/             # 领域对象、usecase、仓储接口、业务错误
internal/data/            # 仓储实现与存储 client
```

应用实现类型一律留在 `internal/` 下，客户端只 import 版本化 API 包。所有 `*.pb.go`、`*_grpc.pb.go`、`*_http.pb.go` 均为生成产物——要改就改 proto 源后重新生成（`make api` / `make all`），生成文件与源一同提交；传输构造、TLS、服务发现、中间件、超时等手工逻辑放在生成包之外。

**MUST NOT** 把实现代码放进 api/ 或公开 export 给外部 import；**MUST NOT** 手工编辑任何生成文件。

**为什么**：api/ 是对外契约的单一来源（proto 优先），internal/ 由 Go 编译器强制不可外部引用——这是框架级的封装保证；配置 proto 独立成模块（internal/conf）与业务契约分离。生成物提交入库保证不装 protoc 也能构建，CI 干净重新生成的 diff 检查能抓住"源改了忘重新生成"的漂移；手改会在下次生成时被静默覆盖。

**源依据**：go-kratos.dev/zh-cn/docs/intro/layout/（目录节："\*.pb.go、wire_gen.go 均为生成产物……而不是手动编辑生成文件"、"客户端只导入版本化 API 包"）；go-kratos.dev/zh-cn/docs/component/api/（生成产物节：生成文件与 proto 一同提交、不要手工编辑）。

**违例后果**：外部直接依赖实现包 → 重构即破坏兼容；api 目录混入实现后契约与代码互相污染。

---

## LAY-02: 分层依赖方向单向——biz 不依赖 data，service 不碰存储

**MUST** 依赖方向严格单向：

- `service`：transport 边界的 DTO 转换 + 调 usecase；可 import `api/...` 与 `biz`，**禁止 import `data` 或存储 client**
- `biz`：领域对象、usecase、业务错误、**仓储接口**（接口定义在此层）；不依赖 service 也不依赖 data
- `data`：实现 biz 的仓储接口，持有 PO 与存储 client，负责 DO/PO 转换；**禁止 import API DTO 或 service**
- `cmd`：通过 wire 组合各层；`server` 只构造 transport 并注册，不处理 transport 转换或业务规则

数据模型链：client → (DTO) → service → (DO) → biz → (DO) → data → (PO) → storage。

**为什么**：依赖倒置让"换存储"与"换传输"都能局部测试——biz 定义接口、data 实现，存储与 transport 的变化不会扩散到应用各层。

**源依据**：go-kratos.dev/zh-cn/docs/intro/layout/（分层边界节：service/biz/data/cmd 四段职责与 import 限制）。

**违例后果**：service 直连 data 后，换缓存/换库要改 transport 层；biz 依赖 data 后领域逻辑被存储细节绑架，单测必起真实存储。

---

## DI-01: 依赖注入走 wire 编译期生成，每层一个小 ProviderSet

**MUST**：
1. 组装用 Google Wire（编译期代码生成，非运行时反射）：每层导出一个小 `ProviderSet = wire.NewSet(...)`，set 靠近它暴露的构造函数。
2. injector 声明放 `cmd/<app>/wire.go`（仅 `wireinject` 构建标签下编译），panic(wire.Build(...)) 是声明不是运行时代码；产物 `wire_gen.go` 提交入库。
3. 构造函数经参数与返回值声明依赖；可失败返回 `(value, error)`；持有长生命周期资源（DB client）返回 `(value, cleanup, error)`；main 中构造成功后 `defer cleanup()`。
4. data 层构造函数返回**业务仓储接口**（而非具体结构体）；构造失败返回错误，**禁止在构造函数里 panic**。

**MUST NOT** 手写全局单例/可变全局状态代替注入；MUST NOT 通过 provider set 暗中创建可变全局状态。

**为什么**：wire 在编译期把"缺依赖/多依赖/依赖环"（No provider found / Multiple providers / Initialization cycle）变成生成期报错而非运行期意外；cleanup 组合保证资源按构造逆序释放，且能安全处理部分初始化。Kratos 运行时不依赖 wire，生成的是普通 Go 代码，可断点可读。

**源依据**：go-kratos.dev/zh-cn/docs/guide/wire/（按层组织 provider set、定义 injector、生成 injector、在 main 中管理清理、排查生成错误各节）。

**违例后果**：手写单例引入隐式全局状态，测试无法隔离；构造函数 panic 让已初始化的资源（连接池、监听器）泄漏；依赖环在运行时才炸。
