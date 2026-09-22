#!/usr/bin/env bash
# ACRS 团队接入入口：写 ~/.acrs/path 指针（须在 ACRS 仓库内执行）
set -euo pipefail
cd "$(dirname "$0")"
exec bash bin/acrs init
