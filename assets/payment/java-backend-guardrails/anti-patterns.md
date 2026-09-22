> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 反模式清单

> 汇总所有"禁止"项。每条包含：错误写法 → 问题说明 → 正确写法。
> 代码审查和自检阶段必须逐条过滤；**子 Agent 完成代码生成后必须加载本文件做最终自检**。

---

## 金额处理

### AP-01: 裸 BigDecimal 运算

```java
// 错误：直接用 BigDecimal 做金额运算
BigDecimal totalAmount = amount.add(fee);
BigDecimal channelFee = amount.multiply(feeRate);
```

**问题**：无币种校验，可能混合不同币种运算；无统一精度和舍入控制。

```java
// 正确：使用 Money 方法
Money totalAmount = amount.add(fee);                          // 自动校验 assertSameCurrency
Money channelFee = amount.multiply(feeRate, RoundingMode.UP); // 显式舍入
```

### AP-02: double 表示金额

```java
// 错误：用 double/float 存储金额
double amount = 10000.00;
float feeRate = 0.006f;
```

**问题**：浮点精度丢失，0.1 + 0.2 ≠ 0.3，金融场景不可接受。

```java
// 正确：使用 Money 或 BigDecimal
Money amount = Money.of(new BigDecimal("10000.00"), "CNY");
BigDecimal feeRate = new BigDecimal("0.0060");
```

### AP-03: 省略 RoundingMode

```java
// 错误：不指定舍入模式
BigDecimal channelFee = amount.divide(new BigDecimal("3")); // 除不尽时抛 ArithmeticException
```

```java
// 正确：显式指定
Money channelFee = amount.divide(new BigDecimal("3"), RoundingMode.UP);
```

---

## 状态管理

### AP-04: 直接 setStatus

```java
// 错误：绕过状态机直接设置状态
payOrder.setCurrentStatus(PayOrderStatus.PAID);
```

**问题**：跳过状态机校验，可能产生非法状态转换，无日志记录，终态判断失效。

```java
// 正确：事件驱动
payOrder.transferStatusByEvent(PayOrderEvent.PAY_SUCCESS);
```

### AP-05: if-else / switch 推进状态

```java
// 错误 1：if-else 决定目标状态
if (payResult.isSuccess()) {
    payOrder.setCurrentStatus(PayOrderStatus.PAID);
} else {
    payOrder.setCurrentStatus(PayOrderStatus.FAILED);
}

// 错误 2：switch-case 决定目标状态（DM-05 同样禁止 switch）
switch (channelResult.getResultCode()) {
    case "00": payOrder.setCurrentStatus(PayOrderStatus.PAID);   break;
    case "01": payOrder.setCurrentStatus(PayOrderStatus.CLOSED); break;
    case "02": payOrder.setCurrentStatus(PayOrderStatus.FAILED); break;
    default:   payOrder.setCurrentStatus(PayOrderStatus.PAYING);
}

// 错误 3：在 Status 枚举内部用 switch (this) 推目标态（state-machine-template §6 反例 1）
public BaseStatus getTargetStatus(BaseEvent event) {
    switch (this) {
        case INIT:   if (event == SUBMIT) return PAYING; break;
        case PAYING: if (event == PAY_SUCCESS) return PAID; break;
        // ...
    }
    return null;
}
```

**问题**：
1. 状态转换逻辑散落在服务层 / 枚举内部，难以维护，新增状态时所有 switch / if-else 都要改
2. 跳过状态机校验，可能产生非法状态转换
3. 渠道结果码、业务条件 → 目标态 的映射应集中在状态机的 `STATE_MACHINE.accept(...)` 静态注册中
4. switch 与 if-else 等价违规，**MUST NOT** 用 switch 绕过 DM-05

```java
// 正确：只决策"领域事件"，由状态机查 STATUS_EVENT_PAIR 决定目标
PayOrderEvent event = payResult.isSuccess() ? PayOrderEvent.PAY_SUCCESS : PayOrderEvent.PAY_FAIL;
payOrder.transferStatusByEvent(event);

// 正确：渠道结果 → Event 的翻译放在独立 Translator（gateway 层适配器）
PayOrderEvent event = channelResultTranslator.toPayOrderEvent(channelResult);
payOrder.transferStatusByEvent(event);

// 正确：Status 枚举的 getTargetStatus 只查表，一行
@Override
public BaseStatus getTargetStatus(BaseEvent event) {
    if (!(event instanceof PayOrderEvent e)) return null;
    return STATE_MACHINE.getTargetStatus(this, e);  // ← 查 STATUS_EVENT_PAIR Map
}
```

**关联规则**：DM-04 / DM-05 / DM-06 / DM-21；scaffolds/state-machine-template.md §6 反例 1。

### AP-06: 在 Service 层修改模型状态

```java
// 错误：服务层直接操作模型内部状态字段
public void handlePayResult(PayOrder payOrder, ChannelPayResult channelResult) {
    payOrder.setCurrentStatus(PayOrderStatus.PAID);
    payOrder.setPreviousStatus(payOrder.getCurrentStatus());
    payOrder.setFinalStatusAt(LocalDateTime.now());
}
```

