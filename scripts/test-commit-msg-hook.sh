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

# 1) Pass: standard Jira + CC
run_case "pass_basic" "pass" "" <<'MSG'
LSFB-123: feat(api): add endpoint
MSG

# 2) Pass: breaking via !
run_case "pass_bang_breaking" "pass" "" <<'MSG'
LSFB-124: feat(auth)!: remove legacy auth
MSG

# 3) Pass: breaking via footer
run_case "pass_footer_breaking" "pass" "" <<'MSG'
LSFB-125: feat(api): change token format

BREAKING CHANGE: clients must refresh tokens
MSG

# 4) Fail: missing Jira (default policy)
run_case "fail_missing_jira" "fail" "" <<'MSG'
feat(api): add endpoint
MSG

# 5) Fail: invalid type
run_case "fail_invalid_type" "fail" "" <<'MSG'
LSFB-126: feature(api): add endpoint
MSG

# 6) Fail: malformed BREAKING marker
run_case "fail_bad_breaking_marker" "fail" "" <<'MSG'
LSFB-127: feat(api): change auth

BREAKING-CHANGE: invalid marker style
MSG

# 7) Pass: no scope
run_case "pass_no_scope" "pass" "" <<'MSG'
LSFB-128: fix: handle nil response
MSG

# 8) Pass: flexible scope tokens
run_case "pass_scope_tokens" "pass" "" <<'MSG'
LSFB-129: feat(api-v2/auth_service): add route guard
MSG

# 9) Pass: pure CC when Jira disabled
run_case "pass_no_jira_when_disabled" "pass" "MT_HOOK_REQUIRE_JIRA_PREFIX=false" <<'MSG'
feat(core): add parser abstraction
MSG

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
