> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# API 设计约束

> 涵盖 REST 接口规范（API-01~20，其中 API-15 已废止）和 RPC 规范（RPC-01~06）。

---

## REST 设计

### API-01: URL 模式

**MUST** 遵循 RESTful URL 格式：

```
POST   /api/v1/{resource-plural}                            # 创建
GET    /api/v1/{resource-plural}/{id}                       # 查询
POST   /api/v1/{resource-plural}/{id}/actions/{action}      # 操作
```

示例（支付场景）：

```
POST   /api/v1/pay-orders                                       # 创建支付单
GET    /api/v1/pay-orders/{payOrderNo}                           # 查询支付单
POST   /api/v1/pay-orders/{payOrderNo}/actions/refund             # 发起退款
POST   /api/v1/pre-auth-orders                                    # 创建预授权单
POST   /api/v1/pre-auth-orders/{preAuthOrderNo}/actions/capture    # 请款
```

### API-02: 统一响应包装

**MUST** 所有接口返回 `ApiResponse<T>` 统一包装：

```json
{ "code": "00000", "message": "success", "data": { ... } }
```

### API-02b: 返回码按「调用处置」分 5 类，且错误码 ≠ 实体状态

**MUST** `ResultCode` 按**本次调用的处置**分为 5 大类（5 位数字，段前缀即大类，供程序化处理；段内具体码供业务分支/可观测/i18n）：

| 段 | 大类 | 调用方动作 | 例 |
|---|---|---|---|
| 0xxxx | 成功 | 继续（实体处于何态由响应的 status 数据带出） | SUCCESS |
| 1xxxx | 参数/请求非法（**含认证/授权**：凭证无效/无权即请求不合法） | 改请求，别原样重试 | INVALID_ARGUMENT、INVALID_AMOUNT、UNAUTHORIZED |
| 2xxxx | 业务规则拒绝（**含资源未找到**） | 按具体码分支（多为终态） | ORDER_ALREADY_EXISTS、NOT_PAYABLE、INSUFFICIENT_BALANCE、REFUND_AMOUNT_EXCEEDED、ORDER_NOT_FOUND |
| 4xxxx | 系统/依赖故障（DB、下游/渠道调用失败、超时、锁争用；**含可重试**） | 视具体码重试/稍后重试 | CHANNEL_SERVICE_ERROR、DATA_VERSION_CONFLICT、SYSTEM_BUSY |
| 9xxxx | 系统异常兜底（无法归类） | 记录 + 告警 | UNSUPPORTED_RESULT_TYPE、SYSTEM_ERROR |

**分类唯一标准**：调用方能据此做什么不同的动作（改参数 / 按业务分支 / 重试 / 转人工）。两个错误动作相同才可合并，不同必须能区分。

**MUST NOT 把实体状态塞进错误码**。错误码只描述"这次调用的处置"，**不表达业务实体的状态**：

- "处理中 / 结果未知 / 待确认"等是**订单状态**（状态机的非终态，如 `PAYING`），作为 `status` **数据**随 **`SUCCESS`** 响应返回；调用方读 status 决定"转查询/对账"。
- 例：渠道超时、未拿到确认结果 → 订单停在 `PAYING`（状态）→ API 返回 `SUCCESS` + status=PAYING（数据）→ 调用方转查询。**全程不产生"未知"错误码**；"防盲目重试"靠"订单停在非终态"这一状态语义，不靠错误码。
- 反例（MUST NOT）：定义 `RESULT_UNKNOWN` / `PROCESSING` 之类的**错误码**——那是状态，不是调用处置。

> 关联：4xxxx 内"可重试(SYSTEM_BUSY/超时/锁争用)"仍是**错误码**（描述这次调用怎么失败的），与"实体状态"是两回事，勿混。异常翻译映射见 [`persistence.md`](persistence.md) PS-18。

### API-03: Controller 位置 & 职责

