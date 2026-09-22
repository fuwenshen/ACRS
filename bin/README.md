# bin/ — 安装与运维工具

> 本目录放**可执行入口**：把 ACRS 从本仓库安装进目标项目的脚本。

## acrs-install.sh
把 ACRS 协作规范安装进一个目标项目：

```bash
./bin/acrs-install.sh --target <项目目录> --platform joycode-cli [--dry-run]
```

行为要点（与项目诚实底线一致）：
- **只装真实存在 binding 的平台**：JoyCode（cli 🟢 已验证 / app 🟡 未实测编排）；无 binding 的平台直接拒绝，绝不假装。
- **自包含落盘**：一律装到目标项目 `<project>/.acrs/`，不污染项目其它文件；删掉它项目照常构建。
- **幂等**：可反复运行；`JOYCODE.md` 只更新 `ACRS:BEGIN/END` 标记块，不动原有正文。
- `--dry-run` 只打印计划、不落盘。
