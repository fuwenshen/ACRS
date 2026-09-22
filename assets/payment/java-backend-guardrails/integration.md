> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 集成约束

> INT-01 ~ INT-18：MQ 消息队列、ScheduleCenter 定时任务、外部调用（RPC）、Redis 缓存、ConfigCenter 配置中心、RateLimiter 限流。

---

## 消息队列（MQ）

### INT-01: MQ 发送时机

**MUST** MQ 消息在事务提交后发送——把发送**放在事务块返回之后顺序执行**（事务执行器失败即抛异常中断流程，能执行到发送行即已提交；无需 afterCommit 回调，见 [`persistence.md`](persistence.md) PS-12）。

**MUST NOT** 在事务内发送 MQ 消息（事务回滚时消息已发出，导致数据不一致）。

```java
// 错误：事务内直接发送
transactionExecutor.executeWithoutResult(() -> {
    payOrderRepository.save(payOrder);
    payOrderMqGateway.sendCreatedEvent(payOrder); // MUST NOT：事务回滚时消息已发
});

// 正确：事务块内只落库，提交后（事务块返回之后）顺序发送不可变快照
transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder));
payOrderMqGateway.sendCreatedEvent(gatewayConverter.toCreatedCommand(payOrder));
```

### INT-02: 消费失败不抛异常

**MUST NOT** MQ 消费者抛出未捕获异常（会触发 MQ 重新投递，可能造成死循环）。

**MUST** 消费失败时记录错误日志，由补偿机制（定时任务/对账）处理。

```java
/**
 * 渠道支付结果 Consumer（adapter/consumer/ 层入口）
 * 不含业务逻辑，仅做消息接收 + 消息转换 + 调 AppService。
 */
@Component
public class ChannelPayResultConsumer {

    @Autowired
    private PaymentAppService paymentAppService;
    @Autowired
    private ChannelResultMessageConverter converter;   // 位于 adapter/consumer/{biz}/converter/

    /** 监听渠道支付结果消息 */
    @MqListener(id = "channelPayResult", topics = {"trade_channel_pay_result"})
    public void onChannelPayResult(Message<String> message) {
        try {
            ChannelResultMessage msg = JSON.parseObject(message.getBody(), ChannelResultMessage.class);
            HandleChannelResultCommand command = converter.toCommand(msg);
            paymentAppService.handleChannelResult(command);   // adapter 只调 AppService
        } catch (Exception e) {
            log.error("Channel result message consumed failed, msgId: {}, body: {}",
                    message.getMsgId(), message.getBody(), e);
            // MUST NOT 抛异常；由补偿定时任务处理未更新的订单
        }
    }
}
```

### INT-03: 消息格式与 MQ Producer

**MUST** MQ 消息体使用 JSON 序列化，包含业务主键字段便于追踪。

**MUST** 使用 MQ Producer 发送消息，通过业务语义 Gateway 接口封装。
**Gateway 接口定义在 `{system}-app`**（业务语义：`TradeNotifyGateway` / `TradeEventGateway` / 具体业务 `{Biz}MqGateway`），**实现放在 `{system}-infra/mq/gateway/`**。

```java
// {system}-app/{biz}/gateway/：业务语义 MQ Gateway 接口
public interface PayOrderMqGateway {
    /** 发送支付单创建事件 */
    void sendCreatedEvent(PayOrder payOrder);
    /** 发送支付成功事件 */
    void sendPaySuccessEvent(PayOrder payOrder);
}

// {system}-infra/mq/gateway/：MQ 实现（封装 topic / tag / delay 等技术细节）
@Component
public class PayOrderMqGatewayImpl implements PayOrderMqGateway {

    @MqProducer(name = "payOrderCreatedProducer")
    private Producer payOrderCreatedProducer;

    @Override
    public void sendCreatedEvent(PayOrder payOrder) {
        PayOrderCreatedMessage msg = new PayOrderCreatedMessage();
        msg.setPayOrderNo(payOrder.getPayOrderNo());   // MUST：包含业务主键
        msg.setMerchantId(payOrder.getMerchantId());
        msg.setAmountValue(payOrder.getAmount().getValue());
        msg.setAmountCurrency(payOrder.getAmount().getCurrency());
        msg.setTimestamp(System.currentTimeMillis());

        Message<String> message = new Message<>();
        message.setTopic("trade_pay_order_created");
        message.setBody(JSON.toJSONString(msg));
        payOrderCreatedProducer.send(message);
    }
}
```