**MUST** REST Controller **仅当系统提供 REST 接口时才建**，且**位于 `{system}-adapter/controller/` 子包**（不是 app 层）。纯 RPC 微服务无需 REST Controller。位置规则见 [`architecture.md`](architecture.md) ARCH-16。

**MUST** Controller 只做三件事：参数校验+转换（`{Biz}ControllerConverter`，位于 `adapter/controller/{biz}/converter/`）→ 调用 AppService → 响应转换。

**MUST NOT** 在 Controller 中编写业务逻辑、事务控制、状态判断、查库、调渠道。

```java
/** 支付单 REST Controller（trade-adapter/controller/payment/）：仅做协调，不含业务逻辑。 */
@RestController
@RequestMapping("/api/v1/pay-orders")
public class PayOrderController {

    @Autowired
    private PaymentAppService paymentAppService;
    @Autowired
    private PayOrderControllerConverter controllerConverter;   // adapter/controller/payment/converter/

    @PostMapping
    public ApiResponse<PayOrderResponse> createPayOrder(@RequestBody @Valid CreatePayOrderRequest request) {
        CreatePayOrderCommand command = controllerConverter.toCommand(request);
        PayOrderResult result = paymentAppService.pay(command);
        return ApiResponse.success(controllerConverter.toResponse(result));
    }
}
```

> **Request DTO 校验**：`@Valid` 触发 JSR 380 注解校验（`@NotNull`/`@NotBlank`/`@Size`/`@Pattern`/`@DecimalMin` 等），Controller 内**不得**手工 if-throw 做字段格式/必传校验。详见 CS-16。

---

## 幂等性

### API-04: 创建端点必须幂等

**MUST** 所有创建端点支持幂等性。幂等键模式：`merchantId + externalOrderNo`（或同类业务唯一组合）。

### API-05: 幂等返回

**MUST** 重复请求返回已有结果或错误码（如 `PAY_ORDER_ALREADY_EXISTS`），不创建新记录。

---

## 返回码

### API-06: 三级返回码映射

**MUST** 实施三级返回码体系：

```
商户/用户 API 返回码 ← 平台内部标准码 ← 渠道/外部系统返回码
   （对外展示）           （内部流转）        （外部系统）
```

### API-07: 内部标准码格式

**MUST** 内部返回码格式：`RS + 子系统(3位) + 错误级别(1位) + 具体码(3位)`

```
RS2010000  →  Trade（支付域） + 正常 + 成功
RS2011101  →  Trade + 业务异常 + 渠道余额不足
RS2011102  →  Trade + 业务异常 + 订单已存在（幂等）
RS2012999  →  Trade + 系统异常 + 未知错误
```

### API-08: 映射铁律

**MUST** 只有明确成功 → 推成功。**MUST** 只有明确失败 → 推失败。**MUST** 其余一律视为"未知"，走补偿机制（查询/对账）。

### API-09: 敏感信息脱敏

**MUST** 对外返回码不暴露内部实现细节（不暴露表名、SQL 异常、堆栈信息）。**SHOULD** 非敏感错误尽量精确，帮助接入方定位问题。

### API-10: 渠道交互双层判断（接口层 vs 业务层，接口失败禁当业务失败）

**MUST** 所有渠道交互（查询、支付、退款等）区分**接口层**与**业务层**两个维度，结果载体两轴表达，MUST NOT 压成一个 `resultType`：

- **接口层** `boolean success`：渠道调用本身是否拿到业务应答（false=超时/网络等通信失败）。由 infra 网关实现（技术判断）回填。
- **业务层** `BizResult`（`SUCCESS`/`FAILURE`/`UNKNOWN`）：接口成功后的业务结果分类。由渠道返回码经映射服务翻译产出（见 [`integration.md`](integration.md) INT-10b）。

