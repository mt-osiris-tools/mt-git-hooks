#!/bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
INSTALLER="$ROOT_DIR/scripts/install-git-hooks.sh"
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

TARGET_REPO="$TMP_DIR/target-repo"
mkdir -p "$TARGET_REPO/scripts/git-hooks"
git -C "$TARGET_REPO" init >/dev/null 2>&1

cp "$ROOT_DIR/scripts/git-hooks/pre-commit" "$TARGET_REPO/scripts/git-hooks/pre-commit"
cp "$ROOT_DIR/scripts/git-hooks/commit-msg" "$TARGET_REPO/scripts/git-hooks/commit-msg"
cp "$ROOT_DIR/scripts/git-hooks/post-commit" "$TARGET_REPO/scripts/git-hooks/post-commit"
chmod +x "$TARGET_REPO/scripts/git-hooks/pre-commit" "$TARGET_REPO/scripts/git-hooks/commit-msg" "$TARGET_REPO/scripts/git-hooks/post-commit"

# 1) clean install succeeds
(
  cd "$TARGET_REPO"
  "$INSTALLER" >/dev/null
)
if [ -x "$TARGET_REPO/.git/hooks/pre-commit" ] && [ -x "$TARGET_REPO/.git/hooks/commit-msg" ] && [ -x "$TARGET_REPO/.git/hooks/post-commit" ]; then
  pass "clean local install succeeds"
else
  fail_case "clean local install missing hooks"
fi

# 2) second install blocks without --force
set +e
(
  cd "$TARGET_REPO"
  "$INSTALLER" >/dev/null 2>&1
)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  pass "local install blocks overwrite without --force"
else
  fail_case "local install should block overwrite without --force"
fi

# 3) second install succeeds with --force and backup
(
  cd "$TARGET_REPO"
  "$INSTALLER" --force >/dev/null
)
pass "local install succeeds with --force"

if find "$TARGET_REPO/.git/hooks/mt-git-hooks-backups" -type f -name pre-commit | grep -q .; then
  pass "local install --force creates backup"
else
  fail_case "local install --force did not create backup"
fi

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
