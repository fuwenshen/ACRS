> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 代码风格约束

> CS-01 ~ CS-17：参数封装、方法设计、异常处理、日志与注释规范、测试规范、参数校验、魔法值、Git 提交。

---

## 参数传递

### CS-01: 禁止 Map 传参

**MUST NOT** 使用 `Map<String, Object>` 作为方法参数或返回值。

**MUST** 使用具体的 DTO/Command/Param 对象。

```java
// 错误
public void createPayOrder(Map<String, Object> params) { ... }

// 正确
public void createPayOrder(CreatePayOrderCommand command) { ... }
```

### CS-02: 参数超过 3 个必须封装

**MUST** 当方法参数超过 3 个时，使用对象封装。**适用于所有方法**，包括 Service 方法、聚合根工厂方法（`create()`）、内部 build 方法。

```java
// 错误：参数过多
public void processRefund(String payOrderNo, Money refundAmount,
                           String refundNo, LocalDate refundDate) { ... }

// 错误：聚合根工厂方法参数过多
public static PayOrder create(String tradeNo, String outTradeNo,
        String bizScenario, String tradeIdentifier,
        Money amount, Money orderAmount) { ... }

// 正确：Command 封装
public void processRefund(ProcessRefundCommand command) { ... }

// 正确：聚合根工厂方法接收 Command
public static PayOrder create(CreatePayOrderCommand command) { ... }
```

---

## 方法设计

### CS-03: 主方法不超过 20 行

**MUST** 主方法（public 方法）不超过 20 行。

超过时提取私有方法，保持主方法作为"流程目录"可一眼读懂。

> **行数计量口径**：只数非注释代码行，不计注释与空行。方法内解释「为什么这么做」的注释
> 不占用行数预算。门禁实现见 `feedback/java-app/code-quality.md` ## 行数计量口径。

### CS-04: 参数组装提取为独立方法

**MUST NOT** 在主方法中编写 `set()`/`build()` 组装请求参数的代码。

**MUST** 提取到独立的 build 方法或 Converter 类中：

```java
// 错误：主方法中内联组装
public void pay(PayOrder payOrder) {
    ChannelPayRequest request = new ChannelPayRequest();
    request.setMerchantId(payOrder.getMerchantId());
    request.setAmount(payOrder.getAmount().getValue());
    request.setCurrency(payOrder.getAmount().getCurrency());
    request.setPayOrderNo(payOrder.getPayOrderNo());
    // ... 10+ 行组装代码
    channelGateway.pay(request);
}

// 正确方式一：提取 build 方法
public void pay(PayOrder payOrder) {
    ChannelPayRequest request = buildChannelPayRequest(payOrder);
    channelGateway.pay(request);
}

// 正确方式二：委托给 Converter（跨层转换推荐）
public void pay(PayOrder payOrder) {
    ChannelPayRequest request = channelRequestConverter.toChannelRequest(payOrder);
    channelGateway.pay(request);
}
```

### CS-13: 方法嵌套不超过 3 层

**MUST NOT** 方法内嵌套超过 3 层（if/for/while/try 等）。

多层嵌套必须提炼子方法。

```java
// 错误：4 层嵌套
public void processTimeoutOrders(List<PayOrder> orders) {
    if (orders != null) {
        for (PayOrder order : orders) {
            if (order.isTimeout()) {
                if (order.canClose()) {  // 第 4 层！
                    closeService.close(order);
                }
            }
        }
    }
}

// 正确：提炼子方法，降低嵌套
public void processTimeoutOrders(List<PayOrder> orders) {
    if (orders == null) return;
    for (PayOrder order : orders) {
        closeIfTimeout(order);
    }
}

private void closeIfTimeout(PayOrder order) {
    if (!order.isTimeout() || !order.canClose()) return;
    closeService.close(order);
}
```

### CS-14: 优先使用卫语句

**SHOULD** 当 if 的条件满足后执行全部逻辑时，优先用卫语句（Guard Clause）提前返回，减少嵌套。