**问题**：状态流转逻辑属于模型行为，不应散落在服务层，破坏领域模型封装性。

```java
// 正确：DomainService 三段式——翻译（私有 buildXxxEvent）→ 推进（唯一入口）→ 记录（DM-19）
public void handlePayResult(PayOrder payOrder, ChannelPayResult channelResult) {
    // 1. 翻译：渠道结果 → 领域事件，判定逻辑集中在私有方法内
    PayOrderEvent event = buildPayResultEvent(channelResult);

    // 2. 推进：唯一入口 transferStatusByEvent，由状态机校验当前态是否允许该事件
    payOrder.transferStatusByEvent(event);

    // 3. 记录：非状态业务字段通过 record*/setter 回填
    payOrder.recordChannelOrderNo(channelResult.getChannelOrderNo());
}

private PayOrderEvent buildPayResultEvent(ChannelPayResult channelResult) {
    return channelResult.isSuccess() ? PayOrderEvent.PAY_SUCCESS : PayOrderEvent.PAY_FAIL;
}
```

**MUST NOT**：`refundedAmount` 等纯业务字段更新（如 `payOrder.setRefundedAmount(...)`）不驱动 `PayOrder` 自身状态机——退款后 `PayOrder` 状态仍为 `PAID`，**MUST NOT** 为此新增 `PayOrderEvent.REFUND_COMPLETE`/`PARTIAL_REFUND` 等不存在的事件；退款单自身的状态推进由 `RefundOrder` 独立状态机负责（DM-08）。详见 integration.md INT-12。

---

## 事务管理

### AP-07: @Transactional 注解

```java
// 错误
@Transactional
public void createPayOrder(CreatePayOrderCommand command) {
    merchantGateway.check(command.getMerchantId());  // 外部调用在事务内 → 长事务
    payOrderRepository.save(payOrder);
    payOrderMqGateway.sendCreatedEvent(payOrder);    // MQ 在事务内 → 回滚时消息已发
}
```

**问题**：事务范围过大，外部调用导致长事务；MQ 发送在事务回滚后无法撤回。

```java
// 正确：TransactionTemplate + 三段式
// PREPARE（事务外）
MerchantResult merchantResult = merchantGateway.check(command.getMerchantId());
PayOrder payOrder = PayOrder.create(command, merchantResult);

// EXECUTE（事务内，仅 DB 操作）
transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder));

// CONVERT（事务提交之后，顺序外发）：能执行到此即已提交（失败会抛异常中断）
payOrderMqGateway.sendCreatedEvent(gatewayConverter.toCreatedCommand(payOrder));
```

### AP-08: 用事务回调（含 Spring 原生 afterCommit）发外部消息

```java
// 错误：使用 Spring 原生 afterCommit
TransactionSynchronizationManager.registerSynchronization(
    new TransactionSynchronization() {
        @Override
        public void afterCommit() {
            channelGateway.notifyPaySuccess(payOrder); // 长操作，DB 连接未释放
        }
    }
);
```

**问题**：`afterCommit()` 在事务提交后但连接释放前执行，长操作会持续占用数据库连接。更一般地，一旦事务边界收敛在 `TransactionExecutor` 内（失败即抛异常中断流程、独立提交），任何 afterCommit 回调都属多余——"提交后发送"直接由事务块之后的顺序调用实现即可。

```java
// 正确：事务块内只落库；提交后（事务块返回之后、连接已释放）顺序发送，无任何回调
transactionExecutor.executeWithoutResult(() -> payOrderRepository.updateWithVersion(payOrder));
channelGateway.notifyPaySuccess(gatewayConverter.toNotifyCommand(payOrder));
```

---

## 持久化

### AP-09: 启用 OptimisticLockerInterceptor

```java
// 错误：启用 MyBatis-Plus 乐观锁拦截器
@Bean
public MybatisPlusInterceptor mybatisPlusInterceptor() {
    interceptor.addInnerInterceptor(new OptimisticLockerInnerInterceptor()); // MUST NOT
    return interceptor;
}
```

**问题**：金融系统使用悲观锁（SELECT FOR UPDATE），乐观锁拦截器的自动重试不适合支付场景，可能导致脏写。

```java
// 正确：手动悲观锁 + 版本检查
PayOrder payOrder = payOrderRepository.getByPayOrderNoForUpdate(payOrderNo); // SELECT FOR UPDATE
int updated = payOrderRepository.updateWithVersion(payOrder);                // WHERE version = ?
FinAssert.isTrue(updated > 0,
        ResultCode.DATA_VERSION_CONFLICT, "Pay order version conflict");
```

### AP-10: PO 包含业务逻辑

```java
// 错误：在 PO 中写业务方法
@TableName("pay_order")
public class PayOrderPO {
    public boolean canRefund() { ... }          // MUST NOT：业务逻辑
    public Money calculateChannelFee() { ... }  // MUST NOT：业务逻辑
}
```

