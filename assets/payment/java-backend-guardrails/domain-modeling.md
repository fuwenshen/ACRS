> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 领域建模约束

---

## 聚合根

### DM-01: 聚合根的合法行为边界

**MUST** 聚合根（DomainModel）暴露的 public 方法**仅限**以下几类：

| 类别 | 示例 | 副作用 |
|---|---|---|
| **工厂方法** | `create(Command)` / `restore(PO)` | 初始化（含 `INIT` 状态） |
| **状态推进唯一入口** | `transferStatusByEvent(Event)` | 经状态机校验后推进 status + 维护 previousStatus / statusChangedAt / finalStatusAt |
| **无副作用判断方法** | `isOverdue()` / `canRefund()` | 无 |
| **无副作用计算方法** | `getRefundableAmount()` | 无 |
| **业务字段 getter** | `getAmount()` / `getRefundedAmount()` | 无 |
| **业务字段 setter（必要时）** | `setRefundedAmount(Money)` / `setChannelAuthToken(String)` | 仅更新单个业务字段，**不**推进状态 |

**MUST NOT** 聚合根暴露"业务包装方法"——任何内部会调用 `transferStatusByEvent` 的 public 方法。详见 [DM-21](#dm-21-聚合根仅暴露-transferstatusbyevent-推进状态must-not-业务包装方法)。

```java
/** 支付单聚合根：管理支付单的完整生命周期：创建、支付、退款、关闭。 */
public class PayOrder extends BaseDomainModel<PayOrderStatus, PayOrderEvent> {

    /** 是否可以退款（无副作用判断 ✅） */
    public boolean canRefund() {
        return getCurrentStatus() == PayOrderStatus.PAID
                && refundedAmount.lessThan(amount);
    }

    /** 计算可退金额（无副作用计算 ✅） */
    public Money getRefundableAmount() {
        return amount.subtract(refundedAmount);
    }

    /** 业务字段 setter（仅更新字段，不推进状态 ✅） */
    public void setRefundedAmount(Money refundedAmount) {
        this.refundedAmount = refundedAmount;
    }

    // ❌ MUST NOT：暴露 recordPaySuccess(...) / close() / refund() 等业务包装方法——
    //              它们内部调用 transferStatusByEvent，等同于让外部绕过状态机校验（见 DM-21）。
    //              状态推进 MUST 由 DomainService 直接调 payOrder.transferStatusByEvent(EVENT) 完成。
}
```

### DM-02: 扁平化结构

**SHOULD** 聚合根采用扁平化字段结构，所有字段在顶层，不做深层嵌套。

---

## 状态机

> **写状态机代码前必读**：[`scaffolds/java-app/state-machine-template.md`](../../scaffolds/java-app/state-machine-template.md) 含基础包说明、5 步骨架、4 种订单类型（PayOrder/PreAuthOrder/CaptureOrder/RefundOrder）样板、并发控制、自检清单。本节只定义规则，模板里有可直接复制的代码。
>
> **基础包**：`com.company.fin.share.kernel.statemachine` 已提供 `BaseStatus` / `BaseEvent` / `StateMachine<S,E>` / `StatusEventPair<S,E>` / `StateMachineException`。**MUST NOT** 业务侧重新实现这 5 个类。

### DM-03: 状态机实现标准

**MUST** 状态枚举实现 `BaseStatus`，事件枚举实现 `BaseEvent`，使用 `StateMachine<Status, Event>` 管理转换。

```java
public enum PayOrderStatus implements BaseStatus {
    INIT("INIT", false, "初始化"),
    PAYING("PAYING", false, "支付中"),
    PAID("PAID", true, "支付成功"),
    FAILED("FAILED", true, "支付失败"),
    CLOSED("CLOSED", true, "已关闭");

    private static final StateMachine<PayOrderStatus, PayOrderEvent> STATE_MACHINE = new StateMachine<>();
    static {
        STATE_MACHINE.accept(null,   PayOrderEvent.CREATE,       INIT);
        STATE_MACHINE.accept(INIT,   PayOrderEvent.SUBMIT,       PAYING);
        STATE_MACHINE.accept(PAYING, PayOrderEvent.PAY_SUCCESS,  PAID);
        STATE_MACHINE.accept(PAYING, PayOrderEvent.PAY_FAIL,     FAILED);
        STATE_MACHINE.accept(PAYING, PayOrderEvent.CANCEL,       CLOSED);
        STATE_MACHINE.accept(PAYING, PayOrderEvent.TIMEOUT,      CLOSED);
    }
}
```

### DM-04: 禁止直接 setStatus

**MUST NOT** 使用 `setCurrentStatus()` 直接修改状态。**MUST** 通过 `transferStatusByEvent(event)` 事件驱动推进。

```java
// 错误
payOrder.setCurrentStatus(PayOrderStatus.PAID);
// 正确
payOrder.transferStatusByEvent(PayOrderEvent.PAY_SUCCESS);
```

### DM-05: 禁止 if-else 推进状态

**MUST NOT** 用 if-else / switch-case 判断状态转换目标。状态转换逻辑必须在 `StateMachine.accept()` 中声明式定义。

```java
// 错误：服务层用条件分支决定目标状态
if (channelResult.isSuccess()) {
    payOrder.setCurrentStatus(PayOrderStatus.PAID);
} else {
    payOrder.setCurrentStatus(PayOrderStatus.FAILED);
}

// 正确：映射事件，由状态机决定目标状态
PayOrderEvent event = channelResult.isSuccess() ? PayOrderEvent.PAY_SUCCESS : PayOrderEvent.PAY_FAIL;
payOrder.transferStatusByEvent(event);
```

### DM-06: 状态流转是模型行为

**MUST NOT** 在领域服务层直接修改模型状态字段。状态流转由模型自身的 `transferStatusByEvent()` 方法驱动，服务层只负责决策事件。

### DM-07: 终态标记

**MUST** 终态（PAID/FAILED/CLOSED 等）的 `isFinalStatus` 设为 `true`。到达终态时记录 `finalStatusAt`。

### DM-08: 单据独立状态机

**MUST** 每种业务类型维护独立状态机，禁止混用。4 个支付聚合各自独立管理状态：`PayOrderStatus/Event`（扣款单）、`PreAuthOrderStatus/Event`（授权单，含 AUTHED/CAPTURING）、`CaptureOrderStatus/Event`（请款单）、`RefundOrderStatus/Event`（退款单，含 PREPARE_SUCC）。

```java
// 错误：把预授权 / 请款状态塞进支付单
public enum PayOrderStatus implements BaseStatus {
    INIT, PAYING, PAID, AUTHORIZED, CLOSED;   // AUTHORIZED 属于预授权单，不应在此
}
```

### DM-08b: Event 枚举保持纯标识

**MUST NOT** 在 Event 枚举中持有渠道结果映射 Map 或 `fromChannelResult` 之类静态翻译方法。渠道结果 → 领域事件的翻译属于 **gateway / app 适配层**，泄漏到 Event 枚举会让 common 模块依赖渠道概念，破坏分层。

```java
// 错误：Event 枚举里维护渠道映射
public enum PayOrderEvent implements BaseEvent {
    PAY_SUCCESS, PAY_FAIL;
    private static final Map<ChannelResultStatusEnum, PayOrderEvent> MAP = new HashMap<>();
    public static PayOrderEvent fromChannelResult(ChannelResultStatusEnum s) { ... }  // ❌
}

// 正确：渠道映射放在 gateway 层的 Translator
public class ChannelResultToPayEventTranslator {
    public PayOrderEvent translate(ChannelResultStatusEnum s) { ... }
}
```

**MUST NOT** 同时定义语义重复的事件（如 `AUTHORIZE` 与 `AUTHORIZE_SUCCESS`）。

### DM-08c: 终态语义分离

**MUST** `PAY_FAIL`（渠道返回失败）与 `CANCEL` / `TIMEOUT`（关闭）必须流转到**不同**终态。

```java
// 错误：渠道失败和主动关单都映射到 CLOSED，丢失语义
STATE_MACHINE.accept(PAYING, PAY_FAIL, CLOSED);
STATE_MACHINE.accept(PAYING, TIMEOUT,  CLOSED);

// 正确：用 FAILED 区分渠道失败，CLOSED 表示主动/超时关闭
STATE_MACHINE.accept(PAYING, PAY_FAIL, FAILED);
STATE_MACHINE.accept(PAYING, TIMEOUT,  CLOSED);
```

**理由**：差错处理、退款链路、对账分桶都依赖这两种终态的区分；合并会导致下游无法判断该走"未扣款撤销"还是"已扣款冲正"。

### DM-21: 聚合根仅暴露 transferStatusByEvent 推进状态；MUST NOT 业务包装方法

**MUST** 聚合根状态推进**唯一入口**是 `transferStatusByEvent(Event)`。外部（DomainService）MUST 通过传入 `Event` 让状态机查表决定能否流转。

**MUST NOT** 聚合根暴露任何"业务包装方法"——即任何内部调用 `transferStatusByEvent` 的 public 方法。危害：**让外部"无意识地"绕过状态机校验**。

**反模式清单**（任何 public 方法只要内部含 `transferStatusByEvent` 即违反）：

| 反模式类型 | 示例 |
|---|---|
| 状态/事件同名 | `close()` / `settle()` / `cancel()` / `void()` |
| 业务动词包装 | `submitToChannel()` / `authorize()` / `capture()` / `refund()` |
| 事件命名包装 | `recordRefund(Money)` / `markPaidByChannel()` |
| 渠道结果回调 | `handleChannelSuccess()` / `onCaptureNotify()` |

**正解 — DomainService 协调，DomainModel 透传事件**：

```java
// ❌ 错误：DomainModel 暴露 authorize() 包装方法
public class PreAuthOrder {
    public void authorize(ChannelAuthResult result) {
        this.channelAuthToken = result.getToken();
        transferStatusByEvent(PreAuthOrderEvent.AUTHORIZE_SUCCESS); // 外部一调 authorize() 就跳过了状态机判断
    }
}
preAuthOrder.authorize(result); // ❌ 看似业务动作，实则绕过状态机

// ✅ 正确：业务字段更新 + 状态推进由 DomainService 协调
public class PreAuthOrder {
    public void setChannelAuthToken(String token) { this.channelAuthToken = token; }
    public void setAuthTokenExpiresAt(LocalDateTime t) { this.authTokenExpiresAt = t; }
    // 只暴露字段 setter；不写 authorize() 这种包装方法
}

public class PreAuthDomainServiceImpl implements PreAuthDomainService {
    public void authorize(PreAuthOrder preAuthOrder, ChannelAuthResult result) {
        preAuthOrder.setChannelAuthToken(result.getToken());
        preAuthOrder.setAuthTokenExpiresAt(result.getTokenExpiresAt());
        preAuthOrder.transferStatusByEvent(PreAuthOrderEvent.AUTHORIZE_SUCCESS);
    }
}
```

**理由**（必须读）：

1. **绕过校验风险**：`payOrder.close()` 看似是业务动作，实际只是 `transferStatusByEvent(CANCEL_EVENT)`。调用者在 DomainService 写 `if (error) payOrder.close()` 时**无意识地绕过**了状态机的"当前态是否允许 CANCEL_EVENT"校验。
2. **可审计性**：状态机推进**只有一个入口**时，所有状态变更天然集中在状态机日志，不需要遍历多个包装方法。
3. **抗腐性**：业务命名（`authorize` / `capture`）会随渠道差异变化（不同渠道对同一操作的叫法、字段含义可能不同）；`Event` 是领域内部稳定概念。
4. **强制 DomainService 显式决策事件**：杜绝"看到成功就 setStatus(SUCCESS)"模式，让 DomainService 必须先想清楚"这次操作对应哪个领域事件"。

**例外（无副作用方法保留）**：`canXxx()/isXxx()` 判断、`calculateXxx()` 计算、业务字段 setter/getter（前提：setter 不调 `transferStatusByEvent`）。

**MUST** 状态字段（`currentStatus`/`previousStatus`/`statusChangedAt`/`finalStatusAt`）setter MUST 是 `private`，仅由 `transferStatusByEvent` 内部修改（与 DM-04/DM-06 协同）。

**关联**：[`anti-patterns.md`](anti-patterns.md) AP-22 / AP-24；完整设计见 [`reference-implementation.md`](reference-implementation.md)。

---

## Money

### DM-09: 全链路 Money 类型

**MUST** 所有金额字段使用 `Money` 类型，不允许裸 `BigDecimal` 表示金额。

```java
// 正确
private Money amount;           // 订单金额
private Money refundedAmount;   // 已退款金额
private Money channelFeeAmount; // 渠道手续费金额

// 错误
private BigDecimal amountValue;
private String amountCurrency;
```

### DM-10: 入口立即转 Money（内部对象 MUST 用 Money，MUST NOT 拆 amountValue+currency）

**MUST** 外部请求跨入应用边界时，第一时间（app 层 `FacadeConverter` / adapter `MessageConverter`）把金额转成 `Money`。**过了入口，所有内部对象——app 层 Command、domain 入参、`DomainService`/`XxxResultInfo` 等——MUST 持有 `Money`，MUST NOT 用拆开的 `amountValue`(BigDecimal) + `currency`(String) 表示金额。**

拆开的原始金额表示只允许出现在**真正的外部边界**：入站 client `Request`/`Response`（用 `MoneyDTO`，见 DM-18）、出站**对外通知** `XxxNotifyCommand`（下游/商户要求的最小币种单位）、以及 infra 网关实现**真正调用渠道 SDK** 的那一刻（转成渠道要求的最小币种单位/字符串）。**渠道网关命令/结果 `ChannelXxxCommand`/`ChannelXxxResult` 属内部应用间传递，MUST 用 `Money`**（网关是内部防腐层，不是外部线格式）——Money → 最小币种单位的转换下沉到 infra 调 SDK 的边缘，不在 `ChannelXxxCommand` 上拆。边界 DTO 在 Converter/SDK 边缘与 `Money` 互转，边界内一律 `Money`。

```java
// 正确：app Command 持有 Money，不拆
@Getter
@Builder
public class PaymentCommand {
    private final String merchantId;
    private final String externalOrderNo;
    private final Money amount;                 // ✅ Money
}

// 入口 Converter（client Request → app Command）：第一时间合成 Money
// request.getAmount() 是 MoneyDTO（amount + currency，见 DM-18）
Money amount = Money.of(request.getAmount().getAmount(), request.getAmount().getCurrency());

// 错误：app Command 用拆开的原始表示
public class PaymentCommand {
    private final BigDecimal amountValue;       // MUST NOT
    private final String currency;              // MUST NOT —— 应合成 Money amount
}
```

后果：命令/领域层散落 `amountValue + currency`，会诱发裸 `BigDecimal` 运算（违反 DM-11）、币种校验分散、精度与舍入不统一；`Money` 把「金额 + 币种 + 精度 + 舍入」收敛为一个值对象，入口即转是全链路 `Money`（DM-09）的前提。

### DM-11: 禁止裸 BigDecimal 运算

**MUST NOT** 在业务逻辑中直接对 BigDecimal 做加减乘除。**MUST** 使用 Money 的方法：`add()`、`subtract()`、`multiply()`、`divide()`。

```java
// 错误
BigDecimal remaining = amount.getValue().subtract(refundedAmount.getValue());
// 正确
Money remaining = amount.subtract(refundedAmount);
```

### DM-12: 显式指定 RoundingMode

**MUST** 所有金额计算显式指定舍入模式，禁止使用默认舍入。

| 场景 | RoundingMode |
|------|-------------|
| 向商户收取手续费 | UP |
| 向用户退款 | DOWN |
| 统计/报表计算 | HALF_UP |

```java
Money channelFee = amount.multiply(feeRate, RoundingMode.UP);    // 向上取整，对商户收费
Money refundFee  = paidFee.multiply(refundRatio, RoundingMode.DOWN); // 向下取整，对用户退款
```

### DM-13: 精度规则（仅法币）

**MUST** 遵循法币币种精度，本系统仅处理法币：

| 币种 | 精度 |
|------|------|
| CNY / USD / EUR | 2 位 |
| JPY / KRW | 0 位 |

**MUST NOT** 引入加密货币精度（BTC/ETH/USDT/USDC 等），本系统不涉及数字货币业务。

---

## Business ID

### DM-14: 使用 BusinessId 生成器

**MUST** 使用 `BusinessIdGenerator.generate(BusinessType, SystemCode)` 生成业务 ID。**MUST NOT** 使用 Snowflake 或 UUID 作为业务订单号。

```java
// 正确
String payOrderNo = BusinessIdGenerator.generate(BusinessType.PAYMENT, SystemCode.TRADE);
// 错误
String payOrderNo = UUID.randomUUID().toString();
```

### DM-15: BusinessId 注解

**MUST** PO 的业务 ID 字段使用 `@BusinessId` 注解：

```java
/** 支付单号 */
@BusinessId(systemCode = SystemCode.TRADE, businessType = BusinessType.PAYMENT)
@TableField(value = "pay_order_no", fill = FieldFill.INSERT)
private String payOrderNo;
```

---

## 转换层

### DM-16: MapStruct 转换

**MUST** 使用 MapStruct（`@Mapper(componentModel = "spring")`）实现对象转换。**MUST NOT** 手写逐字段赋值代码，**MUST NOT** 使用 `processor`/`assembler` 分层——统一命名 `converter`。

```java
// 正确：位于 trade-infra/{biz}/converter/PayOrderConverter.java
@Mapper(componentModel = "spring")
public interface PayOrderConverter {
    PayOrder toDomainModel(PayOrderPO po);
    PayOrderPO toPO(PayOrder payOrder);
}

// 错误：手动逐字段赋值
PayOrder order = new PayOrder();
order.setPayOrderNo(payOrderPO.getPayOrderNo());
order.setAmount(Money.of(payOrderPO.getAmountValue(), payOrderPO.getAmountCurrency()));
// ... 20+ 行赋值
```

### DM-17: 转换方向清晰

**MUST** 为每个转换方向定义独立的 Converter。**位置严格遵守**（违反者见 [`anti-patterns.md`](anti-patterns.md) AP-25）：

| Converter | 位置 | 职责 |
|-----------|------|------|
| `{Entity}Converter` | `trade-infra/{biz}/converter/` | PO ↔ DomainModel（**不带 `Domain` 后缀**，防止 domain 反向依赖 infra） |
| `Channel{Biz}Converter` | `trade-infra/{biz}/channel/converter/` | 渠道 request/response ↔ app gateway command/result |
| `{Biz}FacadeConverter` | `trade-app/{biz}/converter/` | client Request/Response ↔ app command/result |
| `{Biz}GatewayConverter` | `trade-app/{biz}/converter/` | app command/result ↔ gateway command/result；DomainModel → NotifyCommand/EventCommand |
| `{Biz}MessageConverter` | `trade-adapter/consumer(或 scheduler)/{biz}/converter/` | MQ Message → app command / Scheduler 参数 → app command |

**关键约定**：Converter 命名**不带 `Domain` 后缀**；domain 层**不放 Converter**（避免依赖 PO 引起反向依赖）。

---

## DM-18: 对外金额用统一的 MoneyDTO（amount + currency）

**MUST** 对外契约（client `Request`/`Response`、facade DTO）传输金额时，使用统一的 `MoneyDTO`，且**只含两个字段**：`amount` + `currency`。**MUST NOT** 在业务 DTO 里散放 `amountValue`/`amount` + 独立 `currency` 两个平级字段——金额与币种必须成对封装进 `MoneyDTO`。DTO 跨入应用边界后，入口 Converter 立即转成内部 `Money`（DM-10）。

```java
// 位于 {system}-client 的共享 DTO 包（如 com.company.{system}.client.common）
@Data
public class MoneyDTO implements Serializable {
    /** 金额（主单位，如元；ISO 4217 对应精度） */
    @NotNull
    @DecimalMin(value = "0.01")
    @Digits(integer = 16, fraction = 2)
    private BigDecimal amount;

    /** 币种（ISO 4217，仅法币） */
    @NotBlank
    @Pattern(regexp = "^[A-Z]{3}$")
    private String currency;
}

// Request 里嵌套 MoneyDTO（配合 @Valid 级联校验），不再散放 amount + currency
public class PaymentRequest {
    @NotNull @Valid
    private MoneyDTO amount;
}

// 入口 Converter：MoneyDTO → Money
Money amount = Money.of(request.getAmount().getAmount(), request.getAmount().getCurrency());
// Money → MoneyDTO（对外返回时）
new MoneyDTO(money.getAmount(), money.getCurrency());
```

> 币种最小单位（分）是**某些渠道/下游 API 的传输要求**，属出站边界细节，由对应 gateway Converter 在 `Money → ChannelXxxCommand` 时产出（`money.getMinorUnits()`），不作为对外 `MoneyDTO` 的标准形态。对外 `MoneyDTO` 统一 `amount`(BigDecimal 主单位) + `currency`。

---

## DM-19: DomainService 方法命名为业务事件；AppService 方法命名为用户意图

**MUST** 严格区分两层的方法命名（详见 [`reference-implementation.md`](reference-implementation.md)）：

| 层 | 方法命名 | 示例 |
|----|---------|------|
| **AppService**（app 层）| 业务动作 / 用户意图 | `pay(PaymentCommand)` / `refund(RefundCommand)` / `processPendingCapture(...)` |
| **DomainService**（domain 层）| 业务事件（`handleXxxResult`/`acceptXxx`/`closeXxx`）| `handlePayResult(PayOrder, PaymentResultInfo)` / `handlePreAuthResult(PayOrder, PreAuthOrder, PreAuthResultInfo)` / `acceptRefund(PayOrder, RefundOrder, RefundAcceptInfo)` / `closePayment(PayOrder, PaymentCloseReason)` |

**MUST NOT**：
1. AppService 使用 CRUD 命名（`createPayOrder`）——应用业务动作 `pay`
2. DomainService 使用业务动作命名（`pay`/`refund`）——应用业务事件 `handleXxxResult`/`acceptXxx`
3. DomainService 方法名与状态语义包装绑定（`paySuccess`/`close`）——见 DM-21/AP-22

**DomainService 方法内部三段式**：
```
1. 翻译：把 XxxResultInfo/XxxReason 翻译为 Event（私有方法 buildXxxEvent）
2. 推进：调聚合根 transferStatusByEvent(event)
3. 记录：调聚合根 record* 写入非状态字段（channelOrderNo / stdErrorCode / channelErrorCode 等，错误字段四分见 DM-22）
```

**MUST NOT** DomainService 查库、保存、调渠道、发 MQ——这些在 AppService 编排。

---

## DM-20: initStatus() 必须设置初始状态

**MUST** 聚合根的 `initStatus()` 方法内部设置初始状态（`this.setCurrentStatus(INIT)`），不得为空实现。`create()` 工厂方法调用 `initStatus()` 后不应再重复设置。

```java
@Override
public void initStatus() {
    this.setCurrentStatus(PayOrderStatus.INIT);
}
```

---

## DM-22: 渠道交互模型的错误码字段四分（内部标准错误码 + 渠道原始错误码）

**MUST** 所有「和渠道打交道」的模型，其**错误码字段**（错误码 + 对应描述）拆成**四个字段**，内部标准错误码与外部渠道原始错误码分离（仅针对错误码语义字段，不泛指其它错误/异常处理字段）：

| 字段 | 含义 | 用途 |
|------|------|------|
| `stdErrorCode` | 内部标准错误码（系统归一化） | 内部逻辑分支、监控告警、对账归类——**稳定、跨渠道可比** |
| `stdErrorMessage` | 内部标准错误描述 | 对内展示/日志 |
| `channelErrorCode` | 外部渠道原始错误码（原样保留） | 排障、审计、对客申诉、对账时与渠道核对 |
| `channelErrorMessage` | 外部渠道原始错误描述（原样保留） | 同上 |

**MUST NOT** 用单一 `failCode`/`failMessage`/`failReason` 混装渠道错误与内部错误。渠道原始码语义不稳定、跨渠道不可比，若直接当内部错误码用于逻辑判断/告警，会把渠道差异泄漏进内部逻辑、且渠道换版即失效。

适用范围（「和渠道打交道的 model」全部遵循）：订单聚合（PayOrder/PreAuthOrder/CaptureOrder/RefundOrder 等）、领域结果对象（`XxxResultInfo`）、渠道结果 DTO（`ChannelXxxResult`）、以及对应 PO。

```java
// 聚合根 / ResultInfo：四字段
private String stdErrorCode;
private String stdErrorMessage;
private String channelErrorCode;
private String channelErrorMessage;
```

四字段封装为值对象 `ChannelErrorInfo`，使 `record*`/`fail` 方法参数为 1，符合参数个数上限（`ParameterNumber ≤ 3`，见 [`code-style.md`](code-style.md)）——**MUST NOT** 写成 `recordError(stdErrorCode, stdErrorMessage, channelErrorCode, channelErrorMessage)` 四参方法（违反参数上限）：

```java
// domain/common：四分错误值对象
@Getter
@Builder
public class ChannelErrorInfo {
    private final String stdErrorCode;
    private final String stdErrorMessage;
    private final String channelErrorCode;
    private final String channelErrorMessage;
}

// 聚合根 record*（仅写字段、不推进状态），入参一个值对象
public void recordError(ChannelErrorInfo error) {
    this.stdErrorCode = error.getStdErrorCode();
    this.stdErrorMessage = error.getStdErrorMessage();
    this.channelErrorCode = error.getChannelErrorCode();
    this.channelErrorMessage = error.getChannelErrorMessage();
}
```

**channel → std 的映射是防腐职责**：渠道结果 DTO（`ChannelXxxResult`）只带**渠道原始** `channelErrorCode`/`channelErrorMessage`；在 `Channel{Biz}Converter` / gateway 翻译渠道结果为 `XxxResultInfo` 时，用「渠道码 → 内部标准码」映射表补齐 `stdErrorCode`/`stdErrorMessage`（见 [`integration.md`](integration.md) 防腐 Gateway、[`anti-patterns.md`](anti-patterns.md)）。落库聚合与 PO 四字段同时持有；渠道原始码原样保留、不丢。

```sql
-- PO 列（DM-22）
std_error_code       VARCHAR(64)  DEFAULT NULL COMMENT '内部标准错误码',
std_error_message    VARCHAR(512) DEFAULT NULL COMMENT '内部标准错误描述',
channel_error_code   VARCHAR(64)  DEFAULT NULL COMMENT '渠道原始错误码',
channel_error_message VARCHAR(512) DEFAULT NULL COMMENT '渠道原始错误描述',
```

---

## DM-23: 聚合创建用 Builder-on-aggregate（私有 @Builder 构造器 + validate + initStatus）

**MUST** 聚合根的创建走**聚合自身的 `@Builder`（私有构造器）**：入参只含创建期业务字段；构造体内 `validate()`（`FinAssert` 领域不变量）→ 设初始审计（version=0 / createAt）→ `initStatus()`。**MUST NOT** 为绕开参数上限而引入 `XxxCreateSpec` 之类的**样板参数对象**——`ParameterNumber`（CS-02）已豁免构造器（仅约束方法），`@Builder` 本身就提供具名、顺序无关的入参，比 Spec 少一个类且不变量强制在构建时执行。

```java
@Getter
@Setter                       // 业务字段 setter（restore 走 MapStruct 时需要；若聚合改私有 setter，则 restore 用 rehydrator，见下）
@NoArgsConstructor            // 供 restore 路径（MapStruct/工厂）实例化
public class PayOrder extends BaseDomainModel<PayOrderStatus, PayOrderEvent> {

    private String payOrderNo;
    private String merchantId;
    private String externalOrderNo;
    private Money amount;
    // channelOrderNo / errorInfo 等：创建期不设，由领域方法 record* 回填

    /** 创建：Builder 只收创建期字段；构造体内校验 → 置审计 → initStatus */
    @Builder
    private PayOrder(String payOrderNo, String merchantId, String externalOrderNo, Money amount) {
        this.payOrderNo = payOrderNo;
        this.merchantId = merchantId;
        this.externalOrderNo = externalOrderNo;
        this.amount = amount;
        validate();
        setVersion(0);
        setCreateAt(OffsetDateTime.now());
        initStatus();
    }

    private void validate() {
        FinAssert.hasText(payOrderNo, ResultCode.INVALID_ARGUMENT);      // hasText 仅 2 参重载（无 detail）
        FinAssert.notNull(amount, ResultCode.INVALID_AMOUNT, "amount");  // notNull/isTrue 有 3 参(带 detail)
        FinAssert.isTrue(amount.isPositive(), ResultCode.INVALID_AMOUNT, "amount must be positive");
    }
}
// 调用方（AppService）：PayOrder.builder().payOrderNo(...).merchantId(...).externalOrderNo(...).amount(...).build();
```

> **MapStruct restore 的联动（MUST 注意）**：给聚合加 `@Builder` 后，Lombok 生成 `Xxx.builder()`，MapStruct（1.5.x）会**自动侦测到目标类型的 builder** 并把 `XxxOrderConverter.toDomainModel(PO)` 的实例化策略从「无参构造 + setter」切成「builder」——而创建 Builder 只暴露创建期字段，restore 需要的 `currentStatus`/`version`/`errorInfo` 等设不进去，导致 infra 大面积 `Unknown property ... in result type XxxBuilder` 编译失败。**修复**：在该聚合的 `@Mapper` 上加 `builder = @Builder(disableBuilder = true)`（`import org.mapstruct.Builder`），强制 MapStruct 回退到无参构造 + setter 策略，restore 语义不变。
> ```java
> @Mapper(componentModel = "spring", builder = @Builder(disableBuilder = true))
> public abstract class PayOrderConverter { ... }
> ```

要点：
- **状态字段不进创建 Builder**（在父类，只由 `initStatus`/`transferStatusByEvent` 管；DM-20/DM-21）。
- **保留一个无参构造**（`@NoArgsConstructor` 或私有无参）供 restore 路径实例化。
- **restore（从 DB 回放）走独立路径**，与创建无关：MapStruct converter 设全字段 + `restoreStatus(current, previous, ...)`（专用回放入口，不经状态机），**不跑** create 的 `validate()`/`initStatus()`（历史数据可能早于当前规则，重放应信任 DB，至多做技术性完整性检查）。若聚合把业务 setter 收成私有，则 restore 改用第二个具名 Builder（`rehydrator`），MapStruct 走 builder 映射。
- `validate()` 用 `FinAssert` + `ResultCode`（结构化码），以便 Facade 模板（[`api.md`](api.md) API-13b）翻成带 code 的 `ApiResponse`；**MUST NOT** 裸抛 `DomainException("...")` 自由文本。
- 校验只在创建构造器里跑；restore 不触发。
