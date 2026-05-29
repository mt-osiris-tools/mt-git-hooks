# Local Git Hooks

Reviewed: 2026-05-29

This is a short companion note. The canonical documentation for install, policy, config, examples, and release-boundary guidance lives in [README.md](README.md).

## What this repo installs

- `pre-commit`: blocks direct commits to `main` and `master`
- `commit-msg`: validates the `<type>: [<ticket>] <short description>` rule
- `post-commit`: optional AI use-case sync helper

## When to read README.md

Use `README.md` for:

- installation and uninstall commands
- the canonical commit rule and link to `COMMIT_FORMAT.md`
- release-boundary guidance for GitHub Actions and production deploys
- examples and validation commands

## Local Reminder

This package is a local developer guardrail, not the production release system. GitHub Actions should own semantic release, image promotion, production deploys, and rollback.