**问题**：PO 只负责 DB 映射，业务逻辑属于 DomainModel（PayOrder）。

```java
// 正确：业务逻辑在 DomainModel
public class PayOrder {
    public boolean canRefund() {
        return getCurrentStatus() == PayOrderStatus.PAID
                && refundedAmount.lessThan(amount);
    }
}
```

---

## 架构

### AP-11: app 层直接操作 Repository / Gateway

```java
// 错误：app 层跨层直接调用 Repository 或 Mapper
@Component
public class PaymentAppServiceImpl implements PaymentAppService {

    @Autowired
    private PayOrderRepository payOrderRepository; // MUST NOT：app 层不应直接依赖 Repository / Gateway 实现

    public ApiResponse<PayOrderResponse> queryPayOrder(String payOrderNo) {
        PayOrder order = payOrderRepository.getById(payOrderNo); // 跨层！
        return ApiResponse.success(responseConverter.toView(order));
    }
}
```

**问题**：违反分层架构，app 层只应依赖 domain 层（DomainService）。

```java
// 正确：通过 DomainService
@Component
public class PaymentAppServiceImpl implements PaymentAppService {

    @Autowired
    private PayOrderDomainService payOrderDomainService; // 正确：依赖 domain 层

    public ApiResponse<PayOrderResponse> queryPayOrder(String payOrderNo) {
        PayOrder order = payOrderDomainService.findById(payOrderNo);
        return ApiResponse.success(responseConverter.toView(order));
    }
}
```

### AP-12: 手写逐字段赋值

```java
// 错误：手动逐字段赋值
PayOrderResponse response = new PayOrderResponse();
response.setPayOrderNo(payOrder.getPayOrderNo());
response.setMerchantId(payOrder.getMerchantId());
response.setStatus(payOrder.getCurrentStatus().name());
response.setAmountValue(payOrder.getAmount().getValue());
// ... 20+ 行赋值
```

**问题**：冗长、易遗漏字段、难维护，新增字段需手动同步。

```java
// 正确：MapStruct 自动映射
@Mapper(componentModel = "spring")
public interface PayOrderResponseConverter {
    PayOrderResponse toResponse(PayOrder payOrder);
}
```

---

## 集成

### AP-13: MQ 消费者抛异常

```java
// 错误：消费失败抛出异常
@MqListener(id = "channelPayResult", topics = {"trade_channel_pay_result"})
public void onChannelPayResult(Message<String> message) {
    ChannelResultMessage msg = JSON.parseObject(message.getBody(), ChannelResultMessage.class);
    paymentAppService.handleChannelResult(msg); // 抛异常 → MQ 重投递 → 死循环
}
```

```java
// 正确：catch 异常，记录日志，由补偿任务处理
@MqListener(id = "channelPayResult", topics = {"trade_channel_pay_result"})
public void onChannelPayResult(Message<String> message) {
    try {
        ChannelResultMessage msg = JSON.parseObject(message.getBody(), ChannelResultMessage.class);
        paymentAppService.handleChannelResult(msg);
    } catch (Exception e) {
        log.error("Channel result message consumed failed, msgId: {}, body: {}",
                message.getMsgId(), message.getBody(), e);
    }
}
```

### AP-14: 查询穿透外部渠道

```java
// 错误：查询链路穿透到外部渠道
public PayOrderResponse queryPayOrder(String payOrderNo) {
    PayOrder order = payOrderRepository.getById(payOrderNo);
    // 实时穿透查渠道获取"最新"支付状态
    ChannelResult result = channelGateway.queryPayStatus(order.getChannelOrderNo()); // MUST NOT
    order.setCurrentStatus(mapChannelStatus(result.getStatus()));
    return responseConverter.toView(order);
}
```

**问题**：增加外部依赖、延长响应时间、渠道故障影响查询可用性。

```java
// 正确：查自身数据库，状态由 MQ 回调/补偿任务维护
public PayOrderResponse queryPayOrder(String payOrderNo) {
    PayOrder order = payOrderDomainService.findById(payOrderNo);
    return responseConverter.toView(order); // 直接返回本地最新状态
}
```

### AP-15: 事务内发 MQ

同 [`integration.md`](integration.md) INT-01：**MUST NOT** 在事务内调用 `payOrderMqGateway.sendXxxEvent(...)`；**MUST** 放在事务块返回之后（提交后）顺序发送，无需事务回调。

---

## 架构（续）

### AP-16: Gateway 实现类直接注入而非接口

```java
// 错误：注入 Gateway 实现类
@Autowired
private PayOrderRepositoryImpl payOrderRepositoryImpl; // MUST NOT：注入实现类

@Autowired
private ChannelGatewayImpl channelGatewayImpl;          // MUST NOT：注入实现类
```

**问题**：违反依赖倒置原则，导致代码与具体实现强耦合，无法替换实现（如测试时无法 Mock）。

```java
// 正确：注入接口类型
@Autowired
private PayOrderRepository payOrderRepository;   // 正确：注入接口

@Autowired
private ChannelGateway channelGateway;           // 正确：注入接口
```

---

## 参数校验

