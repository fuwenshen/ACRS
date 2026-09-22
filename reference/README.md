# reference/ — 历史参考运行归档（L4 证据的一部分）

> 本目录回答一个问题：**ACRS 真的跑起来过吗？留痕在哪？**
> 这里存放**已发生**的参考运行完整归档——fixture、patch、测试日志、findings 全套证据，供回溯与交叉验证。

## 目录结构
```
reference/
└── joycode/
    ├── bugfix/          # bugfix 流程参考运行：两次 worker 尝试 + 独立 reviewer 验证，含 evidence/ 与 findings.md
    └── bugfix-reject/   # REJECT 路径参考运行：worker 产物被拒、丢弃重来的完整留痕（含 cli-binding 移植性记录）
```

## 每个参考运行的标准结构
- `fixture/` — 被修复的目标代码与测试（可复现）
- `evidence/` — patch、各角色测试日志、ledger（按时间序的决策账本）
- `findings.md` — 从该运行沉淀的问题与结论
- `RUN-LOG.md` — 运行全程记录

> 与 `../validation/` 的分工：validation 定义**怎么验证**（方法论与闸门），reference 存**已经跑过**的原始证据。
