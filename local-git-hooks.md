# Local Git Hooks

Reviewed: 2026-05-29

This repository provides reusable local Git hooks, with Conventional Commits enforcement in `commit-msg` and optional project-specific checks.

## Installed Hooks

| Hook | Purpose |
| --- | --- |
| `pre-commit` | Blocks direct commits to `main` and `master` |
| `commit-msg` | Enforces Conventional Commits v1.0.0 header format and optional policy extensions |
| `post-commit` | Optionally triggers AI use-case sync script when `ai-use-cases/*.md` changes |

## Installation

Local clone install:

```bash
./scripts/install-git-hooks.sh
```

Curl installer (recommended pinned ref):

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --install
```

Update existing managed hooks:

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --update --force
```

Uninstall managed hooks:

```bash
./scripts/install-git-hooks.sh --uninstall --force
```

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --uninstall --force
```

## Install Safety Review

To avoid silent replacement/removal of managed hooks, installers enforce review before overwrite/uninstall:

- If `pre-commit`, `commit-msg`, or `post-commit` already exists, install/update stops by default.
- Uninstall stops by default when managed hooks exist.
- Installer output includes review commands/details before approval.
- Use `--force` to approve replacement/removal.
- Existing hooks are backed up in `.git/hooks/mt-git-hooks-backups/<timestamp>/` before overwrite or removal.

Examples:

```bash
./scripts/install-git-hooks.sh --force
```

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --install --force
```

## Confluence Alignment

Confluence semantic-versioning examples use pure Conventional Commit headers like `feat:` and `fix:`. This repository keeps Jira-prefix enforcement enabled by default, so equivalent messages are prefixed as:

```text
LSFB-12345: feat: add export endpoint
LSFB-12345: fix(api): resolve null response
```

Disable prefix enforcement with `MT_HOOK_REQUIRE_JIRA_PREFIX=false` to match pure Confluence examples directly.

## `commit-msg` Behavior

### Base rule

Validates this header shape:

```text
<type>[optional scope][optional !]: <description>
```

### Default policy extension

By default, a Jira-style prefix is required before the header:

```text
LSFB-12345: feat(scope): description
```

Set `MT_HOOK_REQUIRE_JIRA_PREFIX=false` to enforce pure Conventional Commits without the prefix.

### Breaking changes

Accepted formats:

- `type!:` or `type(scope)!:` in the header
- `BREAKING CHANGE: ...` in the commit body/footer

### Semantic versioning priority

When downstream release automation evaluates commits, priority follows:

1. major for breaking changes
2. minor for `feat`
3. patch for `fix` and lower-priority changes

### Optional profiles

Project-specific staged-file checks are disabled by default and can be enabled with:

```bash
export MT_HOOK_ENABLE_PROJECT_CHECKS=true
export MT_HOOK_PROJECT_PROFILE=medtrainer
```

When enabled for `medtrainer`, the hook adds migration and test-adjacency checks for `symfony/...` paths.

## Notes

- Hooks are local to each clone unless installed.
- Uninstall removes only managed hooks (`pre-commit`, `commit-msg`, `post-commit`) and leaves other hook files untouched.
- Hooks can be bypassed via `git commit --no-verify`.
- For release flows that depend on source SHA image validation, avoid squash merges for release-bound changes.
- Use `scripts/test-commit-msg-hook.sh` to run fixture validation quickly.
