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

# add an unrelated hook to ensure uninstall does not remove it
printf '#!/bin/bash\necho pre-push\n' > "$TARGET_REPO/.git/hooks/pre-push"
chmod +x "$TARGET_REPO/.git/hooks/pre-push"

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

# 7) uninstall should fail without --force
set +e
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --uninstall >/dev/null 2>&1
)
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  pass "uninstall requires --force"
else
  fail_case "uninstall should fail without --force"
fi

# 8) uninstall with --force should remove only managed hooks and keep unrelated hooks
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --uninstall --force >/dev/null
)
if [ ! -f "$TARGET_REPO/.git/hooks/pre-commit" ] && [ ! -f "$TARGET_REPO/.git/hooks/commit-msg" ] && [ ! -f "$TARGET_REPO/.git/hooks/post-commit" ]; then
  pass "uninstall with --force removes managed hooks"
else
  fail_case "uninstall with --force did not remove all managed hooks"
fi

if [ -f "$TARGET_REPO/.git/hooks/pre-push" ]; then
  pass "uninstall leaves unmanaged hooks untouched"
else
  fail_case "uninstall should not remove unmanaged hooks"
fi

if find "$TARGET_REPO/.git/hooks/mt-git-hooks-backups" -type f -name commit-msg | grep -q .; then
  pass "uninstall with --force creates backup"
else
  fail_case "uninstall with --force did not create backup"
fi

# 9) uninstall no-op should succeed when managed hooks are absent
(
  cd "$TARGET_REPO"
  MT_GIT_HOOKS_RAW_BASE="file://$RAW_BASE_DIR" "$INSTALLER" --uninstall --force >/dev/null
)
pass "uninstall no-op succeeds when hooks are absent"

echo ""
echo "Results: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
