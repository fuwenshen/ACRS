#!/usr/bin/env bash
# acrs validate 测试套件（RFC-006 判据正反例；真实临时目录；退出码即断言）
# 跑法：bash test/validate/run.sh   →  exit 0 = 全绿
set -u
ACRS="$(cd "$(dirname "$0")/../.." && pwd)/bin/acrs"
PASS=0; FAIL=0
T="$(mktemp -d /tmp/acrs-validate-test.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# 断言器：expect <名字> <期望退出码> <期望输出片段(可选)> -- <命令...>
expect() {
  local name="$1" want_rc="$2" want_grep="$3"; shift 3; [[ "${1:-}" == "--" ]] && shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ "$rc" == "$want_rc" ]] && { [[ -z "$want_grep" ]] || grep -q "$want_grep" <<<"$out"; }; then
    PASS=$((PASS+1)); echo "  PASS  $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL  ${name}（rc=${rc} 期望=${want_rc}）"; sed 's/^/        | /' <<<"$out" | head -6
  fi
}

mkdir -p "$T/proj/.acrs/handoff" "$T/proj/src/test"
H="$T/proj/.acrs/handoff/task-001.json"   # RFC-006 C1 标准布局：上推两级=项目根
: > "$T/proj/src/test/ExistsTest.java"
cat > "$H" <<'EOF'
{
  "task_id": "task-001",
  "target_agent": "Backend",
  "entry_type": "new-module",
  "grounding_mode": "full",
  "environment": { "prerequisites": ["JDK 17"], "commands": [], "run_steps": [], "sensitive_domains": ["payment"] },
  "constraints": { "sensitive_domains": ["payment"] },
  "injected_artifacts": [ { "type": "reference", "path": "assets/java/style.md", "version": "1.0", "status": "FROZEN" } ],
  "design_checklist": [
    { "id": "DC-01", "desc": "当金额>0→校验币种→期望拒绝空币种", "sensitive": true },
    { "id": "DC-02", "desc": "当入参合法→落库→期望返回 id", "sensitive": false }
  ],
  "existing_test_files": [ "src/test/ExistsTest.java" ],
  "acceptance_criteria": [ "全部 DC 通过" ]
}
EOF

# 派生 fixture 的通用改写器：mut <out> <python表达式...>
mut() { local out="$1"; shift; python3 - "$H" "$out" "$@" <<'PYEOF'
import json, sys
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
exec(sys.argv[3])
json.dump(d, open(out, "w"), ensure_ascii=False)
PYEOF
}

# ---------- C6 用法 / C3-C5 fail-closed ----------
expect "usage-no-arg 退出码2"            2 "用法"              -- bash "$ACRS" validate
expect "C3 注入包不存在→exit1"            1 "C3"                -- bash "$ACRS" validate "$T/nope.json"
echo '{broken' > "$T/bad.json"
expect "C3 JSON 解析失败→exit1"           1 "C3"                -- bash "$ACRS" validate "$T/bad.json"
expect "C3 result 不存在→exit1"           1 "C3"                -- bash "$ACRS" validate "$H" --result "$T/nope.json"

# ---------- V1 正例 ----------
expect "合法注入包→exit0"                 0 "0 ERROR"            -- bash "$ACRS" validate "$H"

# ---------- V1 反例（逐条对应 RFC-006 §3.2）----------
mut "$T/v11.json" 'd["task_id"]=""'
expect "V1.1 task_id 空→exit1"            1 "V1.1"              -- bash "$ACRS" validate "$T/v11.json"
mut "$T/c2.json" 'd["task_id"]="../escape"'
expect "C2 task_id 路径穿越→exit1"         1 "C2"                -- bash "$ACRS" validate "$T/c2.json"
mut "$T/v12w.json" 'del d["environment"]'
expect "V1.2 environment 缺失→exit0+WARNING" 0 "V1.2"             -- bash "$ACRS" validate "$T/v12w.json"
mut "$T/v12e.json" 'd["environment"]["prerequisites"]=[]'
expect "V1.2 空 prerequisites→exit1"       1 "V1.2"              -- bash "$ACRS" validate "$T/v12e.json"
mut "$T/v13.json" 'd["grounding_mode"]="ultra"'
expect "V1.3 非法 grounding_mode→exit1"    1 "V1.3"              -- bash "$ACRS" validate "$T/v13.json"
mut "$T/v14.json" 'd["injected_artifacts"][0]["status"]="DRAFT"'
expect "V1.4 DRAFT 资产注入→exit1"          1 "V1.4"              -- bash "$ACRS" validate "$T/v14.json"
mut "$T/v15dup.json" 'd["design_checklist"][1]["id"]="DC-01"'
expect "V1.5 DC id 重复→exit1"              1 "V1.5"              -- bash "$ACRS" validate "$T/v15dup.json"
mut "$T/v15s.json" 'd["design_checklist"][0]["sensitive"]="yes"'
expect "V1.5 sensitive 非布尔→exit1"       1 "V1.5"              -- bash "$ACRS" validate "$T/v15s.json"
mut "$T/w12.json" 'd["existing_test_files"]=["src/test/NopeTest.java"]'
expect "W1.2 待建测试文件→exit0+WARNING"   0 "W1.2"              -- bash "$ACRS" validate "$T/w12.json"

