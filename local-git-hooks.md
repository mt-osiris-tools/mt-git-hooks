# Local Git Hooks

Reviewed: 2026-05-14

This document describes the active Git hooks currently installed in the local repository checkout under `.git/hooks/`. These hooks are local to this clone and are not part of the tracked repository unless copied into version control separately.

## Hook Inventory

| Hook | Status | Trigger | Purpose |
| --- | --- | --- | --- |
| `pre-commit` | Active | Before a commit is created | Blocks direct commits to `main` and `master` |
| `commit-msg` | Active | After the commit message is written, before commit finalization | Validates commit message format and some staged-change conventions |
| `post-commit` | Active | After a commit succeeds | Syncs AI use case documentation when relevant files change |
| `*.sample` files | Inactive examples | Not used unless renamed and made executable | Default Git templates shipped with Git |

No custom `core.hooksPath` is configured in this checkout, so Git uses the default `.git/hooks/` directory.

## 1. `pre-commit`

File: `.git/hooks/pre-commit`

### Behavior

This hook checks the current branch name before a commit is created.

If the branch is `main` or `master`, it prints a formatted error block and exits with status `1`, which blocks the commit.

If the branch is anything else, it exits with status `0` and allows the commit.

### What it enforces

- Prevents direct commits to protected branches.
- Encourages a feature-branch workflow.
- Suggests branch naming examples:
  - `feature/your-feature-name`
  - `fix/description`
  - `docs/description`
  - `refactor/description`
  - `test/description`

### Bypass

The script itself documents `git commit --no-verify` as a bypass. That bypass skips all client-side Git hooks for the commit.

### Notes

- The hook uses `git symbolic-ref --short HEAD` to determine the branch name.
- Detached HEAD states will not match `main` or `master`, so the guard only applies when a branch name is available.
- The output is colorized and uses box-drawn formatting for visibility in terminals.

## 2. `commit-msg`

File: `.git/hooks/commit-msg`

### Behavior

This hook validates the commit message before Git finalizes the commit.

It reads the commit message from the path passed by Git, extracts the first line as the subject, and then runs a series of checks. Errors block the commit. Warnings do not block the commit, but they are printed for the user.

### Required format

The subject line must begin with a Jira ticket prefix in this form:

```text
LSFB-12345: type(scope): description
```

The hook expects:

- A ticket prefix like `LSFB-49966:`
- A conventional commit type such as `feat`, `fix`, or `refactor`
- An optional lowercase scope in parentheses
- A descriptive subject line

### Conventional Commits compliance

This hook is **Conventional Commits-inspired**, but it is **not strictly compliant** with v1.0.0 of the specification.

Reasons:

- The spec requires the commit message to start with `<type>[optional scope]: <description>`, while this hook requires an `LSFB-XXXXX:` prefix before the type.
- The spec allows breaking changes to be expressed with `!` in the type/scope prefix, but this hook rejects subjects such as `feat!: ...` because it only accepts `type(` or `type:` after the Jira prefix.
- The hook treats the Jira ticket as part of the required subject prefix, which is a project-specific extension rather than part of the standard.

What still matches the spec:

- The allowed types are mostly aligned with common Conventional Commits types.
- The hook encourages a subject line plus optional body.
- The hook warns when the body is not separated by a blank line.

### Validation rules

#### Errors

These conditions reject the commit:

- Missing `LSFB-XXXXX:` prefix
- Missing a valid conventional commit type
- Generic commit messages that mention file names directly, such as `Update Version20251202160545.php`
- WIP, temp, debug, or placeholder commit subjects
- Migration commits that use the older bundled `SET SESSION` pattern inside a single `addSql()` heredoc

#### Warnings

These conditions do not reject the commit, but they are reported:

- Missing scope
- Subject line longer than 100 characters
- Imperative mood issues, such as `added` or `fixed` instead of `add` or `fix`
- Excessive capitalization
- Subject ending with a period
- Missing blank line between subject and body
- Code changes without accompanying tests
- Multiple migrations in one commit
- Migration changes mixed with unrelated files

### Migration-specific checks

When staged files include paths under `symfony/src/Migrations/`, the hook performs extra checks:

- Warns if more than one migration file is staged
- Warns if migration files are committed with non-migration changes
- Rejects migrations that use the deprecated Pattern A style for `SET SESSION` statements inside `addSql()`

This aligns with the repository’s migration guidance that prefers explicit connection handling for multi-statement safety.

### Test-specific checks

When PHP source files are staged under `symfony/src/` and no files are staged under `symfony/tests/`, the hook warns that no tests were included.

This is only a warning, but it reinforces the repo’s TDD-first workflow.

### Output

After validation, the hook:

- Prints a failure summary and exits `1` if any errors were found.
- Prints a warning summary if warnings were found.
- Prints the validated commit message back to the terminal on success.

### Bypass

The hook suggests `git commit --no-verify` as the bypass.

### Notes

- The hook is Bash-based and relies on standard Unix tooling such as `grep`, `wc`, `sed`, and `git diff --cached`.
- It uses ANSI color codes and emoji in terminal output.
- The script is executable and intended to run locally on developer machines.

## 3. `post-commit`

File: `.git/hooks/post-commit`

### Behavior

This hook runs after a commit succeeds.

Its only active behavior is to look for an AI use cases sync script and run it when the last commit touched Markdown files under `ai-use-cases/`.

### Sync script lookup

The hook resolves the sync script in this order:

1. `AI_USECASES_SYNC_SCRIPT`
2. `AI_USECASES_DIR/sync-ai-use-cases.sh`
3. `$HOME/Documents/ai-use-case-hub/sync-ai-use-cases.sh`

If the script does not exist, the hook exits successfully and does nothing.

### Trigger condition

The hook checks the files modified by the most recent commit using `git diff-tree --no-commit-id --name-only -r HEAD`.

If any changed file matches:

```text
ai-use-cases/*.md
```

the hook prints a sync message and invokes the sync script with the repository root path.

### Failure behavior

If the sync script fails, the hook prints a warning but still exits successfully. The sync is non-fatal and does not block commits.

### Notes

- This hook is integration-oriented, not validation-oriented.
- It has no effect unless the external sync script is present.
- It is safe to leave in place even on machines without the AI use case hub checkout.

## 4. Installed Sample Hooks

The `.git/hooks/` directory also contains Git’s default `*.sample` files. These are not active unless renamed to hook names and made executable.

They are useful as reference material, but they are not part of the current enforcement path.

## 5. Practical Impact

In normal use, this local hook set creates the following workflow:

1. You are expected to commit from a feature branch, not from `main` or `master`.
2. Your commit subject must follow the `LSFB-XXXXX: type(scope): description` convention.
3. Migration commits are expected to follow the newer migration safety pattern.
4. Code changes should ideally include tests.
5. If you touch AI use case Markdown files, the post-commit hook attempts to sync them automatically.

## 6. Operational Caveats

- These hooks are local to this clone. A fresh clone will not have them unless they are copied or installed again.
- Hook behavior depends on executable permissions. The active scripts in this checkout are executable.
- `--no-verify` bypasses client-side commit hooks, so the checks are advisory unless enforced elsewhere.
- The `commit-msg` hook warns about several style issues, but only a subset are hard failures.

## 7. Recommended Maintenance

- Keep the Jira ticket prefix and conventional commit rules aligned with team policy.
- Revisit the migration checks when repository migration patterns change.
- Keep the `post-commit` sync path in sync with the real AI use case hub location if that external location changes.
- If these hooks should be shared across clones, consider tracking an installer script or a repo-managed hook path instead of relying on `.git/hooks/` manually.
