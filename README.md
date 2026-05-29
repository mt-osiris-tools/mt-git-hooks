# mt-git-hooks

Local Git hooks to enforce Conventional Commits v1.0.0 with optional organization policies.

## What this repo installs

- `pre-commit`: blocks direct commits to `main`/`master`
- `commit-msg`: validates commit message format
- `post-commit`: optional AI use-case sync helper

## Install Options

### Option 1: Local install from clone

```bash
./scripts/install-git-hooks.sh
```

### Option 2: Curl one-liner (tag-pinned)

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/v0.1.0/scripts/install-via-curl.sh | bash -s -- --ref v0.1.0 --install
```

### Update existing managed hooks

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/v0.1.0/scripts/install-via-curl.sh | bash -s -- --ref v0.1.0 --update
```

### Advanced examples

Install from `main` (non-reproducible):

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --install
```

Install to a custom hook path:

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/v0.1.0/scripts/install-via-curl.sh | bash -s -- --ref v0.1.0 --install --hooks-dir .githooks
```

Dry-run preview:

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/v0.1.0/scripts/install-via-curl.sh | bash -s -- --ref v0.1.0 --install --dry-run
```

Security note: review remote scripts before piping to shell.

## Confluence Alignment

This repository aligns with the Confluence semantic-versioning process:

- Confluence examples use pure Conventional Commits (`feat:`, `fix:`, `BREAKING CHANGE:`).
- This repository keeps a stricter default policy by requiring a Jira prefix before the same Conventional Commit header.

Mapping examples:

- Confluence: `feat: add export endpoint`
- Default here: `LSFB-12345: feat: add export endpoint`

- Confluence: `feat(auth)!: remove legacy flow`
- Default here: `LSFB-12345: feat(auth)!: remove legacy flow`

Set `MT_HOOK_REQUIRE_JIRA_PREFIX=false` to use Confluence-style pure headers directly.


## Install Safety Review

To avoid silently replacing existing hooks, installers now enforce a review gate:

- If `pre-commit`, `commit-msg`, or `post-commit` already exists, install/update stops by default.
- Review the suggested diff commands printed by the installer.
- Re-run with `--force` to approve overwrite.
- Existing hooks are backed up to `.git/hooks/mt-git-hooks-backups/<timestamp>/`.

Examples:

```bash
./scripts/install-git-hooks.sh --force
```

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/v0.1.0/scripts/install-via-curl.sh | bash -s -- --ref v0.1.0 --update --force
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

### Semantic-release priority model

Semantic versioning systems such as `semantic-release` evaluate all commits since the last tag and apply the highest-priority change type found:

1. major from breaking changes
2. minor from `feat` commits
3. patch from `fix` commits and lower-priority change types

### Default allowed types

- `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `revert`

## Configuration

Configure behavior through environment variables:

- `MT_HOOK_REQUIRE_JIRA_PREFIX` (default: `true`)
- `MT_HOOK_JIRA_PATTERN` (default: `LSFB-[0-9]+`)
- `MT_HOOK_ALLOWED_TYPES` (default: `feat,fix,docs,style,refactor,perf,test,chore,revert`)
- `MT_HOOK_ENABLE_PROJECT_CHECKS` (default: `false`)
- `MT_HOOK_PROJECT_PROFILE` (default: `none`, supported: `medtrainer`)
- `MT_GIT_HOOKS_REF` (curl installer default ref)
- `MT_GIT_HOOKS_VERSION` (alternate ref env var)
- `MT_GIT_HOOKS_RAW_BASE` (override raw host base URL)

Example: pure Conventional Commits (no Jira required):

```bash
export MT_HOOK_REQUIRE_JIRA_PREFIX=false
```

Example: enable MedTrainer profile checks:

```bash
export MT_HOOK_ENABLE_PROJECT_CHECKS=true
export MT_HOOK_PROJECT_PROFILE=medtrainer
```

## Release Flow Compatibility Note

If your downstream release/deployment flow resolves source images by commit SHA, avoid squash merges for release-bound changes. Squash can change commit lineage and break SHA-to-image alignment checks.

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
