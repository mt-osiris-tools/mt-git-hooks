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

# Core behavior
run_case "pass_basic" "pass" "" <<'MSG'
LSFB-123: feat(api): add endpoint
MSG

run_case "pass_bang_breaking" "pass" "" <<'MSG'
LSFB-124: feat(auth)!: remove legacy auth
MSG

run_case "pass_footer_breaking" "pass" "" <<'MSG'
LSFB-125: feat(api): change token format

BREAKING CHANGE: clients must refresh tokens
MSG

run_case "fail_missing_jira" "fail" "" <<'MSG'
feat(api): add endpoint
MSG

run_case "fail_invalid_type" "fail" "" <<'MSG'
LSFB-126: feature(api): add endpoint
MSG

run_case "fail_bad_breaking_marker" "fail" "" <<'MSG'
LSFB-127: feat(api): change auth

BREAKING-CHANGE: invalid marker style
MSG

run_case "pass_no_scope" "pass" "" <<'MSG'
LSFB-128: fix: handle nil response
MSG

run_case "pass_scope_tokens" "pass" "" <<'MSG'
LSFB-129: feat(api-v2/auth_service): add route guard
MSG

run_case "pass_no_jira_when_disabled" "pass" "MT_HOOK_REQUIRE_JIRA_PREFIX=false" <<'MSG'
feat(core): add parser abstraction
MSG

# Confluence-aligned semantic examples (Jira default mode)
run_case "pass_confluence_patch_equivalent" "pass" "" <<'MSG'
LSFB-130: fix(auth): resolve null pointer in login
MSG

run_case "pass_confluence_minor_equivalent" "pass" "" <<'MSG'
LSFB-131: feat(export): add csv export endpoint
MSG

run_case "pass_confluence_major_equivalent" "pass" "" <<'MSG'
LSFB-132: feat(api): add new auth flow

BREAKING CHANGE: remove /auth/legacy endpoint
MSG

run_case "pass_confluence_mixed_major_equivalent" "pass" "" <<'MSG'
LSFB-133: fix(cache): avoid stale tenant config

BREAKING CHANGE: rename public api response fields
MSG

# Confluence pure-CC examples (prefix disabled mode)
run_case "pass_confluence_pure_patch" "pass" "MT_HOOK_REQUIRE_JIRA_PREFIX=false" <<'MSG'
fix: null pointer in login
MSG

run_case "pass_confluence_pure_minor" "pass" "MT_HOOK_REQUIRE_JIRA_PREFIX=false" <<'MSG'
feat: add export to csv
MSG

run_case "pass_confluence_pure_major" "pass" "MT_HOOK_REQUIRE_JIRA_PREFIX=false" <<'MSG'
feat: add new auth flow

BREAKING CHANGE: remove /auth/legacy
MSG

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
