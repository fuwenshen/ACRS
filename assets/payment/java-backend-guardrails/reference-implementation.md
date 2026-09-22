> 【ACRS 资产】源：fin-buddy 工程规范 guardrails/java-app（commit 676aab9，2026-09-21 脱敏复制）。中间件/包名已通用化映射，映射表见本目录 [README.md](README.md)。文内指向 scaffolds / feedback / AGENTS.md / conventions 的相对链接属源仓库附件，未随资产分发。

# 参考实现 — Trade（交易）全景样例

> 本文档是 `reference-impl/`（`com.company.fin.share.core.*`）代码树的**设计说明书**，由后续 Agent 依此落地为可编译代码（契约 §3.5）。本文同时是**规则可视化入口**：每个关键写法后标注对应门禁规则 ID，供 Review / ArchUnit / Agent 自检时反查。
>
> 阅读顺序建议：先看 §1 模块树建立空间感 → §2 四聚合状态机对照 → §3 DomainService 三段式（本文件的核心）→ §4 端到端流程 → §5 写法↔规则映射表。

---

## 1. 模块树（trade 系统实例化 ARCH-01/04/05）

```
trade/
├── trade-client/    com.company.fin.share.core.client
├── trade-adapter/   com.company.fin.share.core.adapter
├── trade-app/       com.company.fin.share.core.app
├── trade-domain/    com.company.fin.share.core.domain
├── trade-infra/     com.company.fin.share.core.infra
├── trade-start/     com.company.fin.share.core.start
├── trade-common/    com.company.fin.share.kernel
└── trade-test/      com.company.fin.share.core.test
```

四个业务子域贯穿 domain/app/infra/adapter：`payment`（扣款）/ `preauth`（预授权）/ `capture`（请款）/ `refund`（退款）。具体骨架见 [`scaffolds/java-app/module-structure.md`](../../scaffolds/java-app/module-structure.md)；本文只展开 domain 层的聚合与 DomainService（架构其余部分复用 architecture.md，不重复）。

---

## 2. 四聚合状态机对照（DM-08 独立状态机）

| 聚合 | 状态枚举 | 事件枚举 | 关键状态 |
|------|---------|---------|---------|
| `PayOrder`（扣款单） | `PayOrderStatus` | `PayOrderEvent` | INIT/PAYING/PAID/FAILED/CLOSED |
| `PreAuthOrder`（预授权单） | `PreAuthOrderStatus` | `PreAuthOrderEvent` | INIT/AUTHING/**AUTHED**/**CAPTURING**/CAPTURED/AUTH_FAILED/CLOSED |
| `CaptureOrder`（请款单） | `CaptureOrderStatus` | `CaptureOrderEvent` | INIT/CAPTURING/CAPTURED/FAILED/CLOSED |
| `RefundOrder`（退款单） | `RefundOrderStatus` | `RefundOrderEvent` | INIT/**PREPARE_SUCC**/REFUNDING/REFUNDED/FAILED/CLOSED |

`PayOrderStatus`/`PayOrderEvent` 的完整定义见 [`domain-modeling.md`](domain-modeling.md) DM-03（本文不复制，避免双份权威）。以下补齐另外三个聚合：

### 2.1 PreAuthOrderStatus / PreAuthOrderEvent

```java
package com.company.fin.share.core.domain.preauth.statemachine;

public enum PreAuthOrderStatus implements BaseStatus {
    INIT("INIT", false, "初始化"),
    AUTHING("AUTHING", false, "授权中"),
    AUTHED("AUTHED", false, "授权成功"),       // 非终态：等待请款
    CAPTURING("CAPTURING", false, "请款中"),   // 已提交请款，等待渠道回执
    CAPTURED("CAPTURED", true, "已请款"),
    AUTH_FAILED("AUTH_FAILED", true, "授权失败"),
    CLOSED("CLOSED", true, "已关闭");

    private static final StateMachine<PreAuthOrderStatus, PreAuthOrderEvent> STATE_MACHINE = new StateMachine<>();
    static {
        STATE_MACHINE.accept(null,      PreAuthOrderEvent.CREATE,        INIT);
        STATE_MACHINE.accept(INIT,      PreAuthOrderEvent.SUBMIT,        AUTHING);
        STATE_MACHINE.accept(AUTHING,   PreAuthOrderEvent.AUTH_SUCCESS,  AUTHED);
        STATE_MACHINE.accept(AUTHING,   PreAuthOrderEvent.AUTH_FAIL,     AUTH_FAILED);
        STATE_MACHINE.accept(AUTHED,    PreAuthOrderEvent.CAPTURE_SUBMIT,     CAPTURING);
        STATE_MACHINE.accept(CAPTURING, PreAuthOrderEvent.CAPTURE_SUCCESS,    CAPTURED);
        STATE_MACHINE.accept(CAPTURING, PreAuthOrderEvent.CAPTURE_FAIL,       AUTHED);  // 请款失败退回 AUTHED，允许重试
        STATE_MACHINE.accept(AUTHED,    PreAuthOrderEvent.CANCEL,        CLOSED);
        STATE_MACHINE.accept(AUTHED,    PreAuthOrderEvent.TIMEOUT,       CLOSED);       // 授权令牌过期未请款
    }
}
```

