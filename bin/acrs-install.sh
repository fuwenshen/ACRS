#!/usr/bin/env bash
# acrs-install.sh — 把 ACRS 协作规范安装进一个目标项目
#
# 设计原则（与项目诚实底线一致）：
#   - 只安装【真实存在 binding】的平台：JoyCode（cli=🟢已验证 / app=🟡未实测编排）、
#     Claude Code（🟡 binding 已建，编排未实测跑 case）、
#     Codex（🟡 binding 已建：custom agent TOML 按官方 subagents 文档，编排未实测跑 case）。
#     Cursor 目前无 binding（⬜ ROADMAP Phase 5），脚本直接拒绝，绝不假装。
#   - 一律安装到目标项目的自包含目录 <project>/.acrs/（Claude Code 另加项目级
#     <project>/.claude/、Codex 另加 <project>/.codex/ + <project>/.agents/，
#     均为各平台官方扫描路径）。
#   - 幂等：可反复运行；入口 md（JOYCODE.md / CLAUDE.md）用 ACRS:BEGIN/END 标记块，
#     只更新标记内内容，不动你原有正文。
#   - --dry-run 只打印计划、不落盘。
set -euo pipefail

# --- 定位 ACRS 仓库根（脚本在 <repo>/bin/ 下）---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACRS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET=""
PLATFORM=""
DRY_RUN=0

usage() {
  cat <<'EOF'
用法：
  acrs-install.sh --target <项目目录> --platform <joycode-cli|joycode-app> [--dry-run]

参数：
  --target    目标项目根目录（把 ACRS 装进这里）
  --platform  入口平台：
                joycode-cli   🟢 已验证：用 root-prompt 让 CLI 会话遵守 ACRS
                joycode-app   🟡 设计意图：装 agent bundles + acrs-shared（App 编排时序未实测）
                claude-code   🟡 binding 已建：装项目级 .claude/{agents,skills} + CLAUDE.md 标记块
                codex         🟡 binding 已建：装项目级 .codex/agents + .agents/skills + AGENTS.md 标记块
                （两平台编排均未实测跑 case，机制按各自官方 subagents 文档）
  --dry-run   只打印将要做的动作，不实际写文件
  -h|--help   显示本帮助

说明：
  Cursor 目前【无 binding】（ROADMAP Phase 5），本脚本会拒绝安装——
  这是有意为之：不安装不存在的东西。
EOF
}

log()  { printf '  %s\n' "$*"; }
step() { printf '\n▶ %s\n' "$*"; }

# run <描述> <命令...>：dry-run 下只打印，否则执行
run() {
  local desc="$1"; shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $desc"
  else
    log "$desc"
    "$@"
  fi
}

# --- 解析参数 ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="${2:-}"; shift 2 ;;
    --platform) PLATFORM="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$TARGET" ]]   || { echo "错误：缺少 --target" >&2; usage; exit 2; }
[[ -n "$PLATFORM" ]] || { echo "错误：缺少 --platform" >&2; usage; exit 2; }

# --- 平台合法性：只认有真实 binding 的 ---
case "$PLATFORM" in
  joycode-cli|joycode-app|claude-code|codex) ;;
  cursor)
    echo "✗ 平台 '$PLATFORM' 目前【无 binding】（ROADMAP Phase 5 才建）。" >&2
    echo "  ACRS 拒绝安装不存在的 binding——这不是缺陷，是诚实边界。" >&2
    exit 3 ;;
  *)
    echo "✗ 不认识的平台：'$PLATFORM'" >&2; usage; exit 2 ;;
esac

