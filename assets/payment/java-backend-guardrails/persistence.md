> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 持久化约束

> 适配 MySQL（MyBatis-Plus）。全景目录树 → [`reference-implementation.md`](reference-implementation.md)（trade-infra 目录树）。

---

## PO 设计

> PO = Persistent Object（DB 映射对象），类名 `*PO` 后缀，存放在 `{system}-infra` 模块 `po/` 子包下。
> **PO ↔ DomainModel Converter 位于 `{system}-infra/{biz}/converter/`**（不是 domain；违反者见 [`anti-patterns.md`](anti-patterns.md) AP-25）。

### PS-01: PO 仅做 DB 映射

**MUST NOT** 在 PO 中放置任何业务逻辑。PO 只包含：字段、`@TableField` 注解、JSON 辅助方法。

```java
// 正确：PO 只做 DB 映射
@TableName("pay_order")
public class PayOrderPO {
    @TableId(value = "id", type = IdType.AUTO)
    private Long id;
    @TableField("pay_order_no")
    private String payOrderNo;
    @TableField("amount_value")
    private BigDecimal amountValue;
    @TableField("amount_currency")
    private String amountCurrency;
    // 无任何业务方法
}

// 错误：PO 包含业务逻辑
public class PayOrderPO {
    public boolean canRefund() { ... }        // MUST NOT
    public void calculateChannelFee() { ... } // MUST NOT
}
```

### PS-02: 金额拆分存储

**MUST** Money 字段在 PO 中拆分为 `_value` + `_currency` 两列：

```java
@TableField("amount_value")
private BigDecimal amountValue;              // DECIMAL(18,2) 订单金额
@TableField("amount_currency")
private String amountCurrency;               // VARCHAR(8) 币种
@TableField("refunded_amount_value")
private BigDecimal refundedAmountValue;      // DECIMAL(18,2) 已退款金额
@TableField("refunded_amount_currency")
private String refundedAmountCurrency;       // VARCHAR(8) 币种
```

```sql
amount_value            DECIMAL(18,2)  NOT NULL COMMENT '订单金额',
amount_currency         VARCHAR(8)     NOT NULL COMMENT '订单币种',
refunded_amount_value   DECIMAL(18,2)  NOT NULL DEFAULT 0 COMMENT '已退款金额',
refunded_amount_currency VARCHAR(8)    NOT NULL COMMENT '已退款币种',
```

精度规则（仅法币）：CNY/USD/EUR → `DECIMAL(18, 2)`；JPY/KRW → `DECIMAL(18, 0)`。

### PS-03: JSON 字段处理

**MUST** 复杂嵌套对象使用 MySQL JSON 类型存储（非 PostgreSQL JSONB）：

```java
/** 扩展信息（JSON） */
@TableField(value = "ext_info", typeHandler = JacksonTypeHandler.class)
private String extInfo;

/** 渠道原始响应（JSON） */
@TableField(value = "channel_response", typeHandler = JacksonTypeHandler.class)
private String channelResponse;
```

```sql
ext_info        JSON  DEFAULT NULL COMMENT '扩展信息',
channel_response JSON DEFAULT NULL COMMENT '渠道原始响应',
```

**MUST NOT** 使用 PostgreSQL 专有的 JSONB 类型或 `JsonbTypeHandler`。

### PS-04: 审计字段

**MUST** 每张表包含以下审计字段：

```sql
version     INT          NOT NULL DEFAULT 0      COMMENT '乐观锁版本（用于版本校验）',
created_at  DATETIME(3)  NOT NULL DEFAULT NOW(3) COMMENT '创建时间（UTC）',
updated_at  DATETIME(3)  NOT NULL DEFAULT NOW(3) ON UPDATE NOW(3) COMMENT '更新时间（UTC）'
```

```java
@TableField("version")
private Integer version;
@TableField(value = "created_at", fill = FieldFill.INSERT)
private LocalDateTime createdAt;
@TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
private LocalDateTime updatedAt;
```

**MUST** UTC 时区处理在应用层完成，数据库存储 UTC 时间，使用 `DATETIME(3)` 而非 `TIMESTAMP`。

### PS-05: 表注解

**MUST** PO 类使用 `@TableName` 指定表名，禁止使用 schema 参数（MySQL 不支持 schema 隔离）：