**AUTHED 是非终态**：预授权成功后资金已冻结但未扣款，等待同步/异步请款触发 `CAPTURE_SUBMIT`（DM-08 强调此状态不得混入 `PayOrderStatus`）。

### 2.2 CaptureOrderStatus / CaptureOrderEvent

```java
package com.company.fin.share.core.domain.capture.statemachine;

public enum CaptureOrderStatus implements BaseStatus {
    INIT("INIT", false, "初始化"),
    CAPTURING("CAPTURING", false, "请款中"),
    CAPTURED("CAPTURED", true, "请款成功"),
    FAILED("FAILED", true, "请款失败"),
    CLOSED("CLOSED", true, "已关闭");

    private static final StateMachine<CaptureOrderStatus, CaptureOrderEvent> STATE_MACHINE = new StateMachine<>();
    static {
        STATE_MACHINE.accept(null,      CaptureOrderEvent.CREATE,         INIT);
        STATE_MACHINE.accept(INIT,      CaptureOrderEvent.SUBMIT,         CAPTURING);
        STATE_MACHINE.accept(CAPTURING, CaptureOrderEvent.CAPTURE_SUCCESS, CAPTURED);
        STATE_MACHINE.accept(CAPTURING, CaptureOrderEvent.CAPTURE_FAIL,    FAILED);
        STATE_MACHINE.accept(CAPTURING, CaptureOrderEvent.CANCEL,         CLOSED);
        STATE_MACHINE.accept(CAPTURING, CaptureOrderEvent.TIMEOUT,        CLOSED);
    }
}
```

`CaptureOrder` 是与 `PreAuthOrder` 独立的单据（一次预授权可能对应多次部分请款），二者状态**不互相复用**（DM-08）；`PreAuthOrder` 只记录聚合层面的 CAPTURING/CAPTURED，明细由 `CaptureOrder` 承载。

### 2.3 RefundOrderStatus / RefundOrderEvent

```java
package com.company.fin.share.core.domain.refund.statemachine;

public enum RefundOrderStatus implements BaseStatus {
    INIT("INIT", false, "初始化"),
    PREPARE_SUCC("PREPARE_SUCC", false, "预处理成功"),  // 已校验可退，等待请款成功或直接提交
    REFUNDING("REFUNDING", false, "退款中"),
    REFUNDED("REFUNDED", true, "退款成功"),
    FAILED("FAILED", true, "退款失败"),
    CLOSED("CLOSED", true, "已关闭");

    private static final StateMachine<RefundOrderStatus, RefundOrderEvent> STATE_MACHINE = new StateMachine<>();
    static {
        STATE_MACHINE.accept(null,         RefundOrderEvent.CREATE,          INIT);
        STATE_MACHINE.accept(INIT,         RefundOrderEvent.PREPARE_SUCCESS, PREPARE_SUCC);
        STATE_MACHINE.accept(PREPARE_SUCC, RefundOrderEvent.SUBMIT,          REFUNDING);
        STATE_MACHINE.accept(REFUNDING,    RefundOrderEvent.REFUND_SUCCESS,  REFUNDED);
        STATE_MACHINE.accept(REFUNDING,    RefundOrderEvent.REFUND_FAIL,     FAILED);
        STATE_MACHINE.accept(PREPARE_SUCC, RefundOrderEvent.CANCEL,          CLOSED);
        STATE_MACHINE.accept(PREPARE_SUCC, RefundOrderEvent.TIMEOUT,         CLOSED);  // 等待请款成功超时
    }
}
```

**PREPARE_SUCC 用途**：AUTH_CAPTURE 模式下，若请款尚未成功，退款先受理并进入 `PREPARE_SUCC`（等待请款成功后由 Scheduler/Consumer 驱动 `SUBMIT`）；SALE 模式下已扣款，`PREPARE_SUCC` 后可立即 `SUBMIT`。

