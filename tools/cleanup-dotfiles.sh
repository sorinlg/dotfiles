#!/usr/bin/env zsh

# Dotfiles Cleanup Utility
# Performs periodic maintenance and cleanup tasks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
log_info() { printf "${BLUE}▶${NC}  %s\n" "$1"; }
log_success() { printf "${GREEN}✅${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
log_error() { printf "${RED}❌${NC} %s\n" "$1" >&2; }
log_section() { printf "\n${BLUE}━━━ %s ━━━${NC}\n" "$1"; }

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PLUGINS_DIR="${ZSH_PLUGINS_DIR:-${HOME}/.config/zsh/plugins}"

# Parse options
CLEAN_ALL=false
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEAN_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            cat << EOF
Usage: $0 [OPTIONS]

Cleanup utility for dotfiles repository maintenance.

Options:
  --all         Clean everything (compiled files, temp files, old backups)
  --dry-run     Show what would be cleaned without doing it
  --verbose     Show detailed output
  --help        Show this help message

Examples:
  $0                    # Basic cleanup (temp files only)
  $0 --all             # Full cleanup including compiled files
  $0 --dry-run --all   # Preview full cleanup
EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_section "DOTFILES CLEANUP"
[[ "$DRY_RUN" == "true" ]] && log_warning "DRY RUN MODE - No files will be modified"

cleanup_count=0

# Function to safely remove files
safe_remove() {
    local file="$1"
    local description="${2:-file}"

    if [[ -e "$file" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Would remove $description: $(basename "$file")"
        else
            rm -f "$file"
            log_info "Removed $description: $(basename "$file")"
        fi
        ((cleanup_count++))
        return 0
    fi
    return 1
}

# Function to safely remove directories
safe_remove_dir() {
    local dir="$1"
    local description="${2:-directory}"

    if [[ -d "$dir" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            local count=$(find "$dir" -type f | wc -l | tr -d ' ')
            log_info "Would remove $description: $dir ($count files)"
        else
            rm -rf "$dir"
            log_info "Removed $description: $dir"
        fi
        ((cleanup_count++))
        return 0
    fi
    return 1
}

# 1. Clean temporary files
log_section "TEMPORARY FILES"
temp_files_found=false

# macOS specific temp files
for pattern in "**/.DS_Store" "**/*.swp" "**/*~" "**/*.tmp"; do
    while IFS= read -r -d '' file; do
        safe_remove "$file" "temp file" && temp_files_found=true
    done < <(find "$ROOT_DIR" -name "${pattern#**/}" -type f -print0 2>/dev/null || true)
done

[[ "$temp_files_found" == "false" ]] && log_info "No temporary files found"

# 2. Clean old backup files (only if --all specified)
if [[ "$CLEAN_ALL" == "true" ]]; then
    log_section "OLD BACKUP FILES"
    backup_files_found=false

    # Keep only the 3 most recent backups of each type
    for backup_pattern in ".zshrc.bak.*" ".p10k.zsh.bak.*" ".p10k-overrides.zsh.bak.*" ".zshenv.bak.*"; do
        newest_first=("${HOME}"/${~backup_pattern}(N.Om))
        old_backups=("${newest_first[@]:3}")
        for old_backup in "${old_backups[@]}"; do
            safe_remove "$old_backup" "old backup" && backup_files_found=true
        done
    done

    [[ "$backup_files_found" == "false" ]] && log_info "No old backup files found"
fi

# 3. Clean compiled files (only if --all specified)
if [[ "$CLEAN_ALL" == "true" ]]; then
    log_section "COMPILED FILES"
    compiled_files_found=false

    # Remove .zwc files
    while IFS= read -r -d '' zwc_file; do
        safe_remove "$zwc_file" "compiled file" && compiled_files_found=true
    done < <(find "$ROOT_DIR" -name "*.zwc" -type f -print0 2>/dev/null || true)

    # Remove compile manifest
    safe_remove "$ROOT_DIR/.compile-manifest" "compile manifest" && compiled_files_found=true

    [[ "$compiled_files_found" == "false" ]] && log_info "No compiled files found"

    # Offer to recompile
    if [[ "$DRY_RUN" == "false" && "$compiled_files_found" == "true" ]]; then
        log_info "Run './lib/build/compile-configs.sh' to recompile configurations"
    fi
fi

# 4. Clean plugin cache directories
log_section "PLUGIN CACHES"
plugin_cache_cleaned=false

if [[ -d "$PLUGINS_DIR" ]]; then
    # Clean common plugin cache directories
    for plugin_dir in "$PLUGINS_DIR"/*; do
        if [[ -d "$plugin_dir" ]]; then
            for cache_dir in "$plugin_dir/.git/objects" "$plugin_dir/cache" "$plugin_dir/.cache"; do
                if [[ -d "$cache_dir" ]] && [[ "$VERBOSE" == "true" ]]; then
                    safe_remove_dir "$cache_dir" "plugin cache" && plugin_cache_cleaned=true
                fi
            done
        fi
    done
fi

[[ "$plugin_cache_cleaned" == "false" ]] && log_info "No plugin caches found to clean"

# 5. Clean shell benchmark results (if verbose)
if [[ "$VERBOSE" == "true" ]] && [[ -d "${HOME}/.shell-benchmark" ]]; then
    log_section "BENCHMARK RESULTS"
    # Keep only the 5 most recent benchmark results
    old_benchmarks=($(ls -t "${HOME}/.shell-benchmark/results-"*.log 2>/dev/null | tail -n +6))
    if [[ ${#old_benchmarks[@]} -gt 0 ]]; then
        for old_benchmark in "${old_benchmarks[@]}"; do
            safe_remove "$old_benchmark" "old benchmark"
        done
    else
        log_info "No old benchmark results found"
    fi
fi

# Summary
log_section "CLEANUP SUMMARY"

if [[ $cleanup_count -eq 0 ]]; then
    log_success "Repository is already clean! ✨"
else
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "$cleanup_count items would be cleaned"
        log_info "Run without --dry-run to perform cleanup"
    else
        log_success "Cleaned $cleanup_count items"

        # Suggest running tests
        if [[ -x "$ROOT_DIR/tools/test-dotfiles.sh" ]]; then
            log_info "Run './tools/test-dotfiles.sh' to verify everything still works"
        fi
    fi
fi

echo