```java
// 正确：MySQL 风格，无 schema 参数
@TableName("pay_order")
public class PayOrderPO { ... }

// 错误：PostgreSQL schema 风格，禁止
@TableName(value = "pay_order", schema = "trade")  // MUST NOT
```

---

## Mapper 与 SQL

> Mapper = MyBatis 数据访问接口，类名 `*Mapper` 后缀，存放在 `{system}-infra` 模块 `mapper/` 子包下，仅被同聚合 `RepositoryImpl` 引用（ARCH-04）。

### PS-17: 显式 SQL 写在 XML，禁止代码侧拼装

**MUST** 所有 DB 操作对应一条写在 XML mapper 中的、手写的显式 SQL 命名语句。**MUST NOT** 用 MyBatis-Plus 的代码侧条件构造器（`LambdaQueryWrapper`/`QueryWrapper`/`LambdaUpdateWrapper`/`UpdateWrapper`）在 Java 里拼装 SQL；**MUST NOT** 依赖 `BaseMapper` 泛型 CRUD（`selectById`/`selectList`/`selectOne(Wrapper)`/`insert`/`updateById`/`deleteById`）隐式生成 SQL。

原因：金融支付的每一条 SQL 都需可审计、可 review、可加 hint / 索引提示 / `FOR UPDATE`；代码侧拼装把 SQL 藏进 Java 表达式，评审看不到最终语句、DBA 无法审 SQL、执行计划不可控。显式 SQL 集中在 XML，是「SQL 即契约」。

```java
// 正确：Mapper 不继承 BaseMapper，每个操作声明显式方法
@Mapper
public interface PayOrderMapper {
    PayOrderPO selectByPayOrderNo(@Param("payOrderNo") String payOrderNo);
    PayOrderPO selectByPayOrderNoForUpdate(@Param("payOrderNo") String payOrderNo,
                                           @Param("version") Integer version);  // 带版本加锁，见 PS-06
    PayOrderPO selectByExternalOrderNo(@Param("merchantId") String merchantId,
                                       @Param("externalOrderNo") String externalOrderNo);
    int insertPayOrder(PayOrderPO po);
    int updateByVersion(PayOrderPO po);
}

// 错误：继承 BaseMapper + 代码侧 Wrapper 拼装
public interface PayOrderMapper extends BaseMapper<PayOrderPO> { }   // MUST NOT
PayOrderPO po = mapper.selectOne(new LambdaQueryWrapper<PayOrderPO>() // MUST NOT
        .eq(PayOrderPO::getPayOrderNo, payOrderNo));
mapper.insert(po);                                                   // MUST NOT（泛型 CRUD）
```

```xml
<!-- resources/mapper/payment/PayOrderMapper.xml：显式列清单，禁止 SELECT *；insert 显式列 + version 初值 0 + NOW(3) -->
<mapper namespace="com.example.trade.infra.payment.mapper.PayOrderMapper">
    <sql id="allColumns">
        id, pay_order_no, merchant_id, external_order_no,
        amount_value, amount_currency, current_status, previous_status,
        version, final_status_at, created_at, updated_at
    </sql>
    <select id="selectByPayOrderNo" resultType="com.example.trade.infra.payment.po.PayOrderPO">
        SELECT <include refid="allColumns"/> FROM pay_order WHERE pay_order_no = #{payOrderNo}
    </select>
    <insert id="insertPayOrder" parameterType="com.example.trade.infra.payment.po.PayOrderPO"
            useGeneratedKeys="true" keyProperty="id">
        INSERT INTO pay_order (pay_order_no, merchant_id, external_order_no,
            amount_value, amount_currency, current_status, previous_status, version, created_at, updated_at)
        VALUES (#{payOrderNo}, #{merchantId}, #{externalOrderNo},
            #{amountValue}, #{amountCurrency}, #{currentStatus}, #{previousStatus}, 0, NOW(3), NOW(3))
    </insert>
</mapper>
```

配置（`application.yml`）：`mybatis-plus.mapper-locations: classpath*:mapper/**/*.xml` 定位 XML；`configuration.map-underscore-to-camel-case: true` 使 snake_case 列自动映射到驼峰属性。