**PayOrder 侧金额记录不经过事件**：`PayOrder.refundedAmount` 是业务字段，由 `RefundDomainService` 通过 `payOrder.setRefundedAmount(...)`（DM-01 定义的业务字段 setter）直接累加，**不**通过 `PayOrderEvent` 推进——因为退款不改变扣款单自身的支付状态（PAID 就是 PAID），只改变其"可退余额"这一业务事实。**MUST NOT** 为此新增 `PayOrderEvent.REFUND_XXX` 事件（会话误把该记录动作建模为状态事件是常见的理解偏差，须在 Review 时对照本节纠正）。

---

## 3. DomainService 三段式（本文档核心，DM-19）

### 3.1 数据载体（ResultInfo / Reason，domain 内纯 POJO）

```java
package com.company.fin.share.core.domain.payment.service;

/** 支付结果载体：AppService 从 ChannelPayResult 转换而来，domain 侧不感知渠道类型。 */
public class PaymentResultInfo {
    private String resultType;      // SUCCESS / FAILED
    private String channelOrderNo;
    private String stdErrorCode;         // 内部标准错误码（DM-22）
    private String stdErrorMessage;
    private String channelErrorCode;     // 渠道原始错误码（DM-22）
    private String channelErrorMessage;

    public boolean isSuccess()    { return "SUCCESS".equals(resultType); }
    public boolean isFailed()     { return "FAILED".equals(resultType); }
    // getChannelOrderNo() / getStdErrorCode() / getChannelErrorCode() 省略
}

/** 主动关闭扣款单的原因载体。 */
public class PaymentCloseReason {
    private final String code;
    private final String message;
    public PaymentCloseReason(String code, String message) { this.code = code; this.message = message; }
    // getCode() / getMessage() 省略
}
```

`XxxResultInfo`/`XxxReason` **MUST NOT** 依赖 app/infra 类型（不得出现 `ChannelPayResult`/Request DTO），否则违反 AP-24。

### 3.2 PaymentDomainService — 三段式实现

```java
package com.company.fin.share.core.domain.payment.service;

public class PaymentDomainServiceImpl implements PaymentDomainService {

    @Override
    public void handlePayResult(PayOrder payOrder, PaymentResultInfo resultInfo) {
        // ① 翻译：ResultInfo -> Event（私有方法，domain 内部完成语义映射）
        PayOrderEvent event = buildPayResultEvent(resultInfo);

        // ② 推进：调聚合根唯一入口（PAYING -> PAID/FAILED）
        payOrder.transferStatusByEvent(event);

        // ③ 记录：写入非状态字段
        recordPayResult(payOrder, resultInfo, event);
    }

    @Override
    public void closePayment(PayOrder payOrder, PaymentCloseReason closeReason) {
        payOrder.transferStatusByEvent(PayOrderEvent.CANCEL);
        payOrder.setFailReason(closeReason.getCode(), closeReason.getMessage());
    }

    private PayOrderEvent buildPayResultEvent(PaymentResultInfo resultInfo) {
        if (resultInfo.isSuccess()) return PayOrderEvent.PAY_SUCCESS;
        if (resultInfo.isFailed())  return PayOrderEvent.PAY_FAIL;
        throw new FinException("不支持的支付结果类型");
    }

    private void recordPayResult(PayOrder payOrder, PaymentResultInfo resultInfo, PayOrderEvent event) {
        if (PayOrderEvent.PAY_SUCCESS.equals(event)) {
            payOrder.setChannelOrderNo(resultInfo.getChannelOrderNo());
            return;
        }
        if (PayOrderEvent.PAY_FAIL.equals(event)) {
            payOrder.setFailReason(resultInfo.getFailCode(), resultInfo.getFailMessage());
        }
    }
}
```

**SUBMIT 事件由 AppService 直接触发**：`SUBMIT`（`INIT -> PAYING`）只由本地状态触发，不依赖任何外部结果、无需业务语义翻译，因此**不经 DomainService 包装**——由 AppService 在外发（渠道调用）之前、事务①落库之前，直接调用聚合根唯一入口 `payOrder.transferStatusByEvent(PayOrderEvent.SUBMIT)`（见 §4 `pay()` 示例）。`handlePayResult` 只处理外发之后、需要把外部结果翻译为事件的终态推进（`PAYING -> PAID/FAILED`）。两者职责边界为：**本地无需翻译的事件由 AppService 直接推进；外部结果需要翻译的事件由 DomainService 三段式封装**，不可颠倒——若把 `PAY_SUCCESS`/`PAY_FAIL` 在 `payOrder` 仍处于 `INIT` 时提前推进，会触发非法状态转移（见 `domain-modeling.md` 状态机定义：`PAY_SUCCESS`/`PAY_FAIL` 仅接受 `PAYING` 为起始态）。