**资损红线（MUST）**：`success=false ⇒ 业务未知`，MUST NOT 读成业务失败；业务判定器一律先与 `success` 与运算（`isBusinessFailure = success && FAILURE`）。领域侧遇**接口失败或 `UNKNOWN`** → **停在非终态**（如 PAYING）交查询/对账，MUST NOT 推进到 FAILED——把"接口没通/结果未定"当"业务失败"会把实际可能成功的交易误标失败，漏单/资损。`UNKNOWN`（受理中/拿不准）是**状态**语义、不是错误码（见 API-02b）。

---

## 参数校验

> **分层原则**：
> - **入口层（Controller / RPC Impl）**：字段格式、必传、长度、范围等"技术型"校验 → 用 JSR 380 注解声明；**HTTP Controller** 由 `@RequestBody @Valid` 自动触发，**RPC Facade** 由 `FacadeTemplate` 程序化触发（RPC 不自动跑校验，见 API-11）
> - **领域层（DomainService / DomainModel）**：业务规则、状态一致性、领域不变量 → 用 `FinAssert`

### API-11: Request DTO 声明式校验（入口层）

**MUST** 所有 Request DTO 字段使用 JSR 380 注解声明格式/必传约束。

**触发方式按入口类型区分（关键，易踩坑）**：
- **HTTP Controller**：`@RequestBody @Valid` 由 Spring MVC 在入口自动触发校验。
- **RPC Facade（RPC）**：`@Valid` 标在 Impl 方法参数上**不会自动生效**——RPC 反序列化只填充对象、不跑 `Validator`，且其参数校验 filter 默认关闭。**MUST** 由 `FacadeTemplate` 在 provider 侧**程序化**执行 Bean Validation（见 API-13b），不依赖 RPC 框架的校验开关；否则 `@NotBlank/@Size` 等只是装饰、静默放过。

```java
// client.payment.dto.request.CreatePayOrderRequest
@Data
public class CreatePayOrderRequest implements Serializable {

    /** 请求来源（调用方系统/渠道/端标识，见 API-17） */
    @NotBlank
    @Size(max = 32)
    private String source;

    @NotBlank
    @Size(max = 64)
    private String merchantId;

    @NotBlank
    @Pattern(regexp = "^[A-Za-z0-9_-]{1,64}$")
    private String externalOrderNo;

    /** 金额：成对封装进 MoneyDTO（amount + currency），见 DM-18 */
    @NotNull
    @Valid
    private MoneyDTO amount;
}
```

**MUST NOT** 在 Controller / RPC Impl 中手工 if-throw 或 `FinAssert` 做字段格式/必传校验（该由注解声明）。

### API-17: Facade Request MUST 携带 source（请求来源）

**MUST** 所有 facade 定义的 Request DTO（业务操作类 + `Query*` / `Close*` 等一切请求）携带一个 `source` 字段，标识**请求来源**（调用方系统 / 渠道 / 端），用于审计、路由、风控、限流、对账时区分来源。

- 类型 `String`，`@NotBlank`（必传）；建议 `@Size` 限长，来源合法性可在后端进一步校验。
- 位置：`{system}-client` 下所有 `*Request`。

```java
public class PaymentRequest implements Serializable {
    /** 请求来源（调用方系统/渠道/端标识） */
    @NotBlank
    @Size(max = 32)
    private String source;
    // ... 其它业务字段
}
```

### API-12: 领域层业务规则校验

**MUST** 业务规则校验（金额正负、状态合法性、幂等检查等）在 DomainService / DomainModel 中用 `FinAssert` 表达：

```java
FinAssert.isTrue(command.getAmount().isPositive(),
        ResultCode.PARAM_ERROR, "Amount must be positive");
FinAssert.isTrue(payOrder.canRefund(),
        ResultCode.INVALID_STATUS, "Pay order is not refundable");
```

### API-13: 商户业务有效性校验

**MUST** 通过 `MerchantGateway` 验证商户业务有效性后才能执行业务操作（在 PREPARE 阶段，事务外）。

