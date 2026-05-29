# mt-git-hooks

Local Git hooks to enforce Conventional Commits v0.1.0 with optional organization policies.
This repo is a developer-side guardrail only; GitHub Actions owns semantic release, image promotion, production deploys, and rollback.

## What this repo installs

- `pre-commit`: blocks direct commits to `main`/`master`
- `commit-msg`: validates commit message format
- `post-commit`: optional AI use-case sync helper

## Commit Format Reference

The canonical commit format, release-intent examples, and pure Conventional Commits opt-out are documented in [COMMIT_FORMAT.md](COMMIT_FORMAT.md).
The default local rule is `<type>: [<ticket>] <short description>`.

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

### Uninstall managed hooks

```bash
./scripts/install-git-hooks.sh --uninstall --force
```

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/v0.1.0/scripts/install-via-curl.sh | bash -s -- --uninstall --force
```

### Advanced examples

Install from `main` (non-reproducible):

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --install
```

Install to a custom hook path:

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --install --hooks-dir .githooks
```

Dry-run preview:

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --install --dry-run
```

Security note: review remote scripts before piping to shell.

## Release Standard Boundary

This repo enforces local release intent only.

- `commit-msg` validates the `<type>: [<ticket>] <short description>` header and allowed types.
- `pre-commit` blocks direct local commits to protected branches.
- `post-commit` optionally syncs AI use-case notes.

GitHub Actions should implement the production release contract:

- validated artifact
- semantic version tag
- immutable promoted image
- manual production gate
- Pulumi `app.version`
- rollback to a previous release tag

If a repository uses pure Conventional Commits for semantic release, set `MT_HOOK_REQUIRE_JIRA_PREFIX=false`. If it keeps the ticket requirement locally, the release workflow must normalize commit subjects before version calculation.

## Install Safety Review

To avoid silently replacing or removing managed hooks, installers enforce a review gate:

- If `pre-commit`, `commit-msg`, or `post-commit` already exists, install/update stops by default.
- Uninstall also requires explicit approval.
- Review the suggested commands printed by the installer.
- Re-run with `--force` to approve overwrite/removal.
- Existing hooks are backed up to `.git/hooks/mt-git-hooks-backups/<timestamp>/`.

Examples:

```bash
./scripts/install-git-hooks.sh --force
```

```bash
curl -fsSL https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks/main/scripts/install-via-curl.sh | bash -s -- --ref main --update --force
```

```bash
./scripts/install-git-hooks.sh --uninstall --force
```

## Release Flow Compatibility Note

If your downstream release/deployment flow resolves source images by commit SHA, avoid squash merges for release-bound changes. Squash can change commit lineage and break SHA-to-image alignment checks.

## Production Release Checklist

Use this repo only to help keep commits releaseable. The actual production release workflow should verify:

1. The merged change has a validated artifact.
2. The release tag is a stable semantic version like `vX.Y.Z`.
3. The promoted image is immutable and traceable to the source commit.
4. Production deploy remains manual and tag-gated.
5. Pulumi records the deployed version in `app.version`.
6. Rollback reuses the same governed path with a previous release tag.

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