**方法命名对照 DM-19**：`handlePayResult`/`closePayment` 是业务事件命名，不是 `pay()`/`close()`（后者是 AppService 层的用户意图命名）；`SUBMIT` 无外部结果需要翻译，不适用此命名族，由 AppService 直调状态机入口即可。

**MUST NOT** 出现：
```java
// ❌ AppService 为外部结果直接构造 Event 并推进状态 —— 绕过 DomainService 的翻译职责
PayOrderEvent event = channelResult.isSuccess() ? PayOrderEvent.PAY_SUCCESS : PayOrderEvent.PAY_FAIL;
payOrder.transferStatusByEvent(event);
```
AppService **MUST** 只调用 `paymentDomainService.handlePayResult(payOrder, resultInfo)` 完成外部结果的翻译，翻译逻辑封闭在 DomainService 内部。

**边界澄清**：上述"MUST 只调用 handlePayResult"针对的是**外部结果需要翻译**的场景（渠道返回的 success/fail → `PAY_SUCCESS`/`PAY_FAIL`）。对**本地、无外部结果、无需翻译**的事件（如 `SUBMIT`：`INIT -> PAYING`），AppService **MAY** 经聚合根唯一入口直接调用 `payOrder.transferStatusByEvent(PayOrderEvent.SUBMIT)`——这里没有"结果 → 事件"的语义映射需要 DomainService 封装，直接调用不构成绕过。

### 3.3 PreAuthDomainService — 双聚合协同示例

`handlePreAuthResult` 需要同时推进 `PayOrder`（扣款单，标记为 AUTH_CAPTURE 场景下暂不视为已扣款）与 `PreAuthOrder`（预授权单）：

```java
package com.company.fin.share.core.domain.preauth.service;

public class PreAuthDomainServiceImpl implements PreAuthDomainService {

    @Override
    public void handlePreAuthResult(PayOrder payOrder, PreAuthOrder preAuthOrder, PreAuthResultInfo resultInfo) {
        if (resultInfo.isSuccess()) {
            preAuthOrder.transferStatusByEvent(PreAuthOrderEvent.AUTH_SUCCESS);
            preAuthOrder.setChannelAuthToken(resultInfo.getChannelAuthToken());
            preAuthOrder.setAuthTokenExpiresAt(resultInfo.getExpiresAt());
            return;
        }
        if (resultInfo.isFailed()) {
            preAuthOrder.transferStatusByEvent(PreAuthOrderEvent.AUTH_FAIL);
            payOrder.transferStatusByEvent(PayOrderEvent.PAY_FAIL);
            preAuthOrder.setFailReason(resultInfo.getFailCode(), resultInfo.getFailMessage());
            return;
        }
        throw new FinException("不支持的预授权结果类型");
    }

    @Override
    public void handleCaptureSubmitted(PreAuthOrder preAuthOrder) {
        preAuthOrder.transferStatusByEvent(PreAuthOrderEvent.CAPTURE_SUBMIT);
    }

    @Override
    public void handleCaptureResult(PayOrder payOrder, PreAuthOrder preAuthOrder, CaptureResultInfo resultInfo) {
        if (resultInfo.isSuccess()) {
            preAuthOrder.transferStatusByEvent(PreAuthOrderEvent.CAPTURE_SUCCESS);
            payOrder.transferStatusByEvent(PayOrderEvent.PAY_SUCCESS);   // 请款成功 = 扣款单最终完成扣款
            payOrder.setChannelOrderNo(resultInfo.getChannelOrderNo());
            return;
        }
        preAuthOrder.transferStatusByEvent(PreAuthOrderEvent.CAPTURE_FAIL);  // 退回 AUTHED，允许重试
        preAuthOrder.setFailReason(resultInfo.getFailCode(), resultInfo.getFailMessage());
    }
}
```

