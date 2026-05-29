#!/bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
INSTALLER="$ROOT_DIR/scripts/install-via-curl.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass_count=0
fail_count=0

pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}

fail_case() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

RAW_BASE_DIR="$TMP_DIR/raw"
REF="testref"
SOURCE_HOOK_DIR="$RAW_BASE_DIR/$REF/scripts/git-hooks"
mkdir -p "$SOURCE_HOOK_DIR"
cp "$ROOT_DIR/scripts/git-hooks/pre-commit" "$SOURCE_HOOK_DIR/pre-commit"
cp "$ROOT_DIR/scripts/git-hooks/commit-msg" "$SOURCE_HOOK_DIR/commit-msg"
cp "$ROOT_DIR/scripts/git-hooks/post-commit" "$SOURCE_HOOK_DIR/post-commit"

TARGET_REPO="$TMP_DIR/target-repo"
mkdir -p "$TARGET_REPO"
git -C "$TARGET_REPO" init >/dev/null 2>&1

# 1) update should fail before install
set +e
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --update >/dev/null 2>&1
)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  pass "update fails before managed hooks exist"
else
  fail_case "update should fail before install"
fi

# 2) install should fail if one managed hook already exists and no --force
cp "$ROOT_DIR/scripts/git-hooks/pre-commit" "$TARGET_REPO/.git/hooks/pre-commit"
set +e
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --install >/dev/null 2>&1
)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  pass "install blocks overwrite without --force"
else
  fail_case "install should block overwrite without --force"
fi

# 3) install should succeed with --force and create backup
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --install --force >/dev/null
)
if [ -x "$TARGET_REPO/.git/hooks/pre-commit" ] && [ -x "$TARGET_REPO/.git/hooks/commit-msg" ] && [ -x "$TARGET_REPO/.git/hooks/post-commit" ]; then
  pass "install with --force creates executable managed hooks"
else
  fail_case "install with --force did not create expected hooks"
fi

if find "$TARGET_REPO/.git/hooks/mt-git-hooks-backups" -type f -name pre-commit | grep -q .; then
  pass "install with --force creates backup"
else
  fail_case "install with --force did not create backup"
fi

# 4) update should fail without --force
set +e
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --update >/dev/null 2>&1
)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  pass "update requires --force"
else
  fail_case "update should fail without --force"
fi

# 5) update should succeed with --force
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --update --force >/dev/null
)
pass "update succeeds with --force"

# 6) dry-run should enforce review gate when hooks already exist
set +e
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --install --dry-run >/dev/null 2>&1
)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  pass "dry-run enforces review gate without --force"
else
  fail_case "dry-run should enforce review gate without --force"
fi

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