```java
// 错误：不必要的嵌套
public Money calculateChannelFee(PayOrder order) {
    if (order != null) {
        if (order.getAmount() != null) {
            if (order.isSettled()) {
                return order.getAmount().multiply(channelFeeRate, RoundingMode.UP);
            }
        }
    }
    return Money.zero("CNY");
}

// 正确：卫语句提前返回
public Money calculateChannelFee(PayOrder order) {
    if (order == null) return Money.zero("CNY");
    if (order.getAmount() == null) return Money.zero("CNY");
    if (!order.isSettled()) return Money.zero("CNY");
    return order.getAmount().multiply(channelFeeRate, RoundingMode.UP);
}
```

---

## 异常处理

### CS-05: domain 层使用 FinAssert 断言

**MUST** 在 **domain 层**（DomainService / DomainModel）使用 `FinAssert` 进行业务规则校验和领域不变量检查。

**MUST NOT** 使用 `if + throw` 模式。

**MUST NOT** 在 API 入口层（Controller / RPC Impl）使用 `FinAssert` 做字段格式/必传校验 —— 应改用 JSR 380 注解（见 CS-16）。

```java
// 错误
if (payOrder == null) {
    throw new FinException(ResultCode.PAY_ORDER_NOT_FOUND, "Pay order not found");
}

// 正确（domain 层业务规则）
FinAssert.notNull(payOrder, ResultCode.PAY_ORDER_NOT_FOUND, "Pay order not found");
FinAssert.isTrue(command.getAmount().isPositive(),
        ResultCode.PARAM_ERROR, "Amount must be positive");
FinAssert.isTrue(payOrder.canRefund(),
        ResultCode.INVALID_STATUS, "Pay order cannot be refunded in current status");
```

> **分层原则补充**：聚合根的 `create()` 工厂方法中，字段必传/格式类校验由入口 `@Valid` 保证，不使用 `FinAssert`。只有业务规则校验（金额正负、状态合法性等）才在 domain 层用 `FinAssert`。

### CS-06: 日志和异常消息使用英文

**MUST** 所有日志输出（`log.info/warn/error`）和异常消息（`FinAssert` 断言）使用英文。

```java
// 错误
FinAssert.notNull(payOrder, ResultCode.PAY_ORDER_NOT_FOUND, "支付单不存在");
log.error("支付失败: {}", payOrderNo);

// 正确
FinAssert.notNull(payOrder, ResultCode.PAY_ORDER_NOT_FOUND, "Pay order not found");
log.error("Payment failed, payOrderNo: {}", payOrderNo);
```

---

## 日志与代码格式

### CS-07: 日志禁止表情符号

**MUST NOT** 在日志输出中使用表情符号。

```java
// 错误
log.info("✅ Pay order created successfully: {}", payOrderNo);
log.warn("⚠️ Refund exceeds threshold: {}", payOrderNo);

// 正确
log.info("Pay order created successfully, payOrderNo: {}", payOrderNo);
log.warn("Refund exceeds threshold detected, payOrderNo: {}", payOrderNo);
```

### CS-08: 禁止类的全路径引用

**MUST NOT** 在代码中使用类的完整包路径。

**MUST** 通过 `import` 导入后使用简单类名。

```java
// 错误
com.company.fin.share.kernel.money.Money amount =
    com.company.fin.share.kernel.money.Money.of(value, "CNY");

// 正确
import com.company.fin.share.kernel.money.Money;
Money amount = Money.of(value, "CNY");
```

### CS-09: 类、方法、属性和关键步骤必须有中文注释

**MUST** 所有 Java 代码必须**完整覆盖**以下四类注释，全部使用**中文**：

| 级别 | 要求 | 内容 |
|------|------|------|
| **类注释**（class-level Javadoc） | 每个类、接口、枚举都必须有 | 类的职责与业务定位、关键协作者、线程安全说明（如适用） |
| **方法注释**（method-level Javadoc） | 每个 public/protected 方法必须有；复杂 private 方法也必须有 | 业务含义、参数语义、返回值、抛出的业务异常 |
| **属性注释**（field-level Javadoc） | 每个字段（含枚举值）必须有 | 字段的业务含义、单位、取值范围或约束 |
| **关键步骤注释**（inline comment） | 复杂业务逻辑、分支判断、计算公式、非显而易见的代码路径 | 说明为什么（Why），不是做什么（What） |

**MUST NOT** 注释使用英文（日志和异常消息除外，见 CS-06）。

**MUST NOT** 仅有空洞的 getter/setter/空构造器留空注释（无业务语义的标准方法可免注释，但属性本身必须有注释）。