### API-13a: 统一异常处理

**MUST** 在 `start` 模块配置全局异常处理器，将 `MethodArgumentNotValidException` / `ConstraintViolationException` 映射为 `ApiResponse.fail(ResultCode.PARAM_ERROR, ...)`，避免 400 裸异常暴露。

### API-13b: Facade 用模板方法统一捕获业务异常 → ApiResponse

**MUST** Facade 返回 `ApiResponse<T>`（API-02）。**MUST** FacadeImpl 通过**统一的模板方法**包裹对 AppService 的调用：成功 → `ApiResponse.success(data)`；捕获业务异常 `FinException` → `ApiResponse.fail(按其 code/message)`；兜底其它异常 → 系统错误码。**MUST NOT** 让业务异常裸抛给上游，也 **MUST NOT** 每个 Facade 方法各写一遍 try/catch。

这是 AppService 侧「断言抛业务异常」（如幂等命中抛 `ORDER_ALREADY_EXISTS`，见 [`persistence.md`](persistence.md) PS-15）在**边界的收口**：AppService 只管抛明确的业务异常，Facade 模板统一把异常翻译成一个**明确的失败 Response**（含 code + message）返回上游——上游据此判定「重复交易 / 参数错误 / 业务失败」，而不是收到一个冒充成功的旧数据。

模板还**集中承担 RPC 入口的程序化 Bean Validation**（见 API-11：RPC 下 `@Valid` 不自动触发）。带 `request` 的重载先校验、违规聚合成一条 `INVALID_ARGUMENT`，再执行业务。校验器用 hibernate-validator 的 `ParameterMessageInterpolator`（不引 Jakarta EL），跑在 provider 侧、不依赖 RPC 校验开关。

```java
// app 层：统一的 Facade 执行模板（集中一处：入参校验 + 异常收口，避免每个方法重复 try/catch）
@Component
public class FacadeTemplate {
    private static final Logger log = LoggerFactory.getLogger(FacadeTemplate.class);

    // 独立构建校验器：ParameterMessageInterpolator 不引 EL，对 @NotBlank/@Size 默认消息足够
    private static final Validator VALIDATOR = Validation.byDefaultProvider().configure()
            .messageInterpolator(new ParameterMessageInterpolator())
            .buildValidatorFactory().getValidator();

    /** 带入参校验的重载：校验放进下方 try 内，违规抛的 FinException 经既有 catch 统一转失败响应（不裸抛出 facade） */
    public <T> ApiResponse<T> execute(Object request, Supplier<T> bizCall) {
        return execute(() -> {
            Set<ConstraintViolation<Object>> violations = VALIDATOR.validate(request);
            if (!violations.isEmpty()) {
                String detail = violations.stream()
                        .map(v -> v.getPropertyPath() + " " + v.getMessage())
                        .collect(Collectors.joining("; "));   // 违规聚合成一条
                throw new FinException(ResultCode.INVALID_ARGUMENT, detail);
            }
            return bizCall.get();
        });
    }

    public <T> ApiResponse<T> execute(Supplier<T> bizCall) {   // 无入参校验，供查询等无请求体场景
        try {
            return ApiResponse.success(bizCall.get());
        } catch (FinException e) {
            log.warn("Business exception: code={}, msg={}", e.getCode(), e.getMessage());
            return ApiResponse.of(e.getCode(), e.getMessage(), null);   // 明确的失败 Response
        } catch (Exception e) {
            log.error("Unexpected error", e);
            return ApiResponse.fail(ResultCode.SYSTEM_ERROR);
        }
    }
}

// FacadeImpl：薄层，方法体只有一行模板调用（带 request 触发校验）
@Override
@ApiLog(description = "RPC-支付")
public ApiResponse<PaymentResponse> pay(PaymentRequest request) {
    return facadeTemplate.execute(request, () ->
            facadeConverter.toResponse(paymentAppService.pay(facadeConverter.toCommand(request))));
}
```

