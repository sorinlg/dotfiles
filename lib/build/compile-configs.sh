#!/usr/bin/env zsh

# ZSH Configuration Compiler
# Compiles zsh configurations to .zwc files for faster loading

DOTFILES_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
COMPILE_MANIFEST="${DOTFILES_DIR}/.compile-manifest"
PLUGINS_DIR="${HOME}/.config/zsh/plugins"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${BLUE}▶${NC}  %s\n" "$1"; }
log_success() { printf "${GREEN}✅${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
log_error() { printf "${RED}❌${NC} %s\n" "$1" >&2; }

run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "${seconds}s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${seconds}s" "$@"
  else
    "$@"
  fi
}

# Initialize manifest
# Use zsh built-in parameter expansion :h (head/dirname) instead of external dirname command
mkdir -p "${COMPILE_MANIFEST:h}"
: > "$COMPILE_MANIFEST"

# Simple, fast compilation function
compile_if_needed() {
  local file="$1"
  local zwc_file="${file}.zwc"

  # Skip if file doesn't exist
  [[ ! -f "$file" ]] && return 1

  # Check if recompilation needed
  if [[ ! -f "$zwc_file" ]] || [[ "$file" -nt "$zwc_file" ]]; then
    # Use zsh built-in parameter expansion :t (tail/basename) instead of external basename command
    log_info "Compiling: ${file:t}"

    # Compile with timeout protection when timeout/gtimeout is available.
    if run_with_timeout 5 zsh -fc 'zcompile "$1"' zsh "$file" 2>/dev/null; then
      echo "$(date +%s):$file" >> "$COMPILE_MANIFEST"
      return 0
    else
      # Use zsh built-in parameter expansion :t (tail/basename) instead of external basename command
      log_error "Failed to compile: ${file:t}"
      [[ -f "$zwc_file" ]] && rm "$zwc_file"
      return 1
    fi
  fi
  return 0
}

# Verify zsh is available
if ! command -v zsh >/dev/null 2>&1; then
  log_error "zsh not found in PATH"
  exit 1
fi

log_info "Starting ZSH configuration compilation..."

compiled_count=0
failed_count=0

# Load config to check for work settings
[[ -f "${DOTFILES_DIR}/config.sh" ]] && . "${DOTFILES_DIR}/config.sh"

# List of files to compile in order of importance
FILES_TO_COMPILE=()

# Auto-discover all files in lib/zsh directory (excluding .zwc files)
for file in "${DOTFILES_DIR}/lib/zsh/"*(N); do
  [[ -f "$file" && "$file" != *.zwc ]] && FILES_TO_COMPILE+=("$file")
done

# Add other configuration files
FILES_TO_COMPILE+=(
  "${DOTFILES_DIR}/lib/utils"
  "${DOTFILES_DIR}/lib/utils-completion"
  "${DOTFILES_DIR}/entrypoint/source_profile.sh"
  "$HOME/.zshrc"
  "$HOME/.p10k.zsh"
  "$HOME/.p10k-overrides.zsh"
)

# Add work configuration if specified
if [[ -n "${_work_config_path:-}" && -n "${_work_shell_config:-}" ]]; then
  local work_shell_file="${_work_config_path}/${_work_shell_config}"
  if [[ -f "$work_shell_file" ]]; then
    FILES_TO_COMPILE+=("$work_shell_file")
    log_info "Including work shell configuration: ${work_shell_file:t}"
  fi
fi

# Compile files
for file in "${FILES_TO_COMPILE[@]}"; do
  if compile_if_needed "$file"; then
    ((compiled_count++))
  else
    ((failed_count++))
  fi
done

# Compile plugins if they exist
if [[ -d "$PLUGINS_DIR" ]]; then
  log_info "Compiling zsh plugins..."
  # Find main plugin files (prioritize .plugin.zsh, then .zsh-theme, then .zsh)
  for plugin_dir in "$PLUGINS_DIR"/*; do
    if [[ -d "$plugin_dir" ]]; then
      local main_file=""
      # Look for the main plugin file
      if [[ -f "$plugin_dir"/*.plugin.zsh ]]; then
        main_file="$plugin_dir"/*.plugin.zsh
      elif [[ -f "$plugin_dir"/*.zsh-theme ]]; then
        main_file="$plugin_dir"/*.zsh-theme
      # Use zsh built-in parameter expansion :t (tail/basename) instead of external basename command
      elif [[ -f "$plugin_dir"/"${plugin_dir:t}".zsh ]]; then
        main_file="$plugin_dir"/"${plugin_dir:t}".zsh
      fi

      if [[ -n "$main_file" ]] && [[ -f "$main_file" ]]; then
        if compile_if_needed "$main_file"; then
          ((compiled_count++))
        else
          ((failed_count++))
        fi
      fi
    fi
  done
fi

# Summary
echo
if [[ $failed_count -eq 0 ]]; then
  log_success "Compilation complete! Compiled $compiled_count files"
else
  log_warning "Compilation finished with $failed_count failures, $compiled_count successes"
fi

log_info "Manifest: $COMPILE_MANIFEST"

[[ $failed_count -eq 0 ]]