---

## 支付流设计

### INT-04: 同步受理异步处理

**MUST** 接口层同步返回受理结果（如支付请求受理成功），后续处理（渠道路由、结果回调）异步执行。

**SHOULD** 在外部渠道调用层（最不可控的外部交互）切入异步。

### INT-05: 查询不穿透

**MUST NOT** 查询链路穿透到外部渠道或下游域。

```
正确：商户 → 支付域查询（本域 DB 终态） → 返回
错误：商户 → 支付域 → 支付渠道实时查询 → 返回
```

网关查自身缓存，支付域查自身数据库，禁止向下游穿透查询。

### INT-06: 梯度补偿查询

**SHOULD** 支付/退款结果补偿查询使用梯度间隔：

```
1s → 2s → 5s → 10s → 20s → 40s → 100s
```

超过 N 次后停止主动查询，等待对账文件。

---

## 定时任务（ScheduleCenter）

### INT-07: 批量处理 + 容错

**MUST** 定时任务批量处理，设置批次上限（如 100 条/次）。

**MUST** 单条失败跳过，继续处理下一条，返回成功数量。

**MUST** 使用 `AbstractJobHandler` 实现 Scheduler，**放在 adapter/scheduler/ 层**（参 [`architecture.md`](architecture.md) ARCH-16）。

```java
/**
 * 支付单超时关单 Scheduler（adapter/scheduler/{biz}/ 层入口）
 * 扫描超时未支付订单，触发关闭状态流转。
 * adapter 只做任务触发 + 参数转换 + 调 AppService；不查库；不改 domain。
 */
@ScheduledJob()
public class PayOrderTimeoutScheduler extends AbstractJobHandler {

    @Autowired
    private PaymentAppService paymentAppService;

    @Override
    public ReturnT<String> execute(JobContext jobContext) {
        ProcessTimeoutCommand command = new ProcessTimeoutCommand();
        command.setBatchSize(100);
        command.setShardIndex(jobContext.getShardIndex());
        command.setShardTotal(jobContext.getShardTotal());
        return paymentAppService.processTimeout(command);
    }
}

// AppService 中做业务编排（不是 Scheduler 遍历）
public ReturnT<String> processTimeout(ProcessTimeoutCommand command) {
    int successCount = 0;
    List<String> timeoutIds = payOrderRepository.findTimeoutIds(
            command.getShardIndex(), command.getShardTotal(), command.getBatchSize());
    for (String payOrderNo : timeoutIds) {
        try {
            closeTimeoutOrder(payOrderNo);  // 内部走 domainService.handleTimeout(...)
            successCount++;
        } catch (Exception e) {
            log.error("Close timeout order failed, payOrderNo: {}", payOrderNo, e);
        }
    }
    log.info("Timeout check completed, total: {}, success: {}", timeoutIds.size(), successCount);
    return ReturnT.SUCCESS;
}
```

### INT-08: 有效的查询条件 + 分片支持

**MUST** 定时任务查询使用精确的筛选条件，避免全表扫描。

**SHOULD** 支持 ScheduleCenter 分片参数，实现多实例并行处理。

```java
// Repository 查询（分片支持 + 精确筛选，命中索引）：
// SELECT pay_order_no FROM pay_order
// WHERE current_status = 'PAYING'
//   AND due_time <= NOW()
//   AND MOD(id, #{shardTotal}) = #{shardIndex}
// ORDER BY due_time ASC
// LIMIT #{batchSize}
```

---

## 外部调用

### INT-09: 外部调用在事务外

**MUST** 外部服务调用（RPC、HttpClient）放在事务外的 PREPARE 阶段。

**MUST NOT** 在事务内调用外部服务（网络抖动会导致长事务占用连接池）。

```java
// 正确：PREPARE 阶段（事务外）调用外部服务
public PayOrder createPayOrder(CreatePayOrderCommand command) {
    // PREPARE：外部调用在事务外
    MerchantResult merchantResult = merchantGateway.check(command.getMerchantId()); // RPC
    ChannelResult channelResult = channelGateway.queryQuota(command);                // HTTP

    PayOrder payOrder = PayOrder.create(command, merchantResult, channelResult);

    // EXECUTE：仅 DB 操作在事务内
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder));

    // 提交后（事务块返回之后）顺序发送不可变快照
    payOrderMqGateway.sendCreatedEvent(gatewayConverter.toCreatedCommand(payOrder));
    return payOrder;
}
```