```java
/**
 * 支付单聚合根
 *
 * <p>管理支付订单的完整生命周期：创建、支付中、成功、失败、关闭。</p>
 *
 * @author finbuddy-trade
 * @since 1.0.0
 */
public class PayOrder {

    /** 支付金额（商户发起支付请求的金额） */
    private Money amount;

    /** 已退款金额（累计实际退款金额） */
    private Money refundedAmount;

    /**
     * 是否可以发起退款（无副作用业务判断 ✅）
     * 仅当状态为支付成功且尚有可退余额时允许。
     *
     * @return true 表示当前状态允许退款
     */
    public boolean canRefund() {
        return getCurrentStatus() == PayOrderStatus.PAID
                && refundedAmount.lessThan(amount);
    }

    /**
     * 计算可退余额（无副作用业务计算 ✅）
     *
     * @return 支付金额减去已退款金额
     */
    public Money getRefundableAmount() {
        return amount.subtract(refundedAmount);
    }

    /** 业务字段 setter（仅更新字段，不推进状态 ✅） */
    public void setRefundedAmount(Money refundedAmount) {
        this.refundedAmount = refundedAmount;
    }

    // ❌ MUST NOT：暴露 recordRefund(Money) / settle() / close() 等业务包装方法
    //              ——它们内部调 transferStatusByEvent 等同于让外部绕过状态机（详见 DM-21 / AP-22）
}
```

---

## 测试

### CS-10: DB 操作必须有测试

**MUST** 所有数据库操作（Repository）和服务（DomainService）编写对应的测试用例。

### CS-11: 测试场景基于真实支付业务

**MUST** 测试用例按真实支付业务场景编写，不使用无意义的测试数据。

```java
// 错误：无意义数据
Money amount = Money.of(new BigDecimal("1"), "XXX");

// 正确：真实业务场景（支付人民币）
Money amount = Money.of(new BigDecimal("10000.00"), "CNY");
Money refundAmount = Money.of(new BigDecimal("500.00"), "CNY"); // 部分退款金额
```

### CS-12: Mock 策略

**MUST** 模块外部服务（RPC、HttpClient、Redis）使用 Mock。

**MUST NOT** Mock 模块内部服务。模块内部走真实调用，确保集成正确性。

```java
// 外部 Gateway → Mock
@MockBean
private ChannelGateway channelGateway;

@MockBean
private MerchantGateway merchantGateway;

// 内部 DomainService → 不 Mock，使用真实实现
@Autowired
private PayOrderDomainService payOrderDomainService;  // 真实注入
```

---

## 参数校验（入口层）

### CS-16: Request DTO 使用 JSR 380 注解

**MUST** 所有 Request DTO（`client.*.dto.request` 包下的类）字段使用 JSR 380（Jakarta Bean Validation）注解声明格式/必传/长度/范围/正则约束。

**MUST** 触发校验：**HTTP Controller** 用 `@RequestBody @Valid` 自动触发；**RPC Facade（RPC）** 由 `FacadeTemplate` 程序化触发（RPC 下 `@Valid` 不自动生效，详见 [`api.md`](api.md) API-11 / API-13b）。

**MUST NOT** 在 Controller / RPC Impl 中手工 if-throw 或 `FinAssert` 做字段格式/必传校验（属 CS-05 + AP-17 违规）。

**MUST** 在 `start` 模块配置 `@RestControllerAdvice` 全局异常处理器，将 `MethodArgumentNotValidException` / `ConstraintViolationException` 映射为 `ApiResponse.fail(ResultCode.PARAM_ERROR, ...)`。

常用注解速查：

| 注解 | 场景 |
|------|------|
| `@NotNull` | 对象非 null |
| `@NotBlank` | String 非 null 且 trim 后非空 |
| `@NotEmpty` | Collection/Map/Array/String 非 null 且 非空 |
| `@Size(min=, max=)` | 集合/字符串长度 |
| `@Pattern(regexp=)` | 正则匹配 |
| `@Min` / `@Max` | 整型范围 |
| `@DecimalMin` / `@DecimalMax` | BigDecimal 范围 |
| `@Digits(integer=, fraction=)` | 数字整数/小数位数 |
| `@Email` | 邮箱格式 |
| `@Past` / `@Future` | 时间相对于当前 |
| `@Valid` | 级联校验嵌套对象 |