补充约定：
- 保留 PO 的 `@TableName`/`@TableId`/`@TableField` 作为列元数据（不参与查询拼装，允许）。AppBoot dal starter 仍可存在；只是 MyBatis-Plus 的代码侧 CRUD/Wrapper 能力禁止使用。
- 时间列不依赖 MyBatis-Plus 自动填充（`FieldFill`）——由 XML 的 `NOW(3)` 显式落库，避免「隐式行为」。
- 每条 `<select>` 用显式列清单（`<sql>` 片段复用），**MUST NOT** `SELECT *`。
- L1 检测：ArchUnit 断言无 Mapper `extends BaseMapper`；PMD XPath 断言 infra 层无 `*Wrapper` 导入/构造。见 [`../../feedback/java-app/archunit/archunit-rules.md`](../../feedback/java-app/archunit/archunit-rules.md)、[`../../feedback/java-app/pmd/pmd-rules.xml`](../../feedback/java-app/pmd/pmd-rules.xml)，反例见 [`anti-patterns.md`](anti-patterns.md) AP-27。

---

## 锁策略

### PS-06: 悲观锁优先（FOR UPDATE MUST 带版本条件）

**MUST** 金融数据更新使用悲观锁 `SELECT ... FOR UPDATE`；且该 `FOR UPDATE` 语句 **MUST** 在 `WHERE` 中带 `version` 条件。

**version 从何而来（关键）**：金融「改」的流程一定是先**查出来**、做业务判断与运算、再**更新**——所以到了更新这一步、要加锁读时，聚合的 `version` 早已在手（来自前面那次业务查询）。`FOR UPDATE` 就用这个已持有的 version 作条件加锁：若在「判断/运算」期间该行被并发改动，version 已变，`FOR UPDATE` 锁不到（返回空）→ 判为版本冲突。这不是仓储内部再补一次读，而是把业务流程里既有查询拿到的 version 一路带到加锁读。

标准流程（读 → 判断/运算 → 加锁读 → 推进 → 更新）：

```java
// PREPARE（事务外）：先普通查询，拿到聚合与其 version，做业务判断/运算
PayOrder payOrder = payOrderRepository.getByPayOrderNo(payOrderNo);
FinAssert.notNull(payOrder, ResultCode.ORDER_NOT_FOUND, "payOrderNo=" + payOrderNo);
FinAssert.isTrue(payOrder.canRefund(), ResultCode.ORDER_NOT_PAYABLE, "not refundable");
// ... 业务运算（构造退款单、金额计算等）...

// EXECUTE（事务内）：用前面已持有的 version 加锁读 → 推进 → 版本检查更新
transactionExecutor.executeWithoutResult(() -> {
    PayOrder locked = payOrderRepository.getByPayOrderNoForUpdate(payOrderNo, payOrder.getVersion());
    FinAssert.notNull(locked, ResultCode.DATA_VERSION_CONFLICT, "payOrderNo=" + payOrderNo); // 期间被并发改动
    paymentDomainService.applyXxx(locked, ...);   // 在锁定实例上推进状态/记账
    payOrderRepository.updateWithVersion(locked);
});
```

```java
// Repository 接口（{system}-domain/{biz}/repository/）：forUpdate 接收调用方已持有的 version
public interface PayOrderRepository {
    /** 普通查询（用于判断，返回含 version 的聚合） */
    PayOrder getByPayOrderNo(String payOrderNo);
    /** 带期望版本的排他锁查询：version 不符则返回 null（并发冲突） */
    PayOrder getByPayOrderNoForUpdate(String payOrderNo, Integer version);
}
```

```java
// Repository 实现（{system}-infra/{biz}/repository/）：直接按 (no, version) 加锁读，不做多余的内部再读
public PayOrder getByPayOrderNoForUpdate(String payOrderNo, Integer version) {
    PayOrderPO locked = payOrderMapper.selectByPayOrderNoForUpdate(payOrderNo, version);
    return locked == null ? null : payOrderConverter.toDomainModel(locked);
}
```

```java
// Mapper：forUpdate 方法 MUST 带 version 参数
PayOrderPO selectByPayOrderNoForUpdate(@Param("payOrderNo") String payOrderNo,
                                       @Param("version") Integer version);
```