### INT-10: 防腐层隔离外部系统

**SHOULD** 外部系统交互通过业务语义 Gateway 防腐层隔离。Gateway **接口定义在 `{system}-app`**，实现在 `{system}-infra/{biz}/channel/gateway/`；AppService（不是 DomainService）负责调渠道。

```java
// {system}-app/{biz}/gateway/：业务语义接口（AppService 依赖此接口）
public interface ChannelGateway {
    /** 向渠道发起支付请求 */
    ChannelPayResult pay(ChannelPayCommand command);
}

// {system}-infra/{biz}/channel/gateway/：防腐层实现（RPC 客户端调用）
@Component
public class ChannelGatewayImpl implements ChannelGateway {

    @BootReference
    @BootReferenceBinding(alias = "channelPayService", group = "channel")
    private ChannelPayService channelPayService;

    @Override
    public ChannelPayResult pay(PayOrder payOrder) {
        // 内部模型 → 渠道 DTO
        ChannelPayRequest request = buildChannelRequest(payOrder);
        // RPC 调用
        ChannelApiResponse response = channelPayService.pay(request);
        // 渠道响应 → 内部模型（只回原始：接口层 success + 原始码 + 渠道名/接口名 + Money，不做业务归类）
        return convertToChannelResult(response);
    }
}
```

### INT-10b: 渠道返回码 → 内部标准码 映射（app 标准服务 + infra 查表，禁 infra 归类/禁 app 硬编码）

**MUST** “渠道返回码 → (业务结果分类 `BizResult` + 内部标准码)” 的映射由 **app 层标准服务**（`ChannelResultMappingService`，谁需要谁调）承担业务语义，映射数据存 **DB 表**、由 **infra 仓储**读取。

- **映射键 MUST 含 (渠道名, 接口名, 渠道返回码)**（如 `adyen-riverty` + `payment` + code）——同一渠道码在不同渠道/接口语义不同。
- **infra 只读数据、不做业务归类**（infra 无业务逻辑）：仓储按键返回映射行；“未命中兜底为 UNKNOWN、无错误码即 SUCCESS”等语义在 app 服务。
- **MUST NOT** 在 app `GatewayConverter` 里硬编码 `switch(channelCode)` 码表，也 **MUST NOT** 让渠道原始码语义泄进 domain——domain 只见内部标准码（+ 不透明原始码供审计，见 [`domain-modeling.md`](domain-modeling.md) DM-22 `ChannelErrorInfo`）。
- infra 网关实现只回**原始**（接口层 `success` + 渠道原始码 + 渠道名/接口名 + `Money` 金额）；app 拿原始码调映射服务得业务结果 + 标准码，再组装 domain 结果载体（两轴，见 [`api.md`](api.md) API-10）。

---

## 防呆设计

### INT-11: 环境隔离

**MUST** 测试环境只使用测试参数/测试渠道，禁止使用生产参数。

**MUST** Business ID 标记位区分预生产/生产（0=预生产，1=生产），防止跨环境请求。

### INT-12: 金额自检

**MUST** 退款金额 ≤ 可退余额，**由 DomainService 协调**：DomainModel 提供无副作用的判断/计算，DomainService 做断言、决策事件、调 `transferStatusByEvent`（详见 DM-21 / AP-22）。

```java
// DomainModel 仅暴露无副作用判断 + 字段 setter
public class PayOrder {
    /** 可退余额（无副作用计算 ✅） */
    public Money getRefundableAmount() {
        return amount.subtract(refundedAmount);
    }
    public void setRefundedAmount(Money amt) { this.refundedAmount = amt; }
    // 不暴露 recordRefund(Money) 等业务包装方法（DM-21）
}

// DomainService 协调：业务断言 → 字段更新（不驱动 PayOrder 自身状态机，见 DM-01）
public class RefundDomainServiceImpl {
    public void handleRefund(PayOrder payOrder, Money refundAmount) {
        // 1. 业务规则断言（domain 层用 FinAssert，CS-05）
        Money refundable = payOrder.getRefundableAmount();
        FinAssert.isTrue(refundAmount.lessOrEqual(refundable),
                ResultCode.REFUND_AMOUNT_EXCEEDED,
                "Refund amount exceeds refundable balance");

        // 2. 业务字段更新：退款不改变 PayOrder 自身支付状态（PAID 保持 PAID），
        //    是"可退余额"这一业务事实的记录，MUST NOT 经由 transferStatusByEvent 推进
        Money newRefunded = payOrder.getRefundedAmount().add(refundAmount);
        payOrder.setRefundedAmount(newRefunded);

        // 3. 退款单自身的状态推进由 RefundOrder 独立状态机负责（DM-08），
        //    MUST NOT 为此新增 PayOrderEvent.REFUND_XXX 事件
    }
}
```