```java
// 正确示例：Request DTO 声明约束
@Data
public class CreatePayOrderRequest {
    @NotBlank @Size(max = 64)
    private String merchantId;

    @NotBlank @Pattern(regexp = "^[A-Za-z0-9_-]{1,64}$")
    private String externalOrderNo;

    @NotNull @DecimalMin(value = "0.01") @DecimalMax(value = "1000000.00")
    @Digits(integer = 10, fraction = 2)
    private BigDecimal amount;

    @NotBlank @Pattern(regexp = "^[A-Z]{3}$")
    private String currency;
}

// 入口用 @Valid 触发
@PostMapping
public ApiResponse<PayOrderResponse> createPayOrder(
        @RequestBody @Valid CreatePayOrderRequest request) {
    return ApiResponse.success(
            responseConverter.toResponse(
                    domainService.createPayOrder(requestConverter.toCommand(request))));
}
```

---

## 魔法值

### CS-17: 禁止魔法值，就地定义为类成员常量

**MUST NOT** 在代码中出现**魔法值**（magic value）—— 指未命名、直接硬编码在代码里的字面量（数字、字符串、正则、超时、默认分页大小、状态码字符串等）。

**MUST** 将魔法值**就地定义**为该类的 `private static final` 成员常量，命名使用 `UPPER_SNAKE_CASE`。

**MUST NOT** 为了"统一管理"而抽象独立的 `Constants` 常量类 —— 常量归属离使用它的类越近越好。

**MUST** 仅当某个字面量具有**强业务语义**（多处有序选择、对外暴露、状态流转）时，才抽象为**枚举类**。

```java
// 错误：魔法值散落在代码中
public class ChannelFeeCalculator {
    public Money calculateFee(Money amount) {
        // 0.006 是什么？2 是什么？
        return amount.multiply(new BigDecimal("0.006"))
                .setScale(2, RoundingMode.HALF_UP);
    }
}

// 错误：为所有常量建一个大而全的 Constants 类
public final class TradeConstants {
    public static final BigDecimal DEFAULT_FEE_RATE = new BigDecimal("0.006");
    public static final int MAX_REFUND_ATTEMPTS = 3;
    public static final String DEFAULT_CURRENCY = "CNY";
    // ... 200 个互不相关的常量
}

// 正确：就地定义为该类的成员常量
public class ChannelFeeCalculator {
    /** 默认渠道手续费率 */
    private static final BigDecimal DEFAULT_FEE_RATE = new BigDecimal("0.006");

    /** 手续费舍入精度（分） */
    private static final int FEE_SCALE = 2;

    /**
     * 计算渠道手续费
     *
     * @param amount 支付金额
     * @return 渠道手续费金额
     */
    public Money calculateFee(Money amount) {
        return amount.multiply(DEFAULT_FEE_RATE)
                .setScale(FEE_SCALE, RoundingMode.HALF_UP);
    }
}

// 正确：强业务语义才抽象为枚举
/**
 * 退款方式
 *
 * <p>支持的退款处理类型，影响退款路由与到账时效。</p>
 */
public enum RefundMethod {
    /** 全额退款：一次性退还全部支付金额 */
    FULL_REFUND,
    /** 部分退款：退还部分支付金额，可多次发起 */
    PARTIAL_REFUND;
}
```

**判定标准**（是否需要抽枚举）：

| 场景 | 处理方式 |
|------|---------|
| 计算常数（精度、费率、阈值、默认超时） | 类内 `private static final` 成员常量 |
| 类内部使用的 key、prefix、错误前缀 | 类内 `private static final` 成员常量 |
| 多分支有序选择（退款方式、订单状态、事件类型） | 枚举类（enum） |
| 对外暴露的返回码、错误码 | 枚举类（如 `ResultCode`） |
| 状态机的状态与事件 | 枚举类（如 `PayOrderStatus` / `PayOrderEvent`） |

---

## Git 提交

### CS-15: 禁止 AI 署名

**MUST NOT** 在 git commit message 中包含任何 AI 工具署名信息（如 `Co-Authored-By: Claude ...`、`Generated by ...` 等）。

提交记录应保持干净，仅反映变更内容本身。