> 与 API-13a 的分工：**API-13a** 处理 **HTTP `start` 模块**的入口校验异常（Spring MVC `@Valid` → `MethodArgumentNotValidException` / REST 400 映射）；**API-13b 的 `FacadeTemplate`** 在 **RPC Facade** 侧程序化跑 Bean Validation（RPC 不自动触发）**并**统一收口业务异常 `FinException` → `ApiResponse`。两条入口都不让裸异常/静默放过穿透到上游。
>
> **依赖**：`FacadeTemplate` 所在模块 MUST 引 `org.hibernate.validator:hibernate-validator`（Bean Validation 实现；仅有 `jakarta.validation-api` 不够，`validate()` 会 `NoProviderFoundException`）。用 `ParameterMessageInterpolator` 则无需 Jakarta EL。

---

## 日志

> 四层日志标准（接口摘要 / 业务摘要 / 详细日志 / 系统异常）及框架能力边界见 [`observability.md`](../../conventions/observability.md) §1。

### API-14: 接口日志注解

**MUST** 所有 Controller 方法和 RPC 服务方法使用 `@ApiLog(description = "...")` 注解。

### API-16: 业务摘要日志在应用层排空领域事件时输出

**MUST** 业务摘要日志（四层标准的层②，见 [`observability.md`](../../conventions/observability.md) §1.4）在**应用层排空领域事件时**输出：聚合的状态机每次转移无条件 raise 状态转移事件，应用层排空事件时打摘要日志。**MUST NOT** 用"聚合根使用 `@{Module}BizLog` 注解 + `bizLogger.info(this)`"的方案——该注解与 `bizLogger` 从未落地实现，且把日志格式化职责放进聚合根会违反 API-19（领域层不得依赖日志框架）。

### API-18: 禁止新建 `log4j2.component.properties`

**MUST NOT** 业务方新建 `log4j2.component.properties`。这是 classpath 级全局单一语义文件，`app-log` 靠它注册 `log4j2.contextDataInjector`；业务方打一份同名文件会覆盖它，导致 `JLOG_*` 等一整批 MDC 字段全部消失。详见 [`observability.md`](../../conventions/observability.md) §1.5.3。

### API-19: 领域层不得依赖日志框架

**MUST NOT** 领域层（`domain` 模块）依赖 `org.slf4j` / `org.apache.logging.log4j` 等日志框架。领域层拿不到追踪 ID、环境标等线程环境态字段，把日志格式化逻辑搬进领域层会让纯函数变成带隐藏依赖的函数，且领域层单元测试会静默产出半空的日志行。对应 ArchUnit 约束见 [`archunit-rules.md`](../../feedback/java-app/archunit/archunit-rules.md)。

### API-20: 摘要日志字段必须经统一规整

**MUST** 层①接口摘要 / 层②业务摘要 / 层④系统异常的字段值在拼接前统一规整：空值补 `-`；换行压成空格；值中的逗号 `,` 与方括号 `[` `]` 必须替换（渠道返回描述属外部不可控文本）。详见 [`observability.md`](../../conventions/observability.md) §1.4。

---

## RPC 规范

### RPC-01: Facade 接口定义在 client 模块

**MUST** RPC 服务对外契约接口（**Facade**）定义在 `{system}-client` 模块 `facade/` 子包，作为独立 JAR 对外发布，供消费方依赖。全景样例见 [`reference-implementation.md`](reference-implementation.md)。

```
{system}-client/
└── src/main/java/com/company/{system}/client/
    ├── facade/
    │   ├── TradePaymentFacade.java   # RPC 接口（MUST 在 client）
    │   └── TradeRefundFacade.java
    ├── payment/{request,response}/
    └── refund/{request,response}/
```

