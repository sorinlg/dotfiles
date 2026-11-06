#!/usr/bin/env sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { printf "${BLUE}▶${NC}  %s\n" "$1"; }
log_success() { printf "${GREEN}✅${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
log_error() { printf "${RED}❌${NC} %s\n" "$1" >&2; }
log_section() { printf "\n${BLUE}━━━ %s ━━━${NC}\n" "$1"; }

export ROOT_DIR=$(git rev-parse --show-toplevel)
PLUGINS_DIR="${ZSH_PLUGINS_DIR:-${HOME}/.config/zsh/plugins}"

log_section "DOTFILES UNINSTALLATION"
log_warning "This will remove all dotfiles configuration and restore backups"
log_info "Plugin directory: ${PLUGINS_DIR}"
log_info "Backup files will be restored automatically"

# Confirm uninstallation
printf "\n${YELLOW}⚠${NC}  ${YELLOW}Are you sure you want to uninstall? (y/N):${NC} "
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Uninstallation cancelled"
    exit 0
fi

# Remove symlinks and restore backups
restore_config() {
    local config_file="$1"
    local home_file="${HOME}/${config_file}"

    if [[ -L "$home_file" ]]; then
        log_info "Removing symlink: $config_file"
        rm "$home_file"

        # Find most recent backup
        local latest_backup=$(ls -t "${HOME}/${config_file}.bak."* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            log_info "Restoring backup: $config_file"
            cp "$latest_backup" "$home_file"
        else
            log_warning "No backup found for $config_file"
        fi
    else
        log_info "$config_file is not a symlink (skipping)"
    fi
}

# Restore configuration files
log_section "RESTORING CONFIGURATION"
restore_config ".zshrc"
restore_config ".zshenv"
restore_config ".p10k.zsh"
restore_config ".p10k-overrides.zsh"
restore_config ".gitconfig"
restore_config ".gitconfig_aliases"
restore_config ".gitconfig_credentials"
# Codex config is seeded as a real file (not symlinked) on newer installs, so
# restore_config only acts when an old symlinked install is being removed.
restore_config ".codex/config.toml"

# Remove plugins directory
log_section "CLEANING UP"
if [[ -d "$PLUGINS_DIR" ]]; then
    log_info "Removing plugins directory: $PLUGINS_DIR"
    rm -rf "$PLUGINS_DIR"
    log_success "Plugins removed"
else
    log_info "Plugins directory not found (already removed)"
fi

# Remove custom tools
if [[ -d "${HOME}/.bin" ]]; then
    log_info "Removing custom tools from ${HOME}/.bin"

    # Only remove our tools, not entire .bin directory
    tools=(
        "awss"
        "_git"
    )

    for tool in "${tools[@]}"; do
        if [[ -L "${HOME}/.bin/${tool}" ]]; then
            rm "${HOME}/.bin/${tool}"
            log_info "Removed tool: $tool"
        fi
    done

    # Remove .bin directory if it's empty
    if [[ -z "$(ls -A "${HOME}/.bin" 2>/dev/null)" ]]; then
        rmdir "${HOME}/.bin"
        log_info "Removed empty .bin directory"
    fi
fi

# Clean up completion functions
fpath_dir="${HOME}/.config/zsh/completion"
if [[ -d "$fpath_dir" ]]; then
    log_info "Removing completion functions: $fpath_dir"
    rm -rf "$fpath_dir"
fi

# Clean up compiled files from dotfiles directory
if [[ -n "$ROOT_DIR" && -d "$ROOT_DIR" ]]; then
    log_info "Cleaning compiled files from dotfiles directory"
    find "$ROOT_DIR" -name "*.zwc" -type f -delete 2>/dev/null || true
    rm -f "$ROOT_DIR/.compile-manifest" 2>/dev/null || true
    log_success "Compiled files removed"
fi

log_section "UNINSTALLATION COMPLETE"
log_success "Dotfiles successfully removed!"
log_info "Shell configuration restored to previous state"
log_info "Restart your terminal or run 'exec zsh' to see changes"

# Optional: List remaining backup files
backup_files=($(ls "${HOME}/.zshrc.bak."* "${HOME}/.p10k.zsh.bak."* 2>/dev/null | head -5))
if [[ ${#backup_files[@]} -gt 0 ]]; then
    printf "\n${BLUE}▶${NC}  Backup files remaining (safe to delete):\n"
    for backup in "${backup_files[@]}"; do
        printf "   ${BLUE}•${NC} %s\n" "$(basename "$backup")"
    done
fi

printf "\n${GREEN}🧹 Your system has been restored to its original state!${NC}\n\n"
