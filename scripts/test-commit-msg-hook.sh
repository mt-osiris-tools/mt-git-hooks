#!/bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/scripts/git-hooks/commit-msg"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass_count=0
fail_count=0

run_case() {
  local name="$1"
  local expected="$2"
  local envs="$3"
  local msg_file="$TMP_DIR/${name}.msg"

  cat > "$msg_file"

  local rc=0
  set +e
  if [ -n "$envs" ]; then
    env $envs "$HOOK" "$msg_file" >/dev/null 2>&1
    rc=$?
  else
    "$HOOK" "$msg_file" >/dev/null 2>&1
    rc=$?
  fi
  set -e

  if [ "$expected" = "pass" ] && [ "$rc" -eq 0 ]; then
    echo "PASS: $name"
    pass_count=$((pass_count + 1))
  elif [ "$expected" = "fail" ] && [ "$rc" -ne 0 ]; then
    echo "PASS: $name (expected failure)"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $name (expected $expected, rc=$rc)"
    fail_count=$((fail_count + 1))
  fi
}

run_case "pass_feat" "pass" "" <<'MSG'
feat: [LSFB-53603] add provider search endpoint
MSG

run_case "pass_fix" "pass" "" <<'MSG'
fix: [LSFB-53604] correct token expiration validation
MSG

run_case "pass_perf" "pass" "" <<'MSG'
perf: [LSFB-53605] reduce provider lookup query time
MSG

run_case "pass_chore" "pass" "" <<'MSG'
chore: [LSFB-53606] update framework dependency
MSG

run_case "pass_refactor" "pass" "" <<'MSG'
refactor: [LSFB-53607] simplify assignment signer validation
MSG

run_case "pass_docs" "pass" "" <<'MSG'
docs: [LSFB-53608] update API usage notes
MSG

run_case "pass_test" "pass" "" <<'MSG'
test: [LSFB-53609] add tests for signer ordering
MSG

run_case "pass_style" "pass" "" <<'MSG'
style: [LSFB-53610] format assignment service file
MSG

run_case "pass_ci" "pass" "" <<'MSG'
ci: [LSFB-53611] update release workflow cache
MSG

run_case "pass_build" "pass" "" <<'MSG'
build: [LSFB-53612] update package build config
MSG

run_case "pass_revert" "pass" "" <<'MSG'
revert: [LSFB-53613] revert provider search endpoint
MSG

run_case "pass_breaking_footer" "pass" "" <<'MSG'
feat: [LSFB-53614] replace assignment signer API

BREAKING CHANGE: remove the previous assignment signer contract
MSG

run_case "fail_missing_ticket" "fail" "" <<'MSG'
feat: add provider search endpoint
MSG

run_case "fail_old_prefix_format" "fail" "" <<'MSG'
LSFB-53603: feat: add provider search endpoint
MSG

run_case "fail_invalid_type" "fail" "" <<'MSG'
feature: [LSFB-53615] add provider search endpoint
MSG

run_case "fail_scope_not_allowed" "fail" "" <<'MSG'
feat(api): [LSFB-53616] add provider search endpoint
MSG

run_case "fail_header_bang_not_allowed" "fail" "" <<'MSG'
feat!: [LSFB-53617] replace assignment signer API
MSG

run_case "fail_bad_breaking_marker" "fail" "" <<'MSG'
feat: [LSFB-53618] replace assignment signer API

BREAKING-CHANGE: invalid marker style
MSG

run_case "pass_no_ticket_when_disabled" "pass" "MT_HOOK_REQUIRE_JIRA_PREFIX=false" <<'MSG'
feat: add provider search endpoint
MSG

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
