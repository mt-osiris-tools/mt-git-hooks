#!/bin/bash

set -euo pipefail

MANAGED_HOOKS=(pre-commit commit-msg post-commit)
REPO_RAW_BASE_DEFAULT="https://raw.githubusercontent.com/mt-osiris-tools/mt-git-hooks"

ACTION="install"
REF="${MT_GIT_HOOKS_REF:-${MT_GIT_HOOKS_VERSION:-}}"
HOOKS_DIR=""
DRY_RUN=false
FORCE=false
RAW_BASE="${MT_GIT_HOOKS_RAW_BASE:-$REPO_RAW_BASE_DEFAULT}"

usage() {
    cat <<USAGE
Usage: $0 [--install|--update] [--ref <tag-or-branch>] [--hooks-dir <path>] [--dry-run] [--force]

Options:
  --install            Install managed hooks (default)
  --update             Update managed hooks; requires existing hooks and --force
  --ref <value>        Git ref (recommended: release tag)
  --hooks-dir <path>   Override hook destination directory
  --dry-run            Print actions without writing files
  --force              Approve overwrite and create backups for replaced hooks
  -h, --help           Show this help

Environment overrides:
  MT_GIT_HOOKS_REF
  MT_GIT_HOOKS_VERSION
  MT_GIT_HOOKS_RAW_BASE
USAGE
}

log() {
    echo "[mt-git-hooks] $*"
}

fail() {
    echo "[mt-git-hooks] ERROR: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

resolve_hooks_dir() {
    if [ -n "$HOOKS_DIR" ]; then
        printf '%s\n' "$HOOKS_DIR"
        return
    fi

    local configured
    configured="$(git config --get core.hooksPath || true)"
    if [ -n "$configured" ]; then
        if [[ "$configured" = /* ]]; then
            printf '%s\n' "$configured"
        else
            printf '%s\n' "$(git rev-parse --show-toplevel)/$configured"
        fi
        return
    fi

    printf '%s\n' "$(git rev-parse --git-path hooks)"
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --install)
                ACTION="install"
                ;;
            --update)
                ACTION="update"
                ;;
            --ref)
                shift
                [ "$#" -gt 0 ] || fail "Missing value for --ref"
                REF="$1"
                ;;
            --hooks-dir)
                shift
                [ "$#" -gt 0 ] || fail "Missing value for --hooks-dir"
                HOOKS_DIR="$1"
                ;;
            --dry-run)
                DRY_RUN=true
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

validate_context() {
    require_cmd git
    require_cmd curl

    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Run this inside a Git working tree"
    [ -n "$REF" ] || fail "No ref selected. Pass --ref <tag-or-branch> or set MT_GIT_HOOKS_REF/MT_GIT_HOOKS_VERSION"
}

print_review_block() {
    local target_dir="$1"
    shift
    local hooks=("$@")

    log "Existing managed hooks detected in $target_dir"
    for hook in "${hooks[@]}"; do
        local existing_file="$target_dir/$hook"
        local url="$RAW_BASE/$REF/scripts/git-hooks/$hook"
        echo "  - $existing_file"
        echo "    Review: curl -fsSL \"$url\" | diff -u \"$existing_file\" -"
    done
    log "Re-run with --force to approve overwrite with backups."
}

install_one_hook() {
    local hook_name="$1"
    local target_file="$2"
    local url="$RAW_BASE/$REF/scripts/git-hooks/$hook_name"

    log "Fetching $hook_name from $url"

    if [ "$DRY_RUN" = true ]; then
        return
    fi

    local tmp
    tmp="$(mktemp)"
    if ! curl -fsSL "$url" -o "$tmp"; then
        rm -f "$tmp"
        fail "Failed to download $hook_name from ref '$REF'"
    fi

    mv "$tmp" "$target_file"
    chmod +x "$target_file"
}

main() {
    parse_args "$@"
    validate_context

    local target_dir
    target_dir="$(resolve_hooks_dir)"

    [ -d "$target_dir" ] || fail "Hooks directory not found: $target_dir"
    [ -w "$target_dir" ] || fail "Hooks directory is not writable: $target_dir"

    local existing=()
    local missing=()
    for hook in "${MANAGED_HOOKS[@]}"; do
        if [ -f "$target_dir/$hook" ]; then
            existing+=("$hook")
        else
            missing+=("$hook")
        fi
    done

    if [ "$ACTION" = "update" ] && [ "${#missing[@]}" -gt 0 ]; then
        for hook in "${missing[@]}"; do
            log "Missing managed hook for update: $target_dir/$hook"
        done
        fail "--update requires existing managed hooks. Run --install first."
    fi

    if [ "$ACTION" = "install" ] && [ "${#existing[@]}" -gt 0 ] && [ "$FORCE" != true ]; then
        print_review_block "$target_dir" "${existing[@]}"
        exit 1
    fi

    if [ "$ACTION" = "update" ] && [ "$FORCE" != true ]; then
        print_review_block "$target_dir" "${MANAGED_HOOKS[@]}"
        fail "--update requires --force to approve managed hook replacement."
    fi

    log "Action: $ACTION"
    log "Ref: $REF"
    log "Hooks directory: $target_dir"
    [ "$DRY_RUN" = true ] && log "Dry run enabled (no files will be written)"

    if [ "$FORCE" = true ] && [ "$DRY_RUN" != true ]; then
        local backup_dir="$target_dir/mt-git-hooks-backups/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        local to_backup=()
        if [ "$ACTION" = "update" ]; then
            to_backup=("${MANAGED_HOOKS[@]}")
        else
            to_backup=("${existing[@]}")
        fi

        for hook in "${to_backup[@]}"; do
            [ -f "$target_dir/$hook" ] || continue
            cp "$target_dir/$hook" "$backup_dir/$hook"
        done
        log "Backed up existing hooks to $backup_dir"
    fi

    for hook in "${MANAGED_HOOKS[@]}"; do
        install_one_hook "$hook" "$target_dir/$hook"
    done

    if [ "$DRY_RUN" = true ]; then
        log "Dry run completed."
    else
        log "Installed hooks: ${MANAGED_HOOKS[*]}"
    fi
}

main "$@"