### AP-17: 入口层手工做字段格式/必传校验

```java
// 错误：在 Controller/RPC Impl 中用 if-throw 或 FinAssert 做格式校验
@PostMapping
public ApiResponse<PayOrderResponse> createPayOrder(@RequestBody CreatePayOrderRequest request) {
    if (StringUtils.isBlank(request.getMerchantId())) {                        // MUST NOT
        throw new FinException(ResultCode.PARAM_ERROR, "merchantId is required");
    }
    FinAssert.notNull(request.getAmount(), ResultCode.PARAM_ERROR, "...");     // MUST NOT
    if (request.getCurrency() == null) {                                       // MUST NOT
        throw new FinException(ResultCode.PARAM_ERROR, "invalid currency");
    }
    // ...
}
```

**问题**：格式/必传/长度/正则类校验属于 DTO 自描述，应用声明式注解统一表达；散落在入口层会导致：
1. 同一字段在多处重复校验，易漂移
2. 错误提示格式不一致
3. 无法被 swagger/openapi 文档工具识别
4. 入口代码臃肿

> 触发方式按入口类型区分：下例是 **HTTP Controller**，`@RequestBody @Valid` 自动触发；**RPC Facade（RPC）** 的 `@Valid` 不会自动生效，须由 `FacadeTemplate` 程序化跑（见 [`api.md`](api.md) API-11 / API-13b）。

```java
// 正确：在 Request DTO 上用 JSR 380 注解声明约束，HTTP 入口用 @RequestBody @Valid 触发
@Data
public class CreatePayOrderRequest {
    @NotBlank @Size(max = 64)
    private String merchantId;

    @NotNull @DecimalMin(value = "0.01") @Digits(integer = 10, fraction = 2)
    private BigDecimal amount;

    @NotBlank @Pattern(regexp = "^[A-Z]{3}$")
    private String currency;
}

@PostMapping
public ApiResponse<PayOrderResponse> createPayOrder(
        @RequestBody @Valid CreatePayOrderRequest request) {  // @Valid 触发注解校验
    // 入口零校验代码
    return ApiResponse.success(
            responseConverter.toResponse(
                    domainService.createPayOrder(requestConverter.toCommand(request))));
}
```

**业务规则校验**（金额正负、状态合法性、余额余量等）仍在 domain 层用 `FinAssert` 表达，两者分工明确。

---

## 代码规范

### AP-18: 魔法值

```java
// 错误：硬编码字面量散落在逻辑中
public Money calculateChannelFee(Money amount) {
    return amount.multiply(new BigDecimal("0.006"))           // 0.006 是什么？
            .setScale(2, RoundingMode.HALF_UP);                // 2 是什么？
}

// 错误：抽象独立的大而全 Constants 类
public final class TradeConstants {
    public static final BigDecimal DEFAULT_FEE_RATE = new BigDecimal("0.006");
    public static final int MAX_REFUND_ATTEMPTS = 3;
    // ... 100 个互不相关的常量
}
```

**问题**：魔法值降低可读性，修改时容易遗漏；独立 Constants 类导致常量与使用者分离，无法看出谁用了它。详见 [`code-style.md`](code-style.md) CS-17（就地定义为该类成员常量的正确写法）。

### AP-19: 缺少中文注释

```java
// 错误：类、属性、方法无注释
public class PayOrder {
    private Money amount;
    private Money refundedAmount;
    private PayOrderStatus currentStatus;
}
```

**问题**：缺注释的代码对后续维护者不友好，尤其是金融业务逻辑，每个字段和方法的业务含义必须显式说明。完整正确示例见 [`code-style.md`](code-style.md) CS-09。

---

## Maven 依赖

### AP-20: AppBoot groupId 错误

```xml
<!-- 错误：使用 com.company.boot 作为 AppBoot groupId -->
<groupId>com.company.boot</groupId>
<artifactId>app-boot-dependencies</artifactId>
```

**问题**：AppBoot 框架的 Maven groupId 是 `com.company.framework`，使用错误的 groupId 会导致依赖解析失败。

```xml
<!-- 正确：使用 com.company.framework -->
<groupId>com.company.framework</groupId>
<artifactId>app-boot-dependencies</artifactId>
```

---

## 方法长度与参数组装

### AP-21: Service 方法超长且内联字段赋值

```java
// 错误：主方法 40+ 行，工厂方法 6 参数，内联 setter 组装
public PayOrder asyncPay(AsyncPayCommand command) {
    // 幂等检查（Repository 返回 DomainModel，不是 PO）
    PayOrder existing = payOrderRepository.getByBizScenarioAndOutTradeNo(
            command.getBizScenario(), command.getOutTradeNo());
    if (existing != null) {
        return existing;
    }

    // 聚合根工厂方法 6 个参数（违反 CS-02）
    PayOrder payOrder = PayOrder.create(
            command.getTradeNo(), command.getOutTradeNo(),
            command.getBizScenario(), command.getTradeIdentifier(),
            command.getAmount(), command.getOrderAmount());

    // 主方法内内联多个 setter（违反 CS-04）
    payOrder.setSite(command.getSite());
    payOrder.setPiType(command.getPiType());
    payOrder.setBizCode(command.getBizCode());
    // ... 10+ 行 setter

    // 持久化 + 状态推进 + 渠道调用全部堆在主方法
    transactionTemplate.executeWithoutResult(status -> payOrderRepository.save(payOrder));
    payOrder.submitToChannel();
    // ... 再 10 行
    return payOrder;
}
```