### INT-13: 终态不可变

**MUST** 终态（SUCCESS/CLOSED/REFUNDED）订单不可再流转状态。

状态机保证：终态无任何出边。违反自动阻断并告警。

---

## Redis 缓存

### INT-14: 缓存使用规范

**MUST** 分布式缓存使用 Redis（内部分布式缓存），本地缓存使用 Caffeine，禁止使用 Redis。

**MUST** 缓存 Key 格式：`{系统}:{业务域}:{业务类型}:{业务ID}`，例如：`trade:pay:order:PO20260101001`。

**MUST** 设置合理的过期时间，避免缓存击穿（TTL 建议 5 分钟 ~ 1 小时，视业务频率而定）。

**MUST NOT** 缓存金融核心数据的最终状态（终态由数据库持久化为准，缓存仅用于加速查询）。

```java
// {system}-infra/redis/：Redis 缓存使用示例（Gateway 接口定义在 {system}-app/common/gateway/cache/）
@Component
public class PayOrderCacheGatewayImpl implements PayOrderCacheGateway {

    @Autowired
    private RedisClient jimClient;

    private static final String KEY_PREFIX = "trade:pay:order:";
    private static final int CACHE_TTL_SECONDS = 300; // 5 分钟

    @Override
    public Optional<PayOrder> getFromCache(String payOrderNo) {
        String key = KEY_PREFIX + payOrderNo;
        String json = jimClient.get(key);
        if (StringUtils.isBlank(json)) {
            return Optional.empty();
        }
        return Optional.of(JSON.parseObject(json, PayOrder.class));
    }

    @Override
    public void putToCache(PayOrder payOrder) {
        String key = KEY_PREFIX + payOrder.getPayOrderNo();
        jimClient.setex(key, CACHE_TTL_SECONDS, JSON.toJSONString(payOrder));
    }

    @Override
    public void evict(String payOrderNo) {
        jimClient.del(KEY_PREFIX + payOrderNo);
    }
}
```

---

## ConfigCenter 配置中心

### INT-15: 动态配置使用 ConfigCenter

**MUST** 动态配置（开关、阈值、限流参数等）使用 ConfigCenter（内部配置中心），禁止使用 Nacos 或硬编码。

**MUST** 敏感配置（渠道密钥、数据库密码）通过 ConfigCenter 加密存储，不写入代码仓库。

```java
// 正确：通过 ConfigCenter 注入动态配置
@AppConfig(key = "trade.payment.max-amount-cny")
private volatile BigDecimal maxAmountCny;

@AppConfig(key = "trade.payment.channel-timeout-ms")
private volatile Long channelTimeoutMs;

// 错误：硬编码配置
private static final BigDecimal MAX_AMOUNT = new BigDecimal("100000"); // MUST NOT
```

---

## RateLimiter 限流

### INT-16: 核心接口必须限流

**MUST** 支付、退款等核心写接口使用 RateLimiter 进行限流保护，防止流量突增压垮系统。

**SHOULD** 限流规则（QPS 阈值）通过 ConfigCenter 动态配置，支持实时调整。

```java
/**
 * 支付 RPC Facade 实现（app 层，实现 {system}-client 中定义的 Facade 接口）
 */
@BootService
@BootServiceBinding(alias = "tradePaymentFacade", group = "trade")
public class TradePaymentFacadeImpl implements TradePaymentFacade {

    @Autowired private PaymentAppService paymentAppService;
    @Autowired private PaymentFacadeConverter facadeConverter;

    @Override
    @RateLimitResource(value = "trade:payment:pay", fallback = "payFallback")
    @ApiLog(description = "RPC-支付")
    public PaymentResponse pay(PaymentRequest request) {
        PaymentCommand command = facadeConverter.toCommand(request);
        PaymentResult result = paymentAppService.pay(command);
        return facadeConverter.toResponse(result);
    }

    /** 限流降级处理 */
    public PaymentResponse payFallback(PaymentRequest request, BlockException e) {
        log.warn("Pay request blocked by RateLimiter, merchantId: {}", request.getMerchantId());
        return PaymentResponse.fail(ResultCode.SYSTEM_BUSY, "System is busy, please try again later");
    }
}
```

