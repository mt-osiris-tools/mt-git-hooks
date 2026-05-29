#!/bin/bash

set -euo pipefail

MANAGED_HOOKS=(pre-commit commit-msg post-commit)
ACTION="install"
FORCE=false

usage() {
    cat <<USAGE
Usage: $0 [--install|--uninstall] [--force]

Options:
  --install    Install managed hooks (default)
  --uninstall  Remove managed hooks (requires --force)
  --force      Approve overwrite/remove and create backups
  -h, --help   Show this help
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
            --install)
                ACTION="install"
                ;;
            --uninstall)
                ACTION="uninstall"
                ;;
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
    local mode="$1"
    local target_dir="$2"
    local source_dir="$3"
    shift 3
    local hooks=("$@")

    if [ "$mode" = "install" ]; then
        echo "[mt-git-hooks] Existing managed hooks detected in $target_dir"
        for hook in "${hooks[@]}"; do
            echo "  - $target_dir/$hook"
            echo "    Review: diff -u \"$target_dir/$hook\" \"$source_dir/$hook\""
        done
        echo "[mt-git-hooks] Re-run with --force to approve overwrite with backups."
    else
        echo "[mt-git-hooks] Managed hooks scheduled for uninstall from $target_dir"
        for hook in "${hooks[@]}"; do
            echo "  - $target_dir/$hook"
        done
        echo "[mt-git-hooks] Re-run with --force to approve removal with backups."
    fi
}

backup_hooks() {
    local target_dir="$1"
    shift
    local hooks=("$@")

    [ "${#hooks[@]}" -gt 0 ] || return 0

    local backup_dir="$target_dir/mt-git-hooks-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    for hook in "${hooks[@]}"; do
        [ -f "$target_dir/$hook" ] || continue
        cp "$target_dir/$hook" "$backup_dir/$hook"
    done
    log "Backed up existing hooks to $backup_dir"
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

    if [ "$ACTION" = "install" ]; then
        if [ "${#existing[@]}" -gt 0 ] && [ "$FORCE" != true ]; then
            print_review_block "install" "$target_dir" "$source_dir" "${existing[@]}"
            exit 1
        fi

        if [ "${#existing[@]}" -gt 0 ]; then
            backup_hooks "$target_dir" "${existing[@]}"
        fi

        for hook in "${MANAGED_HOOKS[@]}"; do
            cp "$source_dir/$hook" "$target_dir/$hook"
            chmod +x "$target_dir/$hook"
        done

        log "Installed hooks into $target_dir: ${MANAGED_HOOKS[*]}"
        exit 0
    fi

    # uninstall
    if [ "${#existing[@]}" -eq 0 ]; then
        log "No managed hooks found to uninstall."
        exit 0
    fi

    if [ "$FORCE" != true ]; then
        print_review_block "uninstall" "$target_dir" "$source_dir" "${existing[@]}"
        exit 1
    fi

    backup_hooks "$target_dir" "${existing[@]}"
    for hook in "${existing[@]}"; do
        rm -f "$target_dir/$hook"
    done
    log "Uninstalled hooks from $target_dir: ${existing[*]}"
}

main "$@"
