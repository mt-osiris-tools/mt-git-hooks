# Commit Format

Reviewed: 2026-05-29

This repository uses the following default local commit format:

```text
<type>: [<ticket>] <short description>
```

Example:

```text
feat: [LSFB-53603] add provider search endpoint
```

When `MT_HOOK_REQUIRE_JIRA_PREFIX=false` is set, the hook accepts pure Conventional Commits without the ticket segment:

```text
<type>: <short description>
```

## Canonical Rule

The default header must match this shape:

```text
<type>: [<ticket>] <short description>
```

Where:

- `type` is one of the allowed commit types
- `ticket` matches `MT_HOOK_JIRA_PATTERN` and defaults to `LSFB-[0-9]+`
- `short description` is required and should be imperative

The hook does not allow the older `LSFB-12345: feat: description` format.
The hook also does not allow scopes or `!` markers in the header for this repository rule.

## Allowed Types and Release Intent

| Commit type | Release impact | Valid example | Meaning |
| --- | ---: | --- | --- |
| `feat` | **Minor** | `feat: [LSFB-53603] add provider search endpoint` | Adds a new user-facing or API capability |
| `fix` | **Patch** | `fix: [LSFB-53604] correct token expiration validation` | Fixes a bug |
| `perf` | **Patch** | `perf: [LSFB-53605] reduce provider lookup query time` | Improves performance without changing behavior |
| `chore` | **Patch**, only if approved by your rules | `chore: [LSFB-53606] update framework dependency` | Maintenance work that you allow to trigger a release |
| `refactor` | **Patch**, only if approved by your rules | `refactor: [LSFB-53607] simplify assignment signer validation` | Internal code change without feature or bug intent |
| `docs` | **No release**, usually | `docs: [LSFB-53608] update API usage notes` | Documentation-only change |
| `test` | **No release**, usually | `test: [LSFB-53609] add tests for signer ordering` | Test-only change |
| `style` | **No release**, usually | `style: [LSFB-53610] format assignment service file` | Formatting-only change |
| `ci` | **No release**, usually | `ci: [LSFB-53611] update release workflow cache` | CI/CD configuration change |
| `build` | **No release** or **Patch**, depending on rules | `build: [LSFB-53612] update package build config` | Build-system change |
| `revert` | **Patch**, usually | `revert: [LSFB-53613] revert provider search endpoint` | Reverts a previous production change |
| `BREAKING CHANGE` | **Major** | `feat: [LSFB-53614] replace assignment signer API` | Introduces an incompatible change |

Release impact is decided downstream by your release automation. This hook validates header format and allowed types only.

## Breaking Changes

Use a normal header with a `BREAKING CHANGE:` footer in the commit body.
Do not use `!` in the header.

Valid example:

```text
feat: [LSFB-53614] replace assignment signer API

BREAKING CHANGE: remove the previous assignment signer contract
```

Invalid example:

```text
feat!: [LSFB-53614] replace assignment signer API
```

## Invalid Examples

```text
feat: add provider search endpoint
LSFB-53603: feat: add provider search endpoint
feat(api): [LSFB-53603] add provider search endpoint
feature: [LSFB-53603] add provider search endpoint
```

## Pure Conventional Commits Mode

If a repository needs pure Conventional Commits for semantic release, disable the ticket requirement:

```bash
export MT_HOOK_REQUIRE_JIRA_PREFIX=false
```

In that mode the hook accepts headers like:

```text
feat: add provider search endpoint
fix: correct token expiration validation
```