```xml
<!-- 显式列清单（禁 SELECT *，见 PS-17）；WHERE MUST 带 version -->
<select id="selectByPayOrderNoForUpdate" resultType="...PayOrderPO">
    SELECT <include refid="allColumns"/>
    FROM pay_order
    WHERE pay_order_no = #{payOrderNo} AND version = #{version}
    FOR UPDATE
</select>
```

### PS-07: 版本检查

**MUST** UPDATE 语句携带版本检查：

```sql
UPDATE pay_order
SET current_status = #{currentStatus}, version = version + 1, updated_at = NOW(3)
WHERE pay_order_no = #{payOrderNo} AND version = #{version}
```

更新行数为 0 时抛出 `DataVersionConflictException` 异常：

```java
int updated = payOrderMapper.updateByIdWithVersion(entity);
FinAssert.isTrue(updated > 0,
        ResultCode.DATA_VERSION_CONFLICT, "Pay order version conflict, payOrderNo: " + payOrderNo);
```

### PS-08: 禁止乐观锁拦截器

**MUST NOT** 启用 MyBatis-Plus 的 `OptimisticLockerInnerInterceptor`。version 字段用于审计和二次校验，不走拦截器自动递增。

```java
// 正确：只配置必要拦截器（分页等），不加乐观锁
@Bean
public MybatisPlusInterceptor mybatisPlusInterceptor() {
    MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
    interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
    return interceptor;
}
```

---

## 事务管理

### PS-09: 使用 TransactionTemplate（app 层经 TransactionExecutor 封装）

**MUST** 用编程式事务模板管理事务边界（禁 `@Transactional`，见 PS-10）。**MUST** 在应用层通过自定义
`TransactionExecutor`（封装 Spring 原生 `TransactionTemplate`、接口在 app / 实现在 infra）开启事务，**MUST NOT**
在应用服务里直接注入 `org.springframework.transaction.support.TransactionTemplate`——事务执行器统一承担异常翻译职责
（见 PS-18），避免每个调用点各自 try-catch 或让框架异常泄漏。

```java
// app 层：只依赖自定义 TransactionExecutor 端口，动作无返回值用 Runnable、有返回值用 Supplier
transactionExecutor.executeWithoutResult(() -> {
    // 事务内：仅 DB 操作（INSERT / UPDATE / SELECT FOR UPDATE）
    payOrderRepository.save(payOrder);
});
```

### PS-10: 禁止 @Transactional

**MUST NOT** 使用 `@Transactional` 注解。原因：事务边界不可见，容易引入长事务（外部调用被包进事务），且 Spring 代理机制在自调用场景下失效。

```java
// 错误
@Transactional
public void createPayOrder(CreatePayOrderCommand command) {
    channelGateway.check(command);      // 外部调用被包进事务 → 长事务
    payOrderRepository.save(payOrder);
    mqGateway.send(message);            // 事务回滚时消息已发
}
// 正确：见 PS-11 三段式模式
```

### PS-11: 三段式服务模式

**MUST** 涉及 DB 操作的方法遵循 PREPARE → EXECUTE → CONVERT 三段式：

```java
public PayOrderResponse createPayOrder(CreatePayOrderCommand command) {
    // ── PREPARE（事务外）──
    FinAssert.notNull(command.getAmount(), ResultCode.PARAM_ERROR, "Amount is required");
    ChannelResult channelResult = channelGateway.check(command.getMerchantId());
    PayOrder payOrder = PayOrder.create(command, channelResult);

    // ── EXECUTE（事务内，仅 DB 操作）──
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder));

    // ── CONVERT（事务提交之后，顺序外发）──
    // 能执行到此即事务已提交（失败会抛业务异常中断流程）；直接派发即"提交后发送"，无需事务回调
    payOrderEventPublisher.publish(payOrder);
    return payOrderResponseConverter.toResponse(payOrder);
}
```

> **外发型操作的两段 save**：若 EXECUTE 段之后还需要外发资金 / 渠道侧副作用的动作（渠道支付发起等），MUST NOT 直接外发——先在一次事务内落库（带幂等键），外发（事务外）拿到结果后，再用第二次事务落回执，提交后顺序派发通知。完整规则与正反例见 [`integration.md`](integration.md) INT-18、[`anti-patterns.md`](anti-patterns.md) AP-26、[`reference-implementation.md`](reference-implementation.md) §4。