---

## INT-17: MQ 发送传递不可变快照

**MUST** MQ Gateway 接收**不可变快照**（app 层 command / 只读 DTO / 或聚合根深拷贝），不传递 DomainModel 引用。提交后派发前用 converter 转出独立快照，防止后续 domain model 修改污染消息内容。

**推荐**：AppService / 事件发布器通过 `PaymentGatewayConverter.toNotifyCommand(payOrder)` 转换出 `PaymentNotifyCommand`（位于 app 层），再由 `TradeNotifyGateway` 消费。

```java
// 正确：提交后派发时用 converter 转出 app 层 command 快照
tradeNotifyGateway.notifyPaymentResult(PaymentGatewayConverter.toPaymentNotifyCommand(payOrder));

// 错误：直接传递 domain model 引用（后续状态变化会污染消息）
tradeNotifyGateway.notifyPaymentResult(payOrder);
```

> 关联规则：ARCH-02 依赖方向（domain 类型不应出现在 MQ 消息载荷）；ARCH-17 业务语义 Gateway。

---

## INT-18: 落库先于外发

**MUST** 涉及资金 / 渠道侧状态副作用的外发动作（渠道支付发起、下游通知等）之前，先推进到"已提交"态（`transferStatusByEvent(SUBMIT)`，不依赖任何外部结果）并持久化到数据库；外发之后再根据渠道响应 / 回调二次落库更新结果。

**MUST NOT** 先调外部渠道、后落库。外发成功但进程在写库前崩溃，会导致渠道侧已扣款 / 已生效而本地无任何记录，无法对账，造成资损。

**与 INT-09 的区别**：INT-09 针对**无副作用的只读校验 / 查询**（`merchantGateway.check`、`channelGateway.queryQuota`），可在 PREPARE 阶段、任何 DB 写之前调用；INT-18 针对**有资金或渠道侧状态副作用的外发动作**（真正发起扣款 / 支付），要求外发前先有一次独立的落库。

流程：**幂等校验（命中抛重复交易，PS-15）→ 建初始单 + SUBMIT 推进到"已提交"态 → 事务①save（外发前先落库）→ 外发（事务外）→ handleResult（三段式翻译/推进/记录，PAYING → PAID/FAILED）→ 事务②save（落回执结果）→ 提交后按领域事件派发消息（INT-19）**。主流程用组合方法保持在 ~20 行内、可读。

```java
// 正确：两段 save，外发前先落库；主方法只留流程骨架（组合方法），消息派发下沉到事件发布器
public PaymentResult pay(PaymentCommand command) {
    // 幂等：命中已存在直接抛"重复交易"，不回捞返回（PS-15）
    assertNotDuplicate(command);
    // 建初始单并推进到"已提交"态
    PayOrder payOrder = buildInitOrder(command);
    payOrder.transferStatusByEvent(PayOrderEvent.SUBMIT);        // INIT → PAYING
    // 事务①：外发前先落库（防资损）
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder));
    // 外发（事务外）→ 三段式处理结果（翻译→推进→记录，推进即登记领域事件）
    PaymentResultInfo resultInfo = requestChannelPay(payOrder);
    paymentDomainService.handlePayResult(payOrder, resultInfo);
    // 事务②：落回执结果；提交后（事务块返回之后）按领域事件顺序派发消息（取代 isPaid 特判 + Runnable 收集，见 INT-19）
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.updateWithVersion(payOrder));
    paymentEventPublisher.publish(payOrder);
    return facadeConverter.toResult(payOrder);
}
// assertNotDuplicate / buildInitOrder / requestChannelPay 为私有步骤方法，主方法只读流程

// 错误：先外发，后落库——渠道调用成功、进程随即崩溃，则 payOrder 从未写入过 DB（资损，无法对账）
public PaymentResult pay(PaymentCommand command) {
    PayOrder payOrder = PayOrder.create(command);
    ChannelPayResult channelResult = channelPaymentGateway.pay(
            paymentGatewayConverter.toChannelPayCommand(payOrder));           // ❌ 外发先于任何落库
    PaymentResultInfo resultInfo = paymentGatewayConverter.toResultInfo(channelResult);
    paymentDomainService.handlePayResult(payOrder, resultInfo);
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder)); // 唯一一次 save，且在外发之后
    return paymentResultConverter.toResult(payOrder);
}
```

