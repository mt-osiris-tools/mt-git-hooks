#!/bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
SOURCE_DIR="$ROOT_DIR/scripts/git-hooks"
TARGET_DIR="$ROOT_DIR/.git/hooks"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Hook template directory not found: $SOURCE_DIR" >&2
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Git hooks directory not found: $TARGET_DIR" >&2
    exit 1
fi

for hook in pre-commit commit-msg post-commit; do
    if [ ! -f "$SOURCE_DIR/$hook" ]; then
        echo "Missing hook template: $SOURCE_DIR/$hook" >&2
        exit 1
    fi

    cp "$SOURCE_DIR/$hook" "$TARGET_DIR/$hook"
    chmod +x "$TARGET_DIR/$hook"
done

echo "Installed local Git hooks into $TARGET_DIR"