### PS-12: 出站消息在事务提交后发送（提交后顺序派发，不用事务回调）

**MUST** 出站 MQ / 通知在本地事务提交后发送；**MUST NOT** 在事务内发送（回滚会产生幻象消息）。

**实现方式：把外发放在事务块返回之后顺序执行，不注册任何 afterCommit 回调。** 依据：app 层 `TransactionExecutor` 在落库/提交失败时抛 `FinException` 中断流程（PS-18），且独立提交自身事务——因此"执行到事务块之后"即"事务已提交"，顺序派发就是"提交后发送"。

- **MUST NOT** 使用 Spring 原生 `TransactionSynchronization.afterCommit()`（提交后连接未释放，长操作占用连接池）。
- **不需要**自定义 afterCommit 回调助手：无活动事务时它本就退化成 inline 执行，顺序派发已等价且更直观。
- **前置约束（MUST）**：编排方法 MUST NOT 运行在外层/环境事务中——否则 `TransactionExecutor` 会加入外层事务、不独立提交，"事务块之后即已提交"不再成立，破坏本规则与 INT-18「落库先于外发」。
- 出站失败**不回退**已提交业务：由发布器 best-effort 记日志，交重试/对账兜底。

```java
// EXECUTE（事务内，仅 DB 操作）→ 提交 → 顺序派发（提交后）
transactionExecutor.executeWithoutResult(() -> payOrderRepository.updateWithVersion(payOrder));
payOrderEventPublisher.publish(payOrder);   // 能到这行即已提交，直接发；发送异常在发布器内 best-effort 记日志
```

### PS-13: 事务执行时间

**SHOULD** 单次事务执行时间 ≤ 200ms。将外部调用（RPC、HTTP、渠道查询）放在事务外的 PREPARE 阶段。

### PS-18: 事务执行器翻译基础设施异常，禁止其穿越 app 边界

**事务边界在应用层**——一个事务可能同时写多张表（订单表 + 流水表），超出单个 Repository 的职责，Repository 也抓不到
提交/回滚期的异常。因此异常翻译 **MUST** 由应用层的 `TransactionExecutor` 统一承担，**MUST NOT** 放在 RepositoryImpl。

- **MUST** `TransactionExecutor` 捕获 `org.springframework.dao.DataAccessException` 与 `org.springframework.transaction.TransactionException`，翻译为携带业务码的 `FinException` 后抛出。
- **MUST NOT** 让 `org.springframework.dao.*` / `TransactionException` 等基础设施异常原始类型穿越应用层、泄漏到 facade（facade 模板只 catch `FinException`，裸框架异常会掉进兜底系统错误，丢失精确码，见 [`api.md`](api.md) API-13b）。
- **MUST** 业务异常 `FinException` 原样透传，不被重新包装（它不是 `DataAccessException`/`TransactionException`，自然不落入翻译 catch）。
- 高并发下最典型两类必须映射到明确码：并发唯一键冲突（幂等前置校验漏过后的并发 INSERT）、乐观锁版本冲突。

**异常翻译映射（java-app 标准）**：

| 基础设施异常 | 业务码 | 语义 |
|---|---|---|
| `DuplicateKeyException` | `ORDER_ALREADY_EXISTS` | 并发插入撞唯一业务键＝重复交易 |
| `OptimisticLockingFailureException` | `DATA_VERSION_CONFLICT` | 带 version 更新命中并发修改，提示重试 |
| `PessimisticLockingFailureException` / `QueryTimeoutException` | `SYSTEM_BUSY` | 行锁争用或查询超时，瞬时可重试 |
| 其它 `DataAccessException` / `TransactionException` | `SYSTEM_ERROR` | 数据访问失败与提交/回滚期事务异常 |

```java
// infra：TransactionExecutorImpl —— catch 顺序 具体→一般；FinException 不在其中，原样透传
@Override
public <T> T execute(Supplier<T> action) {
    try {
        return transactionTemplate.execute(status -> action.get());
    } catch (DuplicateKeyException e) {
        throw new FinException(ResultCode.ORDER_ALREADY_EXISTS, "duplicate key on persist", e);
    } catch (OptimisticLockingFailureException e) {
        throw new FinException(ResultCode.DATA_VERSION_CONFLICT, "optimistic lock conflict", e);
    } catch (PessimisticLockingFailureException | QueryTimeoutException e) {
        throw new FinException(ResultCode.SYSTEM_BUSY, "lock contention or query timeout", e);
    } catch (DataAccessException | TransactionException e) {
        throw new FinException(ResultCode.SYSTEM_ERROR, "database access failed", e);
    }
}
```