**问题**：
1. 主方法 40+ 行，读者无法一眼看清 PREPARE/EXECUTE/CONVERT 流程（违反 CS-03）
2. 聚合根工厂方法 6 个参数（违反 CS-02）
3. 主方法内 10+ 行 setter 组装聚合根字段（违反 CS-04）
4. Command → DomainModel 的字段装配应由 MapStruct Converter 完成（违反 DM-16）

```java
// 正确：主方法是"流程目录"，细节委托给专职方法/转换器
public PayOrder asyncPay(AsyncPayCommand command) {
    // PREPARE（事务外）
    PayOrder existing = findExistingByIdempotentKey(command);
    if (existing != null) {
        return existing;
    }
    PayOrder payOrder = payOrderRequestConverter.toDomainModel(command);  // MapStruct 一次性装配

    // EXECUTE（事务内）
    saveInit(payOrder);

    // CONVERT（事务外，调渠道 + 状态推进）
    // ❌ MUST NOT：payOrder.submitToChannel() —— DomainModel 暴露业务包装方法（DM-21 / AP-22）
    // ✅ 正解：DomainService 调渠道 + 透传事件
    return dispatchToChannel(payOrder);
}

// 私有方法：DomainService 内部协调"调渠道 → 业务字段更新 → 事件透传"
private PayOrder dispatchToChannel(PayOrder payOrder) {
    ChannelResult result = channelGateway.submit(payOrder); // 调渠道（事务外）
    payOrder.setChannelOrderNo(result.getChannelOrderNo()); // 字段 setter（无状态推进）
    payOrder.transferStatusByEvent(PayOrderEvent.SUBMIT);   // 由状态机校验合法性
    return payOrder;
}

// 聚合根工厂方法接收 Command，字段赋值由 MapStruct 完成
public static PayOrder create(CreatePayOrderCommand command) {
    PayOrder payOrder = PayOrderCreateMapper.INSTANCE.toDomainModel(command);
    payOrder.initStatus();
    return payOrder;
}
```

**关键点**：主方法只保留业务流程骨架（<20 行），字段装配下沉到 Converter，聚合根工厂方法只接收一个 Command 对象；**状态推进 MUST 通过 `transferStatusByEvent(Event)`，禁止把它包装在 `submitToChannel()` 这类业务方法里**（DM-21 / AP-22）。

---

### AP-22: 聚合根暴露状态包装方法（DM-21 反例）

```java
// 错误：聚合根上写"业务动作"方法，内部偷偷调 transferStatusByEvent
public class PayOrder {
    public void submitToChannel() {              // ❌ 业务动词包装
        transferStatusByEvent(PayOrderEvent.SUBMIT);
    }
    public void close() {                        // ❌ 状态/事件同名
        transferStatusByEvent(PayOrderEvent.CANCEL);
    }
    public void paySuccess(ChannelResult r) {    // ❌ 渠道结果回调
        this.channelTradeNo = r.getChannelTradeNo();
        transferStatusByEvent(PayOrderEvent.PAY_SUCCESS);
    }
    public void recordRefund(Money amount) {     // ❌ 双重违规：业务动词包装 + 事件本身不存在
        this.refundedAmount = this.refundedAmount.add(amount);
        transferStatusByEvent(PayOrderEvent.REFUND_COMPLETE); // ❌ 不存在的事件：退款不改变 PayOrder 状态，见 DM-01 / integration.md INT-12
    }
}

// DomainService 一调，外部就"无意识地"绕过了状态机的事件合法性校验：
domainService.handleError(...) {
    payOrder.close();  // ← 调用者以为是业务动作，实际跳过了"当前态是否允许 CANCEL 事件"判断
}
```

**问题**：
1. 任何 public 方法内部含 `transferStatusByEvent(...)` = 让外部绕过状态机校验
2. 方法签名隐藏了"我会改状态"这一事实
3. 业务命名（`authorize` / `capture` / `submit`）随渠道术语变化，领域稳定概念是 `Event`

```java
// 正确：DomainModel 只暴露 transferStatusByEvent + 字段 setter + 无副作用判断
public class PayOrder {
    public void setChannelTradeNo(String no) { this.channelTradeNo = no; }
    public void setRefundedAmount(Money amount) { this.refundedAmount = amount; }
    public boolean canRefund() { ... }
    public Money getRefundableAmount() { ... }
    // 状态推进唯一入口（来自父类 / 基础包语义）
    public void transferStatusByEvent(PayOrderEvent event) { ... }
}

// DomainService 协调："业务字段更新 + 事件决策 + transferStatusByEvent"
public class PayOrderDomainServiceImpl {
    public void onPayResult(PayOrder payOrder, ChannelResult result) {
        payOrder.setChannelTradeNo(result.getChannelTradeNo());
        PayOrderEvent event = result.isSuccess()
                ? PayOrderEvent.PAY_SUCCESS
                : PayOrderEvent.PAY_FAIL;
        payOrder.transferStatusByEvent(event); // 状态机校验当前态 → 自动维护 previousStatus / finalStatusAt
    }
}
```