[[ -d "$TARGET" ]] || { echo "错误：目标目录不存在：$TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"
DEST="$TARGET/.acrs"

echo "════════════════════════════════════════════════════"
echo " ACRS 安装器 v0.1"
echo "   源仓库 : $ACRS_ROOT"
echo "   目标   : $TARGET"
echo "   平台   : $PLATFORM"
[[ "$DRY_RUN" -eq 1 ]] && echo "   模式   : DRY-RUN（不写文件）"
echo "════════════════════════════════════════════════════"

# --- 复制一份目录/文件到 .acrs 下（保持子路径）---
copy_into() {
  local src="$1" rel="$2"
  local dst="$DEST/$rel"
  [[ -e "$ACRS_ROOT/$src" ]] || { echo "✗ 源缺失：$src" >&2; exit 4; }
  run "复制 $src → .acrs/$rel" bash -c "mkdir -p \"\$(dirname '$dst')\" && cp -R \"$ACRS_ROOT/$src\" \"$dst\""
}

# --- 公共产物：所有平台都要（Convention 是地基）---
step "① 安装公共产物到 .acrs/"
copy_into "skills/acrs/acrs-shared" "skills/acrs-shared"
copy_into "docs/mental-model.md" "docs/mental-model.md"
copy_into "docs/bootstrap.md"    "docs/bootstrap.md"
copy_into "docs/quick-start.md"  "docs/quick-start.md"

# --- Claude Code 接线：项目级 .claude/ 注册位 + CLAUDE.md 标记块 ---
wire_claude() {
  step "② CLAUDE 专属产物（项目级注册位，Claude Code 官方扫描路径）"
  local cd="$TARGET/.claude"
  run "mkdir -p $cd/agents $cd/skills" mkdir -p "$cd/agents" "$cd/skills"
  local s
  for s in "$ACRS_ROOT"/skills/acrs/*/; do
    [[ -d "$s" ]] || continue
    run "复制 skills/acrs/$(basename "$s") → .claude/skills/$(basename "$s")" cp -R "${s%/}" "$cd/skills/$(basename "$s")"
  done
  local f base
  for f in "$ACRS_ROOT"/bindings/claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f")
    run "复制 bindings/claude/agents/$base → .claude/agents/$base" cp "$f" "$cd/agents/$base"
  done

  step "③ 接线：在 CLAUDE.md 注入 ACRS 引用块（幂等）"
  inject_marker_block "CLAUDE.md" "$(cat <<'BLK'
<!-- ACRS:BEGIN （由 acrs-install.sh 管理，请勿在标记内手改）-->
## ACRS 协作规范（自动注入）

本项目采用 ACRS 多 Agent 协作规范。**任何会话/Agent 启动时，MUST 先加载并遵守**：

- 行为规范（必读，非可选）：`.acrs/skills/acrs-shared/SKILL.md`
- 运行心智模型（怎么跑）：`.acrs/docs/mental-model.md`
- 启动加载链（怎么起）：`.acrs/docs/bootstrap.md`

**用法**：研发类任务（设计/编码/测试/评审）派发给 ACRS 入口 agent——
`acrs-orchestrator`（总控调度，再由它分诊派发 acrs-architect/backend/solo/test/critic）。
Agent 定义见 `.claude/agents/`，能力 Skill 见 `.claude/skills/`（入口 agent 已预载 acrs-shared）。
<!-- ACRS:END -->
BLK
)"
}

# --- Codex 接线：项目级 .codex/agents + .agents/skills + AGENTS.md 标记块 ---
wire_codex() {
  step "② CODEX 专属产物（项目级注册位：.codex/agents 为官方 custom agent 路径，.agents/skills 为开放标准 skill 路径）"
  local cxd="$TARGET/.codex" ags="$TARGET/.agents"
  run "mkdir -p $cxd/agents $ags/skills" mkdir -p "$cxd/agents" "$ags/skills"
  local s
  for s in "$ACRS_ROOT"/skills/acrs/*/; do
    [[ -d "$s" ]] || continue
    run "复制 skills/acrs/$(basename "$s") → .agents/skills/$(basename "$s")" cp -R "${s%/}" "$ags/skills/$(basename "$s")"
  done
  local f base
  for f in "$ACRS_ROOT"/bindings/codex/agents/*.toml; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f")
    run "复制 bindings/codex/agents/$base → .codex/agents/$base" cp "$f" "$cxd/agents/$base"
  done

  step "③ 接线：在 AGENTS.md 注入 ACRS 引用块（幂等）"
  inject_marker_block "AGENTS.md" "$(cat <<'BLK'
<!-- ACRS:BEGIN （由 acrs-install.sh 管理，请勿在标记内手改）-->
## ACRS 协作规范（自动注入）

本项目采用 ACRS 多 Agent 协作规范。**任何会话/Agent 启动时，MUST 先加载并遵守**：

- 行为规范（必读，非可选）：`.acrs/skills/acrs-shared/SKILL.md`
- 运行心智模型（怎么跑）：`.acrs/docs/mental-model.md`
- 启动加载链（怎么起）：`.acrs/docs/bootstrap.md`

**用法**：研发类任务（设计/编码/测试/评审）委派给 ACRS 入口 custom agent——
`acrs-orchestrator`（总控调度，再由它分诊派发 acrs-architect/backend/solo/test/critic）。
Agent 定义见 `.codex/agents/`（TOML），能力 Skill 见 `.agents/skills/`
（开放标准，用 `$acrs-shared`、`$acrs-<role>` 显式触发加载）。
<!-- ACRS:END -->
BLK
)"
}

# --- 入口 md 标记块注入（JOYCODE.md / CLAUDE.md 共用，幂等替换 ACRS:BEGIN..END 区间）---
# 用法: inject_marker_block <文件名> <标记块内容>
inject_marker_block() {
  local mdname="$1" blkcontent="$2"
  local mdfile="$TARGET/$mdname"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] 将写入/更新 $mdfile 中的 ACRS 标记块"
    return
  fi

  # 标记块写进临时文件（避免把多行串经 awk -v 传入——BSD awk 会报 newline in string）
  local blkfile; blkfile="$(mktemp)"
  printf '%s\n' "$blkcontent" > "$blkfile"

  if [[ -f "$mdfile" ]] && grep -q "ACRS:BEGIN" "$mdfile"; then
    # 已有标记块 → 备份后替换标记区间（块内容由 getline 从文件读）
    cp "$mdfile" "$mdfile.acrs.bak"
    log "已备份 $mdfile → ${mdname}.acrs.bak"
    awk -v blkfile="$blkfile" '
      BEGIN { while ((getline line < blkfile) > 0) blk = blk line ORS }
      /ACRS:BEGIN/ { printf "%s", blk; skip=1; next }
      /ACRS:END/   { skip=0; next }
      !skip        { print }
    ' "$mdfile.acrs.bak" > "$mdfile"
    log "已更新 $mdname 中的 ACRS 标记块"
  else
    # 无标记块 → 追加（不动原有内容）
    { [[ -f "$mdfile" ]] && printf '\n'; cat "$blkfile"; } >> "$mdfile"
    log "已向 $mdname 追加 ACRS 标记块（原有内容未动）"
  fi
  rm -f "$blkfile"
}

# --- CLI 接线：JOYCODE.md 注入标记块 ---
wire_cli() {
  step "② CLI 专属产物"
  copy_into "bindings/joycode/cli/root-prompt.md" "cli/root-prompt.md"

  step "③ 接线：在 JOYCODE.md 注入 ACRS 引用块（幂等）"
  inject_marker_block "JOYCODE.md" "$(cat <<'BLK'
<!-- ACRS:BEGIN （由 acrs-install.sh 管理，请勿在标记内手改）-->
## ACRS 协作规范（自动注入）

本项目采用 ACRS 多 Agent 协作规范。**任何会话/Agent 启动时，MUST 先加载并遵守**：

- 行为规范（必读，非可选）：`.acrs/skills/acrs-shared/SKILL.md`
- 运行心智模型（怎么跑）：`.acrs/docs/mental-model.md`
- 启动加载链（怎么起）：`.acrs/docs/bootstrap.md`

**CLI 用法**：把 `.acrs/cli/root-prompt.md` 作为会话根提示词，即让本次 CLI 会话
以 Orchestrator→Backend→Review 的行为工作（证据留痕、独立验证、REJECT 重来）。
<!-- ACRS:END -->
BLK
)"
}

# --- App 接线：复制 bundles + 打印手动注册步骤（不谎称自动注册）---
wire_app() {
  step "② APP 专属产物（agent bundles + shared）"
  copy_into "bindings/joycode/app/agents" "app/agents"
  copy_into "bindings/joycode/app/shared" "app/shared"

  step "③ 接线说明（⚠️ 手动，不自动注册）"
  cat <<EOF
  JoyCode APP 的 Agent/Skill 注册多为 GUI 驱动，脚本不谎称能自动完成。请手动：
    1. 在 JoyCode APP 里导入 Agent bundles：$DEST/app/agents/{orchestrator,backend,review}
    2. 导入 Skill：$DEST/skills/acrs-shared （agent 的 on_init 会 MANDATORY 加载它）
    3. 选择 orchestrator 作为入口 Agent，开始任务
  🟡 诚实提醒：APP 原生 Agent-to-Agent 编排时序【尚未实测】（见 .acrs/... capability 缺口），
     跑通与否请如实记进 validation/production —— 这正是第一批该收集的 findings。
EOF
}

case "$PLATFORM" in
  joycode-cli) wire_cli ;;
  joycode-app) wire_app ;;
  claude-code) wire_claude ;;
  codex)       wire_codex ;;
esac

step "完成"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "  （dry-run：以上均未落盘。去掉 --dry-run 实际执行。）"
else
  echo "  ACRS 已安装到：$DEST"
  case "$PLATFORM" in
    joycode-cli) echo "  下一步：新开 JoyCode CLI 会话，粘贴 .acrs/cli/root-prompt.md 作为根提示词。" ;;
    claude-code) echo "  下一步：在项目里启动 claude，派发研发任务给 @acrs-orchestrator（定义在 .claude/agents/，已预载 .claude/skills/ 下的 acrs-shared）。" ;;
    codex)       echo "  下一步：在项目里启动 codex，委派研发任务给 acrs-orchestrator（定义在 .codex/agents/，skill 用 \$acrs-shared 显式触发）。" ;;
  esac
fi
