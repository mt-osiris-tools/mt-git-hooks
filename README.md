# mt-git-hooks

Local Git hooks to enforce Conventional Commits v1.0.0 with optional organization policies.

## What this repo installs

- `pre-commit`: blocks direct commits to `main`/`master`
- `commit-msg`: validates commit message format
- `post-commit`: optional AI use-case sync helper

Install hooks into the current repo clone:

```bash
./scripts/install-git-hooks.sh
```

## Commit Message Rule

By default, `commit-msg` requires a Jira-style prefix before a valid Conventional Commits header:

```text
LSFB-12345: feat(api): add tenant-aware endpoint
```

The Conventional Commits header is validated as:

```text
<type>[optional scope][optional !]: <description>
```

### Breaking changes

Supported syntaxes:

- Header marker: `feat!:` or `feat(scope)!:`
- Footer marker in body: `BREAKING CHANGE: <details>`

### Default allowed types

- `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `revert`

## Configuration

Configure behavior through environment variables:

- `MT_HOOK_REQUIRE_JIRA_PREFIX` (default: `true`)
- `MT_HOOK_JIRA_PATTERN` (default: `LSFB-[0-9]+`)
- `MT_HOOK_ALLOWED_TYPES` (default: `feat,fix,docs,style,refactor,perf,test,chore,revert`)
- `MT_HOOK_ENABLE_PROJECT_CHECKS` (default: `false`)
- `MT_HOOK_PROJECT_PROFILE` (default: `none`, supported: `medtrainer`)

Example: pure Conventional Commits (no Jira required):

```bash
export MT_HOOK_REQUIRE_JIRA_PREFIX=false
```

Example: enable MedTrainer profile checks:

```bash
export MT_HOOK_ENABLE_PROJECT_CHECKS=true
export MT_HOOK_PROJECT_PROFILE=medtrainer
```

## Examples

Valid (default policy):

- `LSFB-1001: feat(ui): add release banner`
- `LSFB-1002: fix(auth)!: remove legacy token fallback`
- `LSFB-1003: feat(api): migrate token format` with body containing `BREAKING CHANGE: clients must refresh tokens`

Invalid:

- `feat(api): add endpoint` (invalid when Jira prefix is required)
- `LSFB-1004: feature(api): add endpoint` (invalid type)
- `LSFB-1005: feat(api): add endpoint.` (allowed but warned for trailing period)

## Bypass

Client-side hooks can be bypassed with:

```bash
git commit --no-verify
```

Use sparingly.

## Validation Test Matrix

Run fixture tests for the `commit-msg` hook:

```bash
./scripts/test-commit-msg-hook.sh
```
