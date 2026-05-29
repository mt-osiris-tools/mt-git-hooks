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
Usage: $0 [--install|--update|--uninstall] [--ref <tag-or-branch>] [--hooks-dir <path>] [--dry-run] [--force]

Options:
  --install            Install managed hooks (default)
  --update             Update managed hooks; requires existing hooks and --force
  --uninstall          Remove managed hooks; requires --force
  --ref <value>        Git ref (recommended: release tag; required for install/update)
  --hooks-dir <path>   Override hook destination directory
  --dry-run            Print actions without writing files
  --force              Approve overwrite/remove and create backups
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
            --uninstall)
                ACTION="uninstall"
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
    if [ "$ACTION" != "uninstall" ]; then
        [ -n "$REF" ] || fail "No ref selected. Pass --ref <tag-or-branch> or set MT_GIT_HOOKS_REF/MT_GIT_HOOKS_VERSION"
    fi
}

print_review_block_install_update() {
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

print_review_block_uninstall() {
    local target_dir="$1"
    shift
    local hooks=("$@")

    log "Managed hooks scheduled for uninstall from $target_dir"
    for hook in "${hooks[@]}"; do
        echo "  - $target_dir/$hook"
    done
    log "Re-run with --force to approve removal with backups."
}

backup_hooks() {
    local target_dir="$1"
    shift
    local hooks=("$@")

    [ "$DRY_RUN" = true ] && return 0
    [ "${#hooks[@]}" -gt 0 ] || return 0

    local backup_dir="$target_dir/mt-git-hooks-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    for hook in "${hooks[@]}"; do
        [ -f "$target_dir/$hook" ] || continue
        cp "$target_dir/$hook" "$backup_dir/$hook"
    done
    log "Backed up existing hooks to $backup_dir"
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

    if [ "$ACTION" = "uninstall" ]; then
        if [ "${#existing[@]}" -eq 0 ]; then
            log "No managed hooks found to uninstall."
            exit 0
        fi

        if [ "$FORCE" != true ]; then
            print_review_block_uninstall "$target_dir" "${existing[@]}"
            exit 1
        fi

        log "Action: $ACTION"
        log "Hooks directory: $target_dir"
        [ "$DRY_RUN" = true ] && log "Dry run enabled (no files will be written)"

        backup_hooks "$target_dir" "${existing[@]}"

        for hook in "${existing[@]}"; do
            log "Removing $target_dir/$hook"
            [ "$DRY_RUN" = true ] || rm -f "$target_dir/$hook"
        done

        [ "$DRY_RUN" = true ] && log "Dry run completed." || log "Uninstalled hooks: ${existing[*]}"
        exit 0
    fi

    if [ "$ACTION" = "update" ] && [ "${#missing[@]}" -gt 0 ]; then
        for hook in "${missing[@]}"; do
            log "Missing managed hook for update: $target_dir/$hook"
        done
        fail "--update requires existing managed hooks. Run --install first."
    fi

    if [ "$ACTION" = "install" ] && [ "${#existing[@]}" -gt 0 ] && [ "$FORCE" != true ]; then
        print_review_block_install_update "$target_dir" "${existing[@]}"
        exit 1
    fi

    if [ "$ACTION" = "update" ] && [ "$FORCE" != true ]; then
        print_review_block_install_update "$target_dir" "${MANAGED_HOOKS[@]}"
        fail "--update requires --force to approve managed hook replacement."
    fi

    log "Action: $ACTION"
    log "Ref: $REF"
    log "Hooks directory: $target_dir"
    [ "$DRY_RUN" = true ] && log "Dry run enabled (no files will be written)"

    local to_backup=()
    if [ "$ACTION" = "update" ]; then
        to_backup=("${MANAGED_HOOKS[@]}")
    else
        to_backup=("${existing[@]}")
    fi

    if [ "$FORCE" = true ]; then
        backup_hooks "$target_dir" "${to_backup[@]}"
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
