# Local Git Hooks

Reviewed: 2026-05-29

This is a short companion note. The canonical documentation for install, policy, config, examples, and release-boundary guidance lives in [README.md](README.md).

## What this repo installs

- `pre-commit`: blocks direct commits to `main` and `master`
- `commit-msg`: validates Conventional Commits with optional Jira-prefix enforcement
- `post-commit`: optional AI use-case sync helper

## When to read README.md

Use `README.md` for:

- installation and uninstall commands
- the Jira-prefix vs pure Conventional Commits choice
- release-boundary guidance for GitHub Actions and production deploys
- configuration variables
- examples and validation commands

## Local Reminder

This package is a local developer guardrail, not the production release system. GitHub Actions should own semantic release, image promotion, production deploys, and rollback.