> 关联规则：INT-09（外部调用事务外，适用对象不同）；INT-02（回调 / 补偿兜底最终一致）；INT-06（梯度补偿查询依赖事务①落地的 PAYING 记录才能对账）；[`persistence.md`](persistence.md) PS-11 三段式服务模式；PS-15 幂等抛错；[`anti-patterns.md`](anti-patterns.md) AP-26；INT-19 领域事件派发。

## INT-19: 出站消息由领域事件在提交后派发（禁 isPaid 特判 + Runnable 收集）

**MUST** 出站消息（外部通知、内部异步驱动）由**领域事件**在事务提交后派发，**MUST NOT** 在主流程里用 `if (payOrder.isPaid())` 之类的**终态特判 + `List<Runnable>` 收集**决定发什么。理由:发消息的判定不是一个终态布尔——**中间态**（如 3DS 等待）要发挑战/跳转消息、微服务间**同步受理异步处理**靠消息推进,这些都需要按**状态转移**而非"是否成功"来决定。

机制（分三层,各守其职）:
1. **领域层 raise 事实**:聚合的唯一状态入口 `transferStatusByEvent` 每次成功转移都 raise 一条 `StatusChangedEvent(from, to, event, occurredAt)`（在 `BaseDomainModel` 统一实现）。事件是**领域事实**、瞬态(不入库)、`pullDomainEvents()` 排空;它**不是**编排 flag（`savedSuccessfully`/`needsNotify` 这类 app 簿记 MUST NOT 进模型,见 [`anti-patterns.md`](anti-patterns.md)）。
2. **app 层 map 事实→消息**:每业务一个 `XxxEventPublisher`,提交后排空聚合事件,按 `(from → to)` 路由到出站 Gateway,载荷为不可变快照(INT-17)。终态/中间态/异步受理态都在这张映射里扩展,不改主流程、不改领域模型。
3. **主流程只调一次** `xxxEventPublisher.publish(order)`,在事务块返回之后（即提交后）调用,保持 ~20 行。

```java
// domain：BaseDomainModel.transferStatusByEvent 内,转移成功后
raise(new StatusChangedEvent(this.previousStatus, this.currentStatus, event, this.updateAt));
public List<DomainEvent> pullDomainEvents() { /* 返回快照并清空 */ }

// app：PaymentEventPublisher —— "状态转移 → 出站消息" 映射
@Component
public class PaymentEventPublisher {
    public void publish(PayOrder payOrder) {                     // 调用点在提交后；发送失败 best-effort 记日志
        try { dispatch(payOrder); } catch (Exception e) { log.error("publish failed", e); }
    }
    private void dispatch(PayOrder payOrder) {
        for (DomainEvent e : payOrder.pullDomainEvents()) {
            if (e instanceof StatusChangedEvent sc) { route(sc, payOrder); }
        }
    }
    private void route(StatusChangedEvent sc, PayOrder payOrder) {
        if (sc.getTo() == PayOrderStatus.PAID) {                 // 终态:通知商户
            tradeNotifyGateway.notifyPaymentResult(gatewayConverter.toNotifyCommand(payOrder));
        }
        // WAIT_3DS → 3DS 消息;ACCEPTED → 触发下游异步处理;FAILED → 失败通知……按 to 态在此扩展
    }
}
```

约束与要点:
- **restore MUST NOT raise**:从 DB 回放走 `restoreStatus`(不经 `transferStatusByEvent`),不产生领域事件——回放是装载、不是业务转移。
- **提交后再发**的红线不变(INT-17/PS-12):事件在事务内 raise(纯内存)、事务块返回之后(提交后)顺序派发,无回调。
- **共享内核不引 Lombok**:`BaseDomainModel`/`DomainEvent`/`StatusChangedEvent` 在 `{system}-common`,该模块**无 Lombok**,getter 手写(勿加 `@Getter`)。
- **投递可靠性分档**:Level 1 内存派发(提交后直发,崩溃有丢失窗口,软通知可用);Level 2 **事务性 Outbox**(事件与聚合同事务落库、relay 可靠投递,资损敏感消息用,与 INT-18 资损纪律一致)。起步 Level 1,关键 topic 迁 Outbox。

> 关联规则:INT-17 不可变快照;INT-18 落库先于外发;[`persistence.md`](persistence.md) PS-12 提交后发送(顺序派发,不用回调);[`domain-modeling.md`](domain-modeling.md) DM-21 状态唯一入口(事件在此 raise);[`anti-patterns.md`](anti-patterns.md)（禁编排 flag 进模型）。