**要点**：`handleCaptureResult` 中两个聚合根的事件不同名但语义关联（`CAPTURE_SUCCESS` vs `PAY_SUCCESS`）——这是**正常的跨聚合协同**，不是 DM-08 禁止的"状态混用"（混用指把 `CAPTURING` 这个状态值本身塞进 `PayOrderStatus`，而不是指跨聚合调用两次 `transferStatusByEvent`）。

### 3.4 RefundDomainService — 四段方法族

```java
package com.company.fin.share.core.domain.refund.service;

public class RefundDomainServiceImpl implements RefundDomainService {

    @Override
    public void acceptRefund(PayOrder payOrder, RefundOrder refundOrder, RefundAcceptInfo acceptInfo) {
        refundOrder.transferStatusByEvent(RefundOrderEvent.PREPARE_SUCCESS);
        payOrder.setRefundedAmount(payOrder.getRefundedAmount().add(acceptInfo.getRefundAmount()));  // 字段记录，非事件
    }

    @Override
    public void submitRefund(RefundOrder refundOrder) {
        refundOrder.transferStatusByEvent(RefundOrderEvent.SUBMIT);
    }

    @Override
    public void handleRefundResult(RefundOrder refundOrder, RefundResultInfo resultInfo) {
        RefundOrderEvent event = resultInfo.isSuccess() ? RefundOrderEvent.REFUND_SUCCESS : RefundOrderEvent.REFUND_FAIL;
        refundOrder.transferStatusByEvent(event);
        if (!resultInfo.isSuccess()) {
            refundOrder.setFailReason(resultInfo.getFailCode(), resultInfo.getFailMessage());
        }
    }

    @Override
    public void closeRefund(RefundOrder refundOrder, RefundCloseReason closeReason) {
        refundOrder.transferStatusByEvent(RefundOrderEvent.CANCEL);
        refundOrder.setFailReason(closeReason.getCode(), closeReason.getMessage());
    }
}
```

`acceptRefund` 是 DM-19 表格中 `acceptXxx` 命名族的示例：受理动作本身不代表退款已发生，只代表"校验通过、记账占用"，因此只推进 `RefundOrder` 到 `PREPARE_SUCC`，**不** 触碰 `PayOrder` 的状态机（只更新其 `refundedAmount` 字段）。

---

## 4. 端到端流程（AppService 编排，两段 save，见 INT-18）

`pay()` 涉及资金副作用的渠道外发，MUST 遵循 INT-18「落库先于外发」：外发前先落库（事务①），外发后二次落库更新回执结果（事务②），提交后（事务块返回之后）按领域事件顺序派发消息。主流程用组合方法保持在 ~20 行内。

```java
// trade-app/payment/service/impl/PaymentAppServiceImpl.java —— 组合方法，主流程只读骨架
public PaymentResult pay(PaymentCommand command) {
    // 幂等：命中已存在直接抛"重复交易"（PS-15，DB 唯一索引兜底 PS-14），不回捞返回——两请求可能单号同、其它参数不同
    assertNotDuplicate(command);
    // 建初始单（幂等键 payOrderNo 已就位，DM-14；command 入口即持 Money，DM-10）并推进到"已提交"态
    PayOrder payOrder = buildInitOrder(command);
    payOrder.transferStatusByEvent(PayOrderEvent.SUBMIT);   // INIT -> PAYING：本地事件无需翻译，直接调聚合根唯一入口
    // 事务①：外发前先落库（INT-18）。即使随后进程崩溃，DB 也已有该笔 PAYING 记录可供对账
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.save(payOrder));
    // 外发（事务外）→ 三段式封装在 domain：翻译→推进（PAYING→PAID/FAILED）→记录（推进即登记领域事件）
    PaymentResultInfo resultInfo = requestChannelPay(payOrder);
    paymentDomainService.handlePayResult(payOrder, resultInfo);
    // 事务②：落回执结果；提交后（事务块返回之后）按领域事件顺序派发消息（取代 isPaid 特判 + Runnable 收集，见 INT-19）
    transactionExecutor.executeWithoutResult(() -> payOrderRepository.updateWithVersion(payOrder));
    paymentEventPublisher.publish(payOrder);
    return facadeConverter.toResult(payOrder);
}
// assertNotDuplicate（命中抛 ORDER_ALREADY_EXISTS）/ buildInitOrder（command 已持 Money）/ requestChannelPay 为私有步骤方法，主方法只读流程
```

