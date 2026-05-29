# Local Git Hooks

Reviewed: 2026-05-29

This repository provides reusable local Git hooks, with Conventional Commits enforcement in `commit-msg` and optional project-specific checks.

## Installed Hooks

| Hook | Purpose |
| --- | --- |
| `pre-commit` | Blocks direct commits to `main` and `master` |
| `commit-msg` | Enforces Conventional Commits v1.0.0 header format and optional policy extensions |
| `post-commit` | Optionally triggers AI use-case sync script when `ai-use-cases/*.md` changes |

Install all hooks to `.git/hooks` using:

```bash
./scripts/install-git-hooks.sh
```

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

### Optional profiles

Project-specific staged-file checks are disabled by default and can be enabled with:

```bash
export MT_HOOK_ENABLE_PROJECT_CHECKS=true
export MT_HOOK_PROJECT_PROFILE=medtrainer
```

When enabled for `medtrainer`, the hook adds migration and test-adjacency checks for `symfony/...` paths.

## Notes

- Hooks are local to each clone unless installed.
- Hooks can be bypassed via `git commit --no-verify`.
- Use `scripts/test-commit-msg-hook.sh` to run fixture validation quickly.