**Reviewer 扫描方式**：聚合根 .java 文件中，任何 `public` 方法（除 `transferStatusByEvent` 自身）方法体内出现 `transferStatusByEvent(` 字样 → 直接 Block。

**关联规则**：[`domain-modeling.md`](domain-modeling.md) DM-04 / DM-06 / DM-21；AP-04 / AP-05 / AP-06 / AP-24；完整设计参考 [`reference-implementation.md`](reference-implementation.md)。

---

### AP-23: `isTerminal()` 命名错（正确是 `isFinalStatus()`）

```java
// 错误：调用不存在的 isTerminal()
if (payOrder.isTerminal()) {                     // ❌ 编译失败 或 命名漂移
    return;
}

// 错误：在 Status 枚举上自己实现 isTerminal()
public enum PayOrderStatus implements BaseStatus {
    PAID("PAID", true, "支付成功");
    public boolean isTerminal() { return finalStatus; }   // ❌ BaseStatus 接口方法是 isFinalStatus()
}
```

**问题**：基础包 `com.company.fin.share.kernel.statemachine.BaseStatus` 接口定义的终态判断方法是 **`isFinalStatus()`**，不是 `isTerminal()`。AI 生成代码 / 研发凭感觉命名时会高频写错：

| 错误命名 | 正确命名 |
|---|---|
| `isTerminal()` | `isFinalStatus()` |
| `isFinal()` | `isFinalStatus()` |
| `isEnd()` / `isEnded()` | `isFinalStatus()` |
| `isClosed()`（指终态） | `isFinalStatus()`（`isClosed` 仅指 CLOSED 这一具体状态） |

```java
// 正确：使用基础包接口定义的方法名
if (payOrder.getCurrentStatus().isFinalStatus()) {
    return;
}
```

**Reviewer 扫描方式**：
- `grep -rn "isTerminal()" src/` 任何命中 → Block，改为 `isFinalStatus()`
- 任何 `implements BaseStatus` 的枚举若自定义了 `isTerminal()` 方法 → Block

**关联规则**：[`domain-modeling.md`](domain-modeling.md) DM-03 / DM-07；基础包 `com.company.fin.share.kernel.statemachine.BaseStatus`。

---

## 领域层与外层类型隔离

### AP-24: DomainService 接收 app / infra 类型作参数

```java
// 错误：DomainService 方法直接接收渠道结果 / DTO / Command 等 app/infra 类型
public class PaymentDomainService {
    // ChannelPayResult 是 app.payment.gateway.result 类型；一旦签名依赖，
    // domain 就间接依赖 app/infra，违反依赖方向（ARCH-02）
    public void handlePayResult(PayOrder payOrder, ChannelPayResult result) { ... }

    // 同样错误：直接接 Command / Request
    public void acceptRefund(RefundOrder ro, RefundRequest request) { ... }
}
```

**问题**：
1. `ChannelPayResult` / `RefundRequest` / `PaymentCommand` 等类型分属 `app.*.gateway.result` / `app.*.command` / `client.*.request` 包；domain 一旦引用即产生反向依赖（`domain → app` / `domain → infra`），违反 ARCH-02。
2. 渠道字段调整（如新增 `channelAuthNo`）会污染 domain 层，破坏 domain 稳定性。
3. domain 无法在没有 app / infra 的环境（如单元测试、shared 内核）中被复用。

```java
// 正确：定义 XxxResultInfo / XxxReason 作为 domain 内数据载体
// 位于 {system}-domain/{biz}/service/ 包下，POJO + isXxx()/getXxx()，无业务行为
public class PaymentResultInfo {
    private String resultType;                    // SUCCESS / FAILED / PROCESSING / WAIT_FORWARD_PAY
    private String channelOrderNo;
    private String forwardToken;
    private String redirectUrl;
    private String stdErrorCode;         // 内部标准错误码（DM-22）
    private String stdErrorMessage;
    private String channelErrorCode;     // 渠道原始错误码（DM-22）
    private String channelErrorMessage;

    public boolean isSuccess()          { return "SUCCESS".equals(resultType); }
    public boolean isFailed()           { return "FAILED".equals(resultType); }
    public boolean isProcessing()       { return "PROCESSING".equals(resultType); }
    public boolean isWaitingForwardPay(){ return "WAIT_FORWARD_PAY".equals(resultType); }
    // getters...
}

// DomainService 方法签名只接收 domain 内类型
public class PaymentDomainService {
    public void handlePayResult(PayOrder payOrder, PaymentResultInfo info) {
        PaymentEvent event = buildPayResultEvent(info);
        payOrder.transferStatusByEvent(event);
        recordPayResult(payOrder, info, event);
    }
}

// AppService 负责用 converter 把外层类型翻译成 ResultInfo
public class PaymentAppServiceImpl {
    public PaymentResult pay(PaymentCommand command) {
        // ...
        ChannelPayResult channelResult = channelPaymentGateway.pay(...);
        PaymentResultInfo info = PaymentDomainConverter.toPaymentResultInfo(channelResult);
        paymentDomainService.handlePayResult(payOrder, info);
        // ...
    }
}
```