```java
/** 支付 RPC Facade 接口：供内部微服务通过 RPC 调用。 */
public interface TradePaymentFacade {
    PaymentResponse pay(PaymentRequest request);
    ForwardPayResponse forwardPay(ForwardPayRequest request);
    QueryPaymentResponse queryPayment(QueryPaymentRequest request);
}
```

**MUST** RPC 接口命名使用 `{Biz}Facade` 后缀（不是 `{Biz}Service` / `{Biz}RpcService`）。

```java
// 正确
public interface TradePaymentFacade { ... }
// 错误
public interface TradePaymentService { ... }    // ❌ Service 语义不清
public interface TradePayRpcService { ... }     // ❌ 不带 Facade 后缀
```

### RPC-02: FacadeImpl 提供方使用 @BootService + @BootServiceBinding

**MUST** Facade 实现（`{Biz}FacadeImpl`）位于 **`{system}-app/{biz}/facade/impl/`**，使用 `@BootService` 注册 RPC 服务，`@BootServiceBinding` 配置别名和分组。

```java
/** 支付 Facade 实现（trade-app/payment/facade/impl/）：薄层，转换入参→调用 AppService→转换出参。 */
@BootService
@BootServiceBinding(alias = "tradePaymentFacade", group = "trade")
public class TradePaymentFacadeImpl implements TradePaymentFacade {

    @Autowired
    private PaymentAppService paymentAppService;
    @Autowired
    private PaymentFacadeConverter facadeConverter;   // trade-app/payment/converter/

    @Override
    @ApiLog(description = "RPC-支付")
    public PaymentResponse pay(PaymentRequest request) {
        PaymentCommand command = facadeConverter.toCommand(request);
        PaymentResult result = paymentAppService.pay(command);
        return facadeConverter.toResponse(result);
    }
}
```

**关键约定**：FacadeImpl **调 AppService，不直接调 DomainService**（AppService 负责事务、幂等、调渠道等编排）；FacadeConverter 位于 app 层。

### RPC-03: 服务消费方使用 @BootReference + @BootReferenceBinding

**MUST** RPC 服务消费方使用 `@BootReference` 注入远程服务，`@BootReferenceBinding` 配置别名和分组。

```java
/** 渠道余额查询 Gateway 实现：通过 RPC 调用渠道域服务。 */
@Component
public class ChannelBalanceGatewayImpl implements ChannelBalanceGateway {

    @BootReference
    @BootReferenceBinding(alias = "channelBalanceService", group = "channel")
    private ChannelBalanceService channelBalanceService;

    @Override
    public ChannelResult queryBalance(String merchantId, Money amount) {
        BalanceQueryRequest request = new BalanceQueryRequest();
        request.setMerchantId(merchantId);
        request.setAmount(amount.getValue());
        request.setCurrency(amount.getCurrency());
        ApiResponse<BalanceQueryResult> resp = channelBalanceService.queryBalance(request);
        FinAssert.isTrue(resp.isSuccess(),
                ResultCode.CHANNEL_SERVICE_ERROR, "Balance query failed: " + resp.getMessage());
        return convertToChannelResult(resp.getData());
    }
}
```

### RPC-04: Alias 命名规范

**MUST** RPC 服务别名（alias）使用小驼峰格式，全局唯一，格式：`{业务域}{功能}Facade`（Facade 后缀与 client 层命名对齐）。

| 正确 | 错误 |
|------|------|
| `tradePaymentFacade` | `TradePaymentFacade`（大写开头） |
| `tradeRefundFacade` | `trade-refund-rpc-facade`（中划线） |
| `channelBalanceFacade` | `balanceFacade`（不够具体） |

### RPC-05: 健康检查

**SHOULD** 核心 FacadeImpl 实现 `HealthChecker` 接口，提供健康状态检测。

```java
@BootService
@BootServiceBinding(alias = "tradePaymentFacade", group = "trade")
public class TradePaymentFacadeImpl implements TradePaymentFacade, HealthChecker {
    @Override
    public boolean isHealthy() {
        return payOrderRepository.ping(); // 检查依赖（DB 连接、关键 Gateway 可用性）
    }
}
```