# ---------- V2 result 闭环（RFC-006 §3.4）----------
cat > "$T/res-ok.json" <<'EOF'
{
  "status": "DONE",
  "checklist_coverage": [
    { "dc": "DC-01", "test_case": "PayTest#testCurrency" },
    { "dc": "DC-02", "test_case": "RepoTest#testSave" }
  ],
  "grounding": { "build_exit_code": 0, "test_exit_code": 0 }
}
EOF
expect "result 闭环合法→exit0"             0 "0 ERROR"            -- bash "$ACRS" validate "$H" --result "$T/res-ok.json"
cat > "$T/res-miss.json" <<'EOF'
{
  "status": "DONE",
  "checklist_coverage": [ { "dc": "DC-01", "test_case": "PayTest" } ],
  "grounding": { "test_exit_code": 0 }
}
EOF
expect "V2.2 缺 DC-02 覆盖→exit1"          1 "V2.2"              -- bash "$ACRS" validate "$H" --result "$T/res-miss.json"
cat > "$T/res-sensmiss.json" <<'EOF'
{
  "status": "PARTIAL",
  "checklist_coverage": [ { "dc": "DC-02", "test_case": "RepoTest#testSave" } ],
  "grounding": { "test_exit_code": 1 }
}
EOF
expect "V2.4 敏感DC缺测→exit1"             1 "V2.4"              -- bash "$ACRS" validate "$H" --result "$T/res-sensmiss.json"
cat > "$T/res-extra.json" <<'EOF'
{
  "status": "DONE",
  "checklist_coverage": [
    { "dc": "DC-01", "test_case": "a" }, { "dc": "DC-02", "test_case": "b" }, { "dc": "DC-99", "test_case": "c" }
  ],
  "grounding": { "build_exit_code": 0 }
}
EOF
expect "V2.2 引用不存在 DC→exit1"          1 "V2.2"              -- bash "$ACRS" validate "$H" --result "$T/res-extra.json"
cat > "$T/res-nocode.json" <<'EOF'
{
  "status": "DONE",
  "checklist_coverage": [ { "dc": "DC-01", "test_case": "a" }, { "dc": "DC-02", "test_case": "b" } ],
  "grounding": { "note": "跑过了" }
}
EOF
expect "V2.5 无退出码的完成=违约→exit1"     1 "V2.5"              -- bash "$ACRS" validate "$H" --result "$T/res-nocode.json"

# ---------- strict 档位（C6）----------
expect "默认 WARNING 放行→exit0"           0 "V1.2"              -- bash "$ACRS" validate "$T/v12w.json"
expect "--strict WARNING 阻断→exit1"      1 "strict"            -- bash "$ACRS" validate "$T/v12w.json" --strict

# ---------- --json 模式（DC-01/02）----------
expect "--json 正例→单行JSON exit0"          0 '"ok": true'        -- bash "$ACRS" validate "$H" --json
expect "--json 反例→ok:false exit1"           1 '"ok": false'       -- bash "$ACRS" validate "$T/v11.json" --json
expect "--json 反例 errors 带规则 id"         1 "V1.1"              -- bash "$ACRS" validate "$T/v11.json" --json
mut "$T/proj/.acrs/handoff/v12wj.json" 'del d["environment"]'
expect "--json WARNING 计入 warning_count"    0 '"warning_count": 1' -- bash "$ACRS" validate "$T/proj/.acrs/handoff/v12wj.json" --json
jsonl="$(bash "$ACRS" validate "$H" --json)"
if [[ "$(wc -l <<<"$jsonl" | tr -d ' ')" -eq 1 ]] && python3 -c 'import json,sys; json.loads(sys.argv[1])' "$jsonl" 2>/dev/null; then
  PASS=$((PASS+1)); echo "  PASS  --json 输出为单行合法 JSON"
else
  FAIL=$((FAIL+1)); echo "  FAIL  --json 输出为单行合法 JSON"; sed 's/^/        | /' <<<"$jsonl" | head -6
fi

# ---------- 汇总 ----------
echo "—— validate 测试: $PASS PASS, $FAIL FAIL"
[[ "$FAIL" -eq 0 ]]