**Reviewer 扫描方式**：
- 对每个 `*DomainService.java`，检查所有 `public` 方法的参数类型全限定名。任何参数类型出现在以下前缀 → Block：
  - `com.company.{system}.app.*`（Command / Result / Gateway 命令 / DTO / Facade 请求响应）
  - `com.company.{system}.infra.*`（PO / Channel Request/Response）
  - `com.company.{system}.client.*`（Facade Request/Response）
- 允许的参数类型：`com.company.{system}.domain.*`（含 model / statemachine / service 包下的 ResultInfo / Reason / Money 等）+ Java 标准库 + `com.company.fin.share.kernel.*`

**关联规则**：[`reference-implementation.md`](reference-implementation.md) 数据载体规则；[`architecture.md`](architecture.md) ARCH-02 依赖方向。

---

### AP-25: DomainConverter 放 domain 模块

```java
// 错误：把 PO ↔ DomainModel 转换器放在 domain 层
// {system}-domain/{biz}/converter/PayOrderDomainConverter.java
@Mapper(componentModel = "spring")
public interface PayOrderDomainConverter {
    PayOrder toDomainModel(PayOrderPO po);   // domain 引用 infra.po.PayOrderPO
    PayOrderPO toPO(PayOrder payOrder);      // 反向依赖！
}
```

**问题**：
1. Converter 引用 `PayOrderPO`（位于 `{system}-infra/{biz}/po/`），一旦放在 domain 就产生 `domain → infra` 反向依赖，违反 ARCH-02。
2. PO 字段随表结构演进而变化（新增列、类型调整），会把技术细节污染进 domain 层。
3. domain 应该完全对持久化技术无感（今天用 MySQL + MyBatis-Plus，明天可能换 ES / TiDB / 分库分表方案，domain 无需变更）。

```java
// 正确：PO ↔ DomainModel Converter 放在 {system}-infra
// {system}-infra/{biz}/converter/PayOrderConverter.java
@Mapper(componentModel = "spring")
public interface PayOrderConverter {
    PayOrder toDomainModel(PayOrderPO po);
    PayOrderPO toPO(PayOrder payOrder);
}

// RepositoryImpl 使用 converter 完成翻译
// {system}-infra/{biz}/repository/PayOrderRepositoryImpl.java
@Component
public class PayOrderRepositoryImpl implements PayOrderRepository {
    @Autowired private PayOrderMapper mapper;
    @Autowired private PayOrderConverter converter;

    @Override
    public PayOrder getById(String payOrderNo) {
        PayOrderPO po = mapper.selectById(payOrderNo);
        return converter.toDomainModel(po);
    }

    @Override
    public void save(PayOrder payOrder) {
        PayOrderPO po = converter.toPO(payOrder);
        mapper.insertOrUpdate(po);
    }
}
```

**类名去 `Domain` 后缀**：converter 位于 infra 层，语义上已不再是"领域转换器"，命名统一 `{Name}Converter`（不是 `{Name}DomainConverter`）。

**Reviewer 扫描方式**：
- `find {system}-domain/ -name "*Converter*.java"` 应该为空（或只允许 domain 内部的 Event/ResultInfo 内部构造，不涉及 PO）
- 所有 `implements ... PO` 或 `import ...infra.*.po.*PO;` 的 `@Mapper` 接口 → 必须位于 `{system}-infra/{biz}/converter/` 包下

**关联规则**：[`architecture.md`](architecture.md) ARCH-03 / ARCH-05；[`persistence.md`](persistence.md) PS-01。

---

### AP-26: 外发前未落库

```java
// 错误：先调渠道外发，后落库——渠道调用成功、进程随即崩溃，DB 从未写入过 payOrder
public PaymentResult pay(PaymentCommand command) {
    PayOrder payOrder = PayOrder.create(command);

    ChannelPayResult channelResult = channelPaymentGateway.pay(
            paymentGatewayConverter.toChannelPayCommand(payOrder));                 // ❌ 外发先于任何落库
    PaymentResultInfo resultInfo = paymentGatewayConverter.toResultInfo(channelResult);

    paymentDomainService.handlePayResult(payOrder, resultInfo);
    transactionTemplate.executeWithoutResult(status -> payOrderRepository.save(payOrder)); // 唯一一次 save，且在外发之后
    return paymentResultConverter.toResult(payOrder);
}
```