AppService **MUST NOT** 出现的写法：直接 `new PaymentResultInfo()` 手工赋值渠道字段（应由 converter 完成）、为**外部结果**直接构造 `PAY_SUCCESS`/`PAY_FAIL` 事件并调用 `transferStatusByEvent(...)`（绕过 `handlePayResult` 的翻译职责，见 §3.2 反例；`SUBMIT` 等无需翻译的本地事件允许直接调用，如上文 `pay()` 示例）、外发（`channelPaymentGateway.pay(...)`）先于事务①的 save（见 [`anti-patterns.md`](anti-patterns.md) AP-26）。

---

## 5. 关键写法 ↔ 门禁规则映射表

| 写法 | 对应规则 | 违反后果 |
|------|---------|---------|
| 聚合根仅暴露工厂方法/`transferStatusByEvent`/无副作用判断/业务字段 setter | DM-01 / DM-21 | 状态机校验被绕过，见 AP-22 |
| 状态推进用事件表驱动，不用 if-else/switch | DM-04 / DM-05 | Review 判违反；ArchUnit 可扫描 `setCurrentStatus` 调用点 |
| 4 聚合状态机互相独立，不混用状态值 | DM-08 | 见 §2.2 CaptureOrder 与 PreAuthOrder 独立性说明 |
| Event 枚举不持有渠道映射 Map | DM-08b | 渠道概念泄漏进 common，破坏分层 |
| PAY_FAIL 与 CANCEL/TIMEOUT 流向不同终态 | DM-08c | 对账/退款链路无法区分"未扣款撤销"与"已扣款冲正" |
| 全链路 `Money`，禁裸 `BigDecimal` | DM-09~13 | Checkstyle/PMD 自定义规则可检测字段类型 |
| 业务 ID 用 `BusinessIdGenerator`，禁 UUID/Snowflake 直用 | DM-14/15 | 见本文 §4 `pay()` 示例 |
| Converter 用 MapStruct，禁手写逐字段赋值 | DM-16 | PMD 自定义规则可检测赋值行数 |
| `{Entity}Converter` 放 infra，不带 `Domain` 后缀 | DM-17 / AP-25 | ArchUnit `GatewayRuleArchTest` 可检测包位置 |
| MoneyDTO 用 `long` 最小币种单位，domain 内用 `Money` | DM-18 | 跨模块传输精度丢失 |
| DomainService 用 `handleXxxResult`/`acceptXxx`/`closeXxx`；AppService 用 `pay`/`refund` | DM-19 | 命名倒置会模糊两层职责边界 |
| DomainService 方法内部三段式：翻译→推进→记录 | DM-19 / 本文 §3 | 缺翻译段会导致 Event 硬编码进 AppService |
| DomainService 参数仅 domain 内类型（`XxxResultInfo`） | AP-24 | domain 反向依赖 app/infra，见 anti-patterns.md |
| `initStatus()` 内必须设置 `INIT` | DM-20 | 聚合根创建后状态为 null，首次 `transferStatusByEvent` 报错 |
| Gateway 接口定义在 app，实现在 infra | ARCH-02 / ARCH-09 / ARCH-17 | app 反向依赖 infra，编译期 ArchUnit 拦截 |
| PO 无业务逻辑，业务行为在 DomainModel | ARCH-03 | Review 判违反 |
| adapter 只做接收 + 转换 + 调 AppService | ARCH-16 | adapter 查库/调渠道属于越权 |
| 外发（渠道支付发起）前先落库，回执后二次落库 | INT-18 | 外发成功、落库前崩溃则本地无记录，资损；见本文 §4 `pay()` 示例 |

---

## 6. 与其他文件的关系

- 状态机骨架代码（可直接复制）→ [`scaffolds/java-app/state-machine-template.md`](../../scaffolds/java-app/state-machine-template.md)
- 模块骨架 + pom 片段 → [`scaffolds/java-app/module-structure.md`](../../scaffolds/java-app/module-structure.md)
- `Money`/`FinAssert`/`FinException`/`BaseDomainModel` 等共享内核 API → [`scaffolds/java-app/shared-kernel/reference.md`](../../scaffolds/java-app/shared-kernel/reference.md)
- 反模式详单（本文 §3.2 反例的完整清单）→ [`anti-patterns.md`](anti-patterns.md) AP-22/AP-24
- 本文 §4 两段 save 的完整规则 + 与 INT-09 的区别 → [`integration.md`](integration.md) INT-18；反例 → [`anti-patterns.md`](anti-patterns.md) AP-26
- 实际可编译代码树 → `reference-impl/`（`com.company.fin.share.core.*`，由后续 Agent 依本文档落地，契约 §3.5）