> **为何不包装事务执行、却包装异常翻译**：`TransactionTemplate` 的“执行”本身已是恰当抽象，直接用即可（PS-09）；但“把框架异常翻译成业务码”是一条要在所有事务边界统一强制的横切策略，且需覆盖 Repository 抓不到的提交期异常——满足“有横切策略才包装”的判据。反例是 afterCommit 回调助手：一旦事务边界收敛在执行器内、失败即抛异常中断，"提交后发送"退化为事务块之后的顺序调用，回调抽象不再承载任何独占策略，故删除（见 PS-12）。

---

## 幂等性

### PS-14: DB 唯一索引为最终保障

**MUST** 幂等性最终依赖数据库唯一索引，而非仅 Redis 分布式锁。

```sql
-- 支付幂等键：商户 + 外部订单号
ALTER TABLE pay_order ADD UNIQUE INDEX uk_merchant_ext_order (merchant_id, external_order_no);
```

### PS-15: 幂等处理流程（命中已存在 MUST 断言抛「重复交易」，MUST NOT 回捞本地数据返回）

**MUST** 创建操作遵循：先查询 → 命中已存在则**断言抛「重复交易」异常** → 不存在则创建 → DB 唯一索引兜底（PS-14）。

**MUST NOT** 在命中幂等键（如 `merchantId + externalOrderNo`）时，把本地已存在的订单回捞、转成结果**原样返回给上游**。原因：两次请求可能**单号相同、但其它参数（金额、币种等）不同**——直接返回本地记录会用「上一笔的数据」冒充「这一笔请求的结果」，误导上游、掩盖参数冲突。正确做法是抛出明确的「重复交易」错误，由上层（Facade）统一转成一个**明确的失败 Response**（见 [`api.md`](api.md) API-13b），让上游知道这是重复提交，而非成功。

```java
// PREPARE 阶段：命中已存在即断言抛错（FinAssert，业务语义），不回捞返回
PayOrder existing = payOrderRepository.getByExternalOrderNo(command.getMerchantId(), command.getExternalOrderNo());
FinAssert.isNull(existing, ResultCode.ORDER_ALREADY_EXISTS,
        "merchantId=" + command.getMerchantId() + ", externalOrderNo=" + command.getExternalOrderNo());
// 不存在 → 继续创建流程...
```

> DB 唯一索引（PS-14）是最终兜底：并发下两笔都通过了 PREPARE 查询时，第二笔 `INSERT` 触发唯一键冲突，同样以「重复交易」语义向上暴露（捕获唯一键异常转 `ORDER_ALREADY_EXISTS`），绝不静默吞掉或回捞返回。

---

## 索引设计

### PS-16: 索引分级

**MUST** 区分必需索引和可选索引：

| 级别 | 标准 | 示例 |
|------|------|------|
| 必需 | 唯一约束（幂等键） | `uk_merchant_ext_order` |
| 必需 | 高频查询路径（状态回调、结果查询） | `idx_pay_order_no` |
| 必需 | 定时任务扫描条件（超时关单、待请款扫描） | `idx_status_due_time` |
| 可选 | 中低频筛选、对账报表 | `idx_created_at` |

MySQL 索引设计规范：使用普通索引 + 查询条件优化，替代 PostgreSQL 部分索引；超时扫描等场景通过联合索引（status + due_time）等效实现。

```sql
ALTER TABLE pay_order ADD UNIQUE INDEX uk_merchant_ext_order (merchant_id, external_order_no);
ALTER TABLE pay_order ADD INDEX idx_pay_order_no (pay_order_no);
ALTER TABLE pay_order ADD INDEX idx_status_due_time (current_status, due_time);
```

**SHOULD NOT** 在 MySQL 中使用部分索引语法（MySQL 不原生支持，应改用联合索引 + 查询优化）。