### RPC-06: 服务注册

**MUST** 使用 Registry 进行服务注册与发现，禁止硬编码服务地址。

```yaml
# AppBoot 配置（application.yml）
app:
  registry:
    address: rpcregistry.example.com:9090
    protocol: rpc
  service:
    group: trade
    alias: tradePaymentFacade
```

**MUST NOT** 在代码或配置中硬编码 IP 地址访问 RPC 服务。

---

## MQ 生产者契约

> 内部消息中间件 MQ 的生产者 API（AppBoot 2.1.2，mq-client-spring 2.3.9-BOOT-6）。以下 FQN 均以 `.m2` 中 jar 的 `javap` 为准，**MUST NOT** 臆造包名或类名。异步外发型场景（订单结果事件、状态变更通知）的 MQ Gateway 实现 MUST 依据本契约编写。

### MQ-01: 生产者注入注解

**MUST** 使用 `com.company.mq.client.springboot.annotation.@MqProducer` 注入生产者。该注解唯一成员为 `String name()`，标注在 `com.company.mq.client.producer.MessageProducer` 类型的字段上；`name` 指向 `application.yml` 中的 producer 配置项。

```java
@MqProducer(name = "payOrderResultProducer")
private MessageProducer payOrderResultProducer;
```

### MQ-02: 单条同步发送

**MUST** 通过 `MessageProducer.send(Message)` 单条同步发送。方法签名：

```java
void com.company.mq.client.producer.MessageProducer.send(com.company.mq.common.message.Message) throws com.company.mq.common.exception.MQException;
```

`MQException` 为受检异常，MUST 捕获后封装为领域异常（如 `FinException`）向上抛出，附带 topic 等定位信息。

### MQ-03: 消息构造

**MUST** 使用 `com.company.mq.common.message.Message` 构造消息，`text` 放业务 JSON 正文：

```
new com.company.mq.common.message.Message(String topic, String text);
new com.company.mq.common.message.Message(String topic, String text, String businessId);
```

可用 setter：`setText(String)` / `setBusinessId(String)` / `setApp(String)`。业务 topic 作为常量声明在 Gateway 实现内。

### MQ-04: 事务提交后发送不可变快照

**MUST** MQ 外发在**本地事务提交之后**执行（把发送放在事务块返回之后顺序执行，无需 afterCommit 回调），且发送的是 converter 转出的**不可变结果快照**（如 `PaymentResult`）而非领域模型引用，避免发送前聚合根被后续代码修改而污染消息内容。

### MQ 示例：Gateway 实现

```java
@Component
public class PayOrderMqGatewayImpl implements PayOrderMqGateway {

    private static final String TOPIC = "trade_pay_order_result";

    @MqProducer(name = "payOrderResultProducer")
    private MessageProducer payOrderResultProducer;

    @Override
    public void sendPayResultEvent(PaymentResult paymentResult) {
        PayOrderResultMessage msg = new PayOrderResultMessage();
        msg.setPayOrderNo(paymentResult.getPayOrderNo());
        msg.setStatus(paymentResult.getStatus());
        msg.setChannelPayNo(paymentResult.getChannelPayNo());
        msg.setTimestamp(System.currentTimeMillis());

        // text 放业务 JSON 正文；send 抛受检 MQException，封装为领域异常
        Message message = new Message(TOPIC, JsonUtils.toJson(msg));
        try {
            payOrderResultProducer.send(message);
        } catch (MQException e) {
            throw new FinException(CommonResultCode.SYSTEM_ERROR,
                    "send MQ message failed, topic=" + TOPIC, e);
        }
    }
}
```

对应 `application.yml` 中的 producer 配置（别名与 `@MqProducer(name=...)` 对齐）：

```yaml
mq:
  producers:
    - name: payOrderResultProducer
      topic: trade_pay_order_result
```
