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

# Build local raw source layout: <base>/<ref>/scripts/git-hooks/<hook>
RAW_BASE_DIR="$TMP_DIR/raw"
REF="testref"
SOURCE_HOOK_DIR="$RAW_BASE_DIR/$REF/scripts/git-hooks"
mkdir -p "$SOURCE_HOOK_DIR"
cp "$ROOT_DIR/scripts/git-hooks/pre-commit" "$SOURCE_HOOK_DIR/pre-commit"
cp "$ROOT_DIR/scripts/git-hooks/commit-msg" "$SOURCE_HOOK_DIR/commit-msg"
cp "$ROOT_DIR/scripts/git-hooks/post-commit" "$SOURCE_HOOK_DIR/post-commit"

# Temp git repo to install into
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

# 2) install should succeed
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --install >/dev/null
)
if [ -x "$TARGET_REPO/.git/hooks/pre-commit" ] && [ -x "$TARGET_REPO/.git/hooks/commit-msg" ] && [ -x "$TARGET_REPO/.git/hooks/post-commit" ]; then
  pass "install creates executable managed hooks"
else
  fail_case "install did not create expected hooks"
fi

# 3) update should succeed once installed
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --update >/dev/null
)
pass "update succeeds when managed hooks exist"

# 4) dry-run should succeed
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --ref "$REF" --install --dry-run >/dev/null
)
pass "dry-run succeeds"

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
