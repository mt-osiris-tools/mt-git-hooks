#!/bin/bash

set -euo pipefail

MANAGED_HOOKS=(pre-commit commit-msg post-commit)
FORCE=false

usage() {
    cat <<USAGE
Usage: $0 [--force]

Options:
  --force     Approve overwrite of existing managed hooks and create backups
  -h, --help  Show this help
USAGE
}

log() {
    echo "[mt-git-hooks] $*"
}

fail() {
    echo "[mt-git-hooks] ERROR: $*" >&2
    exit 1
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --force)
                FORCE=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                fail "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

print_review_block() {
    local target_dir="$1"
    local source_dir="$2"
    shift 2
    local hooks=("$@")

    echo "[mt-git-hooks] Existing managed hooks detected in $target_dir"
    for hook in "${hooks[@]}"; do
        echo "  - $target_dir/$hook"
        echo "    Review: diff -u \"$target_dir/$hook\" \"$source_dir/$hook\""
    done
    echo "[mt-git-hooks] Re-run with --force to approve overwrite with backups."
}

main() {
    parse_args "$@"

    local root_dir source_dir target_dir
    root_dir="$(git rev-parse --show-toplevel)"
    source_dir="$root_dir/scripts/git-hooks"
    target_dir="$root_dir/.git/hooks"

    [ -d "$source_dir" ] || fail "Hook template directory not found: $source_dir"
    [ -d "$target_dir" ] || fail "Git hooks directory not found: $target_dir"
    [ -w "$target_dir" ] || fail "Git hooks directory is not writable: $target_dir"

    local existing=()
    for hook in "${MANAGED_HOOKS[@]}"; do
        [ -f "$source_dir/$hook" ] || fail "Missing hook template: $source_dir/$hook"
        if [ -f "$target_dir/$hook" ]; then
            existing+=("$hook")
        fi
    done

    if [ "${#existing[@]}" -gt 0 ] && [ "$FORCE" != true ]; then
        print_review_block "$target_dir" "$source_dir" "${existing[@]}"
        exit 1
    fi

    local backup_dir=""
    if [ "${#existing[@]}" -gt 0 ]; then
        backup_dir="$target_dir/mt-git-hooks-backups/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        for hook in "${existing[@]}"; do
            cp "$target_dir/$hook" "$backup_dir/$hook"
        done
        log "Backed up existing hooks to $backup_dir"
    fi

    for hook in "${MANAGED_HOOKS[@]}"; do
        cp "$source_dir/$hook" "$target_dir/$hook"
        chmod +x "$target_dir/$hook"
    done

    log "Installed hooks into $target_dir: ${MANAGED_HOOKS[*]}"
}

main "$@"