**问题**：
1. `channelPaymentGateway.pay(...)` 调用成功即代表渠道侧已扣款 / 已生效；此时若进程崩溃或发生异常，DB 里没有任何一条记录，这笔交易对本系统"从未发生过"——渠道有资金变动、本地无痕迹，无法对账、无法补偿，直接造成资损。
2. 幂等键（`payOrderNo`）也从未落库，一旦上游因超时重试，无法通过 DB 唯一索引识别重复请求（PS-14），可能导致重复外发。
3. 与 AP-21 中 `asyncPay`/`saveInit` 示例的关键差异：那里外发前已有 `saveInit(payOrder)` 落库，本例完全没有——这正是资损红线所在，而非"两段 save 的先后顺序细节"问题。

```java
// 正确：两段 save，外发前先落库（INT-18）
public PaymentResult pay(PaymentCommand command) {
    // PREPARE（事务外）：幂等校验（PS-15/PS-14）
    PayOrder existing = payOrderRepository.getByExternalOrderNo(command.getMerchantId(), command.getExternalOrderNo());
    if (existing != null) {
        return paymentResultConverter.toResult(existing);
    }

    // PREPARE（事务外）：建初始单（INIT，幂等键已就位）+ 推进到"已提交"态
    PayOrder payOrder = PayOrder.create(command);
    payOrder.transferStatusByEvent(PayOrderEvent.SUBMIT);   // INIT -> PAYING：本地事件无需翻译，AppService 直接调用聚合根唯一入口（无 DomainService 包装）

    // EXECUTE：事务① —— 外发前先落库
    transactionTemplate.executeWithoutResult(status -> payOrderRepository.save(payOrder));

    // CONVERT（事务外）：外发——此时崩溃，DB 已有该笔记录可供对账（INT-06 梯度补偿查询）
    ChannelPayResult channelResult = channelPaymentGateway.pay(
            paymentGatewayConverter.toChannelPayCommand(payOrder));
    PaymentResultInfo resultInfo = paymentGatewayConverter.toResultInfo(channelResult);
    paymentDomainService.handlePayResult(payOrder, resultInfo);   // 三段式：翻译→推进（PAYING→PAID/FAILED）→记录

    // EXECUTE：事务② —— 落回执结果
    transactionTemplate.executeWithoutResult(status -> payOrderRepository.save(payOrder));
    return paymentResultConverter.toResult(payOrder);
}
```

**关联规则**：[`integration.md`](integration.md) INT-18（完整规则 + afterCommit 通知写法）；[`persistence.md`](persistence.md) PS-11 三段式服务模式 / PS-14 幂等；[`reference-implementation.md`](reference-implementation.md) §4 端到端流程。

### AP-27: 代码侧拼装 SQL（MyBatis-Plus Wrapper / BaseMapper 泛型 CRUD）

```java
// 错误：Mapper 继承 BaseMapper，SQL 靠代码侧 Wrapper 拼装、靠泛型 CRUD 隐式生成
public interface PayOrderMapper extends BaseMapper<PayOrderPO> { }        // MUST NOT

public PayOrder getByExternalOrderNo(String merchantId, String externalOrderNo) {
    PayOrderPO po = payOrderMapper.selectOne(new LambdaQueryWrapper<PayOrderPO>()  // MUST NOT：SQL 藏进 Java 表达式
            .eq(PayOrderPO::getMerchantId, merchantId)
            .eq(PayOrderPO::getExternalOrderNo, externalOrderNo));
    return po == null ? null : converter.toDomainModel(po);
}
public void save(PayOrder payOrder) {
    payOrderMapper.insert(converter.toPO(payOrder));                       // MUST NOT：泛型 CRUD 隐式 INSERT
}
```

**问题**：
1. 最终执行的 SQL 不在任何可 review 的文件里——评审、DBA、审计都看不到语句全文，执行计划、索引使用、`FOR UPDATE` 都不可控。金融支付要求「SQL 即契约」。
2. 泛型 `insert`/`updateById` 会把 PO 的所有非空字段隐式拼进语句，字段增减时行为悄然变化；`version`/时间列的处理隐藏在 MyBatis-Plus 自动填充里，不可见。
3. Wrapper 链式条件容易在重构中被静默改写（改字段引用不报错），而 XML 显式 SQL 改动会进 diff、可 review。

```java
// 正确：Mapper 不继承 BaseMapper，方法映射到 XML 手写 SQL（见 persistence.md PS-17）
@Mapper
public interface PayOrderMapper {
    PayOrderPO selectByExternalOrderNo(@Param("merchantId") String merchantId,
                                       @Param("externalOrderNo") String externalOrderNo);
    int insertPayOrder(PayOrderPO po);
}
```

**关联规则**：[`persistence.md`](persistence.md) PS-17（显式 SQL 入 XML 完整规则 + XML 示例 + 配置）；L1 门禁见 [`../../feedback/java-app/archunit/archunit-rules.md`](../../feedback/java-app/archunit/archunit-rules.md)（无 Mapper extends BaseMapper）与 [`../../feedback/java-app/pmd/pmd-rules.xml`](../../feedback/java-app/pmd/pmd-rules.xml)（infra 无 Wrapper 导入）。
