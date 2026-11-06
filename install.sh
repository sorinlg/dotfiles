#!/usr/bin/env zsh

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Parse command line arguments
NO_RELOAD=false
DRY_RUN=false
for arg in "$@"; do
  case $arg in
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --help, -h       Show this help message"
      echo "  --no-reload      Skip shell activation after installation"
      echo "  --dry-run        Show what would happen without making changes"
      echo ""
      echo "Environment variables:"
      echo "  DOTFILES_DIR          Custom dotfiles directory"
      echo "  ZSH_PLUGINS_DIR       Custom plugins directory"
      echo "  DOTFILES_SKIP_OP_CHECK  Skip the mandatory 1Password CLI prerequisite check"
      echo "                          (for disposable/test environments only - see README)"
      echo "  DOTFILES_SKIP_NODE_BOOTSTRAP  Skip automatic Node.js LTS install via nvm"
      echo "  DOTFILES_SKIP_GO_BOOTSTRAP    Skip automatic GVM install + latest Go default"
      exit 0
      ;;
    --no-reload)
      NO_RELOAD=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

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
log_dry() { printf "${YELLOW}[DRY RUN]${NC} %s\n" "$1"; }

# Detect OS and package manager
detect_package_manager() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      log_error "Homebrew not found. Please install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
    echo "brew"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  else
    log_error "No supported package manager found (brew, apt-get, yum)"
    exit 1
  fi
}

PACKAGE_MANAGER=$(detect_package_manager)
export ROOT_DIR=$(git rev-parse --show-toplevel)
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT_DIR}"

log_section "DOTFILES INSTALLATION"
log_info "Root directory: ${ROOT_DIR}"
log_info "Package manager: ${PACKAGE_MANAGER}"
log_info "Plugin directory: ${ZSH_PLUGINS_DIR:-${HOME}/.config/zsh/plugins}"

# Dependency verification
verify_dependencies() {
  log_section "SYSTEM VERIFICATION"

  local missing_deps=()

  # Check git (required for cloning)
  if ! command -v git >/dev/null 2>&1; then
    missing_deps+=("git")
  fi

  # Check internet connectivity
  if ! curl -s --connect-timeout 5 https://github.com >/dev/null 2>&1; then
    log_warning "No internet connection detected - plugin installation may fail"
  fi

  # Check write permissions for home directory
  if [[ ! -w "$HOME" ]]; then
    log_error "No write permission for home directory: $HOME"
    exit 1
  fi

  # Check if we can create the plugin directory
  # Use zsh built-in parameter expansion :h (head/dirname) instead of external dirname command
  local configured_plugins_dir="${ZSH_PLUGINS_DIR:-${HOME}/.config/zsh/plugins}"
  local plugin_parent_dir="$configured_plugins_dir"
  plugin_parent_dir="${plugin_parent_dir:h}"  # Equivalent to $(dirname ...)
  if [[ ! -w "$plugin_parent_dir" ]] && [[ ! -d "$plugin_parent_dir" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry "Would create directory: $plugin_parent_dir"
    elif ! mkdir -p "$plugin_parent_dir" 2>/dev/null; then
      log_error "Cannot create plugin directory: $plugin_parent_dir"
      exit 1
    fi
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_warning "Missing dependencies will be installed: ${missing_deps[*]}"
  else
    log_success "All dependencies verified"
  fi
}

verify_dependencies

# Validate config.sh exists
if [[ ! -f "${ROOT_DIR}/config.sh" ]]; then
  log_error "config.sh not found. Please create it with your personal settings."
  log_info "Copy config.sh.example as a starting point if available"
  exit 1
fi

# Validate 1Password CLI is installed and signed in (mandatory prerequisite
# on a real machine — every op-backed feature below, e.g. Atuin login and the
# Homebrew GitHub token, has no plaintext fallback). DOTFILES_SKIP_OP_CHECK
# opts out of this specific up-front check for disposable/unattended test
# environments (e.g. the Tart VM smoke test) where op will never be signed
# in; every downstream op-backed feature still degrades gracefully with its
# own log_warning rather than failing, so this only skips the fail-fast gate,
# not the actual op reads.
# config.sh is sourced further down, so peek at it to see whether any
# 1Password-backed feature is configured at all (a fork without one needs no op).
_uses_op="$(zsh -c 'source "$1" >/dev/null 2>&1; print -r -- "${_atuin_op_item:-}"' _ "${ROOT_DIR}/config.sh")"
if [[ -z "${_uses_op}" && -z "${DOTFILES_SKIP_OP_CHECK:-}" ]]; then
  log_info "No 1Password-backed features configured in config.sh, skipping the op prerequisite check"
elif [[ -n "${DOTFILES_SKIP_OP_CHECK:-}" ]]; then
  log_warning "Skipping 1Password CLI prerequisite check (DOTFILES_SKIP_OP_CHECK set) - op-backed features (Atuin login, Homebrew token) will be skipped with a warning"
else
  _op_errors=()
  if ! command -v op &>/dev/null; then
    _op_errors+=("1Password CLI (op) is not installed. Install it via Brewfile (cask \"1password-cli\") or https://developer.1password.com/docs/cli/get-started/")
  else
    # `op whoami` reports "not signed in" as a false negative on machines where
    # the desktop app's biometric integration authorizes individual `op`
    # commands without a CLI `op signin` session. `op vault list` requires the
    # same real auth as the `op read`/`op document` calls below, so check that
    # instead of a session marker that doesn't reflect actual capability.
    if ! op vault list &>/dev/null; then
      _op_errors+=("1Password CLI (op) cannot access any vaults. Run: op signin")
    fi
  fi
  if [[ ${#_op_errors[@]} -gt 0 ]]; then
    for _op_error in "${_op_errors[@]}"; do
      log_error "$_op_error"
    done
    exit 1
  fi
fi

# Source configuration for template variables
source "${ROOT_DIR}/config.sh"

_git_update() {
  local repo_url="$1"
  local destination_path="$2"
  # Use zsh built-in parameter expansion :t (tail/basename)
  local plugin_name="${destination_path:t}"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would install/update plugin: $plugin_name"
    return 0
  fi

  if [[ -d "$destination_path" ]]; then
    log_info "Updating ${plugin_name}"
    cd "$destination_path" || return
    git pull --quiet
    cd "$ROOT_DIR" || return
  else
    log_info "Installing ${plugin_name}"
    git clone --quiet --depth=1 "${repo_url}" "${destination_path}"
  fi
}

# Install prerequisites
log_section "PREREQUISITES"

# Trust third-party taps declared in the Brewfile so brew bundle/outdated work
# correctly on Homebrew 6+. Auto-trusting is acceptable here because the taps
# are explicitly authored by the user in their own Brewfile.
trust_taps() {
  [[ "$PACKAGE_MANAGER" != "brew" ]] && return 0

  local brewfile="${ROOT_DIR}/Brewfile"

  local taps
  taps=$(grep -hoE '^tap "[^"]+"' "$brewfile" ${=_brewfile_extra:-} 2>/dev/null | sed -E 's/^tap "([^"]+)"/\1/')
  [[ -z "$taps" ]] && return 0

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would run: brew trust --tap ${taps//$'\n'/ }"
    return 0
  fi

  log_info "Trusting third-party taps"
  # brew trust is idempotent — safe to re-run on existing installs
  if echo "$taps" | xargs brew trust --tap >/dev/null 2>&1; then
    log_success "Taps trusted"
  else
    log_warning "Could not trust one or more taps (continuing)"
  fi
}

install_packages() {
  if [[ "$PACKAGE_MANAGER" != "brew" ]]; then
    log_warning "Package installation skipped (only supported on Homebrew systems)"
    return 0
  fi

  trust_taps

  local brewfile="${ROOT_DIR}/Brewfile"

  log_info "Installing packages via ${brewfile:t}"
  if [[ ! -f "$brewfile" ]]; then
    log_error "Brewfile not found at ${brewfile}"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would run: brew bundle --file=${brewfile}"
    return 0
  fi

  if [[ -z "${_homebrew_github_token:-}" ]]; then
    log_warning "_homebrew_github_token not set in config.sh - continuing without HOMEBREW_GITHUB_API_TOKEN"
  else
    export HOMEBREW_GITHUB_API_TOKEN="$_homebrew_github_token"
  fi

  # _brewfile_extra (config.sh): space-separated extra Brewfiles, e.g. a work profile's
  local _bf
  for _bf in "${brewfile}" ${=_brewfile_extra:-}; do
    if [[ ! -f "$_bf" ]]; then
      log_warning "Brewfile not found, skipping: ${_bf}"
      continue
    fi
    if brew bundle --file="${_bf}" 2>&1 | grep -v "Using "; then
      log_success "Packages installed from ${_bf:t}"
    else
      log_error "Failed to install packages from ${_bf}"
      return 1
    fi
  done
}

install_packages

# Bootstrap Node.js LTS via nvm (brew only installs the nvm binary itself;
# it never populates ~/.nvm/versions/node, so node/npm/npx stay unavailable
# without this). DOTFILES_SKIP_NODE_BOOTSTRAP opts out for disposable/CI
# installs, mirroring DOTFILES_SKIP_OP_CHECK above.
log_section "NODE.JS"
if [[ -n "${DOTFILES_SKIP_NODE_BOOTSTRAP:-}" ]]; then
  log_warning "Skipping Node.js bootstrap (DOTFILES_SKIP_NODE_BOOTSTRAP set) - node/npm/npx will be unavailable"
elif [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would run: nvm install --lts"
else
  _nvm_sh="${_homebrew_prefix:-/opt/homebrew}/opt/nvm/nvm.sh"
  if [[ -s "$_nvm_sh" ]]; then
    log_info "Installing latest Node.js LTS via nvm..."
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    # nvm's install lock (~/.nvm/.cache/locks/<version>) can be left behind by
    # a killed/crashed prior run (e.g. this installer interrupted mid-install).
    # nvm ships a stale-lock timeout for exactly this, but it defaults to
    # disabled (NVM_INSTALL_LOCK_STALE=0), so an orphaned lock silently blocks
    # every future run for the full NVM_INSTALL_LOCK_TIMEOUT (default 600s)
    # before failing. Enable self-healing and shorten the ceiling so a stale
    # lock from this installer never wastes more than 2 minutes again.
    export NVM_INSTALL_LOCK_STALE="${NVM_INSTALL_LOCK_STALE:-2}"
    export NVM_INSTALL_LOCK_TIMEOUT="${NVM_INSTALL_LOCK_TIMEOUT:-120}"
    # shellcheck disable=SC1090
    \. "$_nvm_sh"
    if nvm install --lts >/tmp/nvm-install.log 2>&1 && nvm alias default 'lts/*' >>/tmp/nvm-install.log 2>&1; then
      log_success "Node.js LTS installed ($(nvm current))"
    else
      log_warning "Node.js LTS install failed (see /tmp/nvm-install.log)"
    fi
  else
    log_warning "nvm.sh not found at ${_nvm_sh} - skipping Node.js bootstrap"
  fi
fi

# Bootstrap Go via GVM (Go Version Manager). Unlike nvm, GVM has no Homebrew
# formula (verified via `brew search gvm`) -- it only ships its own installer
# script, so it can't be declared in Brewfile. lib/zsh/3-tools-misc already
# knows how to source ~/.gvm/environments/default and lazy-load the `gvm`
# command once GVM is present, but without this step go falls back to the
# unfilled config.sh placeholders (_config_go_path/_go_root) and breaks.
# DOTFILES_SKIP_GO_BOOTSTRAP opts out, mirroring DOTFILES_SKIP_NODE_BOOTSTRAP.
log_section "GO"
if [[ -n "${DOTFILES_SKIP_GO_BOOTSTRAP:-}" ]]; then
  log_warning "Skipping Go/GVM bootstrap (DOTFILES_SKIP_GO_BOOTSTRAP set) - go will fall back to config.sh's _go_root/_config_go_path"
elif [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would install GVM (if missing) and gvm install/use the latest Go release"
else
  _gvm_root="${HOME}/.gvm"
  if [[ ! -s "${_gvm_root}/scripts/gvm" ]]; then
    log_info "Installing GVM..."
    if GVM_NO_UPDATE_PROFILE=1 bash < <(curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer) >/tmp/gvm-install.log 2>&1; then
      log_success "GVM installed"
    else
      log_warning "GVM install failed (see /tmp/gvm-install.log)"
    fi
  fi

  _gvm_default_env="${_gvm_root}/environments/default"
  if [[ -s "${_gvm_default_env}" ]]; then
    _current_go="$(grep -o 'gvm_go_name="[^"]*"' "${_gvm_default_env}" | cut -d'"' -f2)"
    log_info "Go already managed by GVM (default: ${_current_go:-unknown}) - skipping install"
    unset _current_go
  elif [[ -s "${_gvm_root}/scripts/gvm" ]]; then
    _latest_go="$(curl -fsSL "https://go.dev/VERSION?m=text" 2>/dev/null | head -1)"
    if [[ -n "${_latest_go}" ]]; then
      log_info "Installing ${_latest_go} via GVM..."
      # GVM's own scripts, generated environment files (e.g.
      # ~/.gvm/environments/default), and its commands reference several
      # variables (GVM_DEBUG, PKG_CONFIG_PATH, GVM_NO_GIT_BAK, ...) without a
      # default, and some internal commands return non-zero as normal
      # control flow -- both crash/abort under this file's `set -e`/`set -u`.
      # GVM isn't written to be strict-mode-safe, so shield this whole block
      # instead of patching each violation as it surfaces.
      set +eu
      # shellcheck disable=SC1091
      \. "${_gvm_root}/scripts/gvm"
      if gvm install "${_latest_go}" -B >/tmp/gvm-go-install.log 2>&1 && gvm use "${_latest_go}" --default >>/tmp/gvm-go-install.log 2>&1; then
        log_success "${_latest_go} installed and set as GVM default"
      else
        log_warning "Failed to install/default ${_latest_go} via GVM (see /tmp/gvm-go-install.log)"
      fi
      set -eu
    else
      log_warning "Could not determine latest Go version (network?) - skipping GVM Go install"
    fi
    unset _latest_go
  fi
  unset _gvm_default_env
  unset _gvm_root
fi

# Install zsh plugins (standalone, replacing oh-my-zsh)
log_section "ZSH PLUGINS"
PLUGINS_DIR="${ZSH_PLUGINS_DIR:-${HOME}/.config/zsh/plugins}"
log_info "Installing to: ${PLUGINS_DIR}"
if [[ "$DRY_RUN" != "true" ]]; then
  mkdir -p "${PLUGINS_DIR}"
fi

# Verify plugin directory is writable
if [[ ! -w "${PLUGINS_DIR}" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would require writable plugin directory: ${PLUGINS_DIR}"
  else
    log_error "Plugin directory not writable: ${PLUGINS_DIR}"
    exit 1
  fi
fi

_git_update https://github.com/zsh-users/zsh-syntax-highlighting.git "${PLUGINS_DIR}/zsh-syntax-highlighting"
_git_update https://github.com/zsh-users/zsh-autosuggestions "${PLUGINS_DIR}/zsh-autosuggestions"
_git_update https://github.com/Aloxaf/fzf-tab "${PLUGINS_DIR}/fzf-tab"
_git_update https://github.com/romkatv/powerlevel10k.git "${PLUGINS_DIR}/powerlevel10k"

log_success "All plugins installed"

# Backup existing config files with timestamps
log_section "BACKUP & CONFIGURATION"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
log_info "Creating backups (timestamp: ${TIMESTAMP})"

backup_file() {
  local file="$1"
  if [[ -f "${HOME}/${file}" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry "Would backup ${file}"
    else
      cp "${HOME}/${file}" "${HOME}/${file}.bak.${TIMESTAMP}"
      log_info "Backed up ${file}"
    fi
  fi
}

backup_file ".zshrc"
backup_file ".zshenv"
backup_file ".p10k.zsh"
backup_file ".p10k-overrides.zsh"
backup_file ".codex/config.toml"

# Load utility functions for templating
source "${ROOT_DIR}/lib/utils"
source "${ROOT_DIR}/lib/utils-app-defaults"

# Install zsh profile
log_info "Creating profile files"

# Generate .zshrc from template with configurable path
if [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would generate .zshrc from template"
else
  sed -e "s,##DOTFILES_DIR##,${DOTFILES_DIR},g" "${ROOT_DIR}/rc.d/.zshrc.template" > "${HOME}/.zshrc"
fi

_do_link "${ROOT_DIR}/rc.d/.fzf.zsh" "${HOME}/.fzf.zsh"
_do_link "${ROOT_DIR}/rc.d/.zshenv" "${HOME}/.zshenv"
_do_link "${ROOT_DIR}/rc.d/.p10k.zsh" "${HOME}/.p10k.zsh"
_do_link "${ROOT_DIR}/rc.d/.p10k-overrides.zsh" "${HOME}/.p10k-overrides.zsh"

log_section "GIT CONFIGURATION"
log_info "Setting up git configuration and credentials"

# Generate git configuration from templates
_do_template "${ROOT_DIR}/lib/git/credentials"
_do_template "${ROOT_DIR}/lib/git/config"

# Create git config symlinks
_do_link "${ROOT_DIR}/lib/git/config" "${HOME}/.gitconfig"
_do_link "${ROOT_DIR}/lib/git/aliases" "${HOME}/.gitconfig_aliases"
_do_link "${ROOT_DIR}/lib/git/credentials" "${HOME}/.gitconfig_credentials"

log_section "DEVELOPMENT TOOLS"
log_info "Setting up development tool symlinks"

# Ensure .bin directory exists
if [[ "$DRY_RUN" != "true" ]]; then
  mkdir -p "${HOME}/.bin"
fi

# Create tool symlinks
_do_link "${ROOT_DIR}/tools/awss/awss.sh" "${HOME}/.bin/awss"

# Create git completion symlink for fpath
_do_link "${ROOT_DIR}/lib/git/completion.zsh" "${HOME}/.bin/_git"

# Create vim configuration symlink
if [[ -f "${ROOT_DIR}/lib/vim/vimrc" ]]; then
  _do_link "${ROOT_DIR}/lib/vim/vimrc" "${HOME}/.vimrc"
fi

# Create Ghostty configuration symlink
if [[ -f "${ROOT_DIR}/lib/ghostty/config" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ghostty_config_dir="${HOME}/Library/Application Support/com.mitchellh.ghostty"
    ghostty_xdg_config_dir="${HOME}/.config/ghostty"
  else
    ghostty_config_dir="${HOME}/.config/ghostty"
    ghostty_xdg_config_dir=""
  fi

  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${ghostty_config_dir}"
    [[ -n "${ghostty_xdg_config_dir}" ]] && mkdir -p "${ghostty_xdg_config_dir}"
  fi
  _do_link "${ROOT_DIR}/lib/ghostty/config" "${ghostty_config_dir}/config"
  [[ -n "${ghostty_xdg_config_dir}" ]] && \
    _do_link "${ROOT_DIR}/lib/ghostty/config" "${ghostty_xdg_config_dir}/config"
fi

# Create cmux configuration symlink
if [[ -f "${ROOT_DIR}/lib/cmux/cmux.json" ]]; then
  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${HOME}/.config/cmux"
  fi
  _do_link "${ROOT_DIR}/lib/cmux/cmux.json" "${HOME}/.config/cmux/cmux.json"
fi

# Seed Codex configuration once (NOT symlinked).
# Codex Desktop rewrites ~/.codex/config.toml in place, so a symlink would let it
# scribble into this repo and accumulate duplicate TOML tables. We seed a real
# file on first install and let the app own it thereafter. Repo-scoped overrides
# live in <repo>/.codex/config.toml, which Codex auto-loads for trusted projects.
if [[ -f "${ROOT_DIR}/lib/codex/config.toml" ]]; then
  codex_config_dir="${HOME}/.codex"

  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${codex_config_dir}"
  fi

  _do_seed "${ROOT_DIR}/lib/codex/config.toml" "${codex_config_dir}/config.toml"
fi

# Create Zed configuration symlinks
if [[ -d "${ROOT_DIR}/lib/zed" ]]; then
  zed_config_dir="${HOME}/.config/zed"

  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${zed_config_dir}"
  fi

  [[ -f "${ROOT_DIR}/lib/zed/settings.json" ]] && \
    _do_link "${ROOT_DIR}/lib/zed/settings.json" "${zed_config_dir}/settings.json"
  [[ -f "${ROOT_DIR}/lib/zed/keymap.json" ]] && \
    _do_link "${ROOT_DIR}/lib/zed/keymap.json" "${zed_config_dir}/keymap.json"
fi

# Create VSCode configuration symlinks
if [[ -d "${ROOT_DIR}/lib/vscode" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    vscode_config_dir="${HOME}/Library/Application Support/Code/User"
  else
    vscode_config_dir="${HOME}/.config/Code/User"
  fi

  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${vscode_config_dir}"
  fi

  [[ -f "${ROOT_DIR}/lib/vscode/settings.json" ]] && \
    _do_link "${ROOT_DIR}/lib/vscode/settings.json" "${vscode_config_dir}/settings.json"
  [[ -f "${ROOT_DIR}/lib/vscode/keybindings.json" ]] && \
    _do_link "${ROOT_DIR}/lib/vscode/keybindings.json" "${vscode_config_dir}/keybindings.json"
fi

# Create Atuin configuration symlink
if [[ -f "${ROOT_DIR}/lib/atuin/config.toml" ]]; then
  atuin_config_dir="${HOME}/.config/atuin"

  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${atuin_config_dir}"
  fi

  _do_link "${ROOT_DIR}/lib/atuin/config.toml" "${atuin_config_dir}/config.toml"

  # Auto-login to Atuin sync via 1Password (op signed-in already validated above)
  # so history sync resumes immediately on a new machine instead of needing an
  # interactive login, then trigger an immediate sync so history is available
  # right away instead of waiting on config.toml's sync_frequency daemon setting.
  #
  # `atuin status` (not a session file) is the login check: atuin 18.x no longer
  # persists a flat `session` file, so a file-existence check silently never
  # detects an existing login and, worse, never gates the sync call either.
  if [[ "$DRY_RUN" != "true" ]] && command -v atuin >/dev/null 2>&1; then
    _atuin_logged_in() { atuin status 2>/dev/null | grep -q '^Username:'; }

    if _atuin_logged_in; then
      log_info "Atuin already logged in, skipping auto-login"
    elif [[ -z "${_atuin_op_item:-}" ]]; then
      log_warning "_atuin_op_item not set in config.sh - skipping Atuin login"
    else
      _atuin_username="$(op read "${_atuin_op_item}/username" 2>/dev/null)" || _atuin_username=""
      _atuin_password="$(op read "${_atuin_op_item}/password" 2>/dev/null)" || _atuin_password=""
      _atuin_key="$(op read "${_atuin_op_item}/Atuin Sync/Sync Key" 2>/dev/null)" || _atuin_key=""

      if [[ -z "$_atuin_username" || -z "$_atuin_password" || -z "$_atuin_key" ]]; then
        log_warning "Could not resolve Atuin credentials from 1Password (${_atuin_op_item}) - skipping Atuin login"
      else
        log_info "Logging in to Atuin sync..."
        if atuin login -u "${_atuin_username}" -p "${_atuin_password}" -k "${_atuin_key}" >/tmp/atuin-login.log 2>&1; then
          log_success "Atuin login successful"
        else
          log_warning "Atuin login failed (see /tmp/atuin-login.log)"
        fi
      fi
      unset _atuin_username _atuin_password _atuin_key
    fi

    if _atuin_logged_in; then
      log_info "Syncing Atuin history..."
      if atuin sync -f >/tmp/atuin-sync.log 2>&1; then
        log_success "Atuin sync complete"
      else
        log_warning "Atuin sync failed (see /tmp/atuin-sync.log)"
      fi
    else
      log_warning "Atuin not logged in - skipping sync"
    fi
    unset -f _atuin_logged_in
  fi
fi

# Create ccstatusline (Claude Code statusline) configuration symlink
if [[ -d "${ROOT_DIR}/lib/ccstatusline" ]]; then
  ccstatusline_config_dir="${HOME}/.config/ccstatusline"

  if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "${ccstatusline_config_dir}"
  fi

  [[ -f "${ROOT_DIR}/lib/ccstatusline/settings.json" ]] && \
    _do_link "${ROOT_DIR}/lib/ccstatusline/settings.json" "${ccstatusline_config_dir}/settings.json"
fi

# Import defaults-backed app preferences (Rectangle, Clipy, ...). These apps
# store their config in a macOS `defaults` domain, not a plain file, so they
# are imported via `defaults import` rather than symlinked. macOS-only; see
# README.md Prerequisites for the Accessibility/Input Monitoring permission
# grants this can't script. Registry: lib/utils-app-defaults - add a new app
# there and it's picked up here automatically.
if [[ "$OSTYPE" == "darwin"* ]]; then
  for _app_slug in "${_APP_DEFAULTS_ORDER[@]}"; do
    _app_domain="$(_app_defaults_domain "${_app_slug}")"
    _app_process="$(_app_defaults_process "${_app_slug}")"
    _app_plist="${ROOT_DIR}/$(_app_defaults_plist "${_app_slug}")"

    if [[ -f "${_app_plist}" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would import ${_app_process} preferences (${_app_domain})"
      else
        _defaults_import_and_restart "${_app_domain}" "${_app_process}" "${_app_plist}"
        log_success "${_app_process} preferences imported"
      fi
    fi
  done
  unset _app_slug _app_domain _app_process _app_plist
fi

log_success "All symlinks created"

log_section "DOCKER"

# Ensure docker-credential-env is wired up as the credsStore, plus the
# repo-managed registries under credHelpers, without owning the rest of
# ~/.docker/config.json (other auths/credHelpers entries are tied to this
# machine's current AWS accounts, not repo state).
source "${ROOT_DIR}/lib/docker/configure-credential-env.sh"
_docker_configure_credential_env

log_section "K9S / SOFKA COLORS"
if command -v k9s >/dev/null 2>&1 || command -v sofka >/dev/null 2>&1; then
  if [[ "${_k9s_sync_colours:-true}" == "true" ]]; then
    log_info "Generating k9s skins and sofka color overrides..."

    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry "Would generate k9s skins and sofka color overrides"
    elif "${ROOT_DIR}/tools/generate-k9s-skins.sh"; then
      log_success "K9s/sofka colors generated"
    else
      log_warning "K9s/sofka color generation failed"
    fi
  else
    log_info "K9s/sofka color auto-sync disabled in config (_k9s_sync_colours=false)"
  fi
else
  log_info "Neither k9s nor sofka installed, skipping color generation"
fi

log_section "PERFORMANCE OPTIMIZATION"
log_info "Compiling configurations for faster loading..."
if [[ -x "${ROOT_DIR}/lib/build/compile-configs.sh" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would compile configurations"
  else
    if "${ROOT_DIR}/lib/build/compile-configs.sh" "${ROOT_DIR}"; then
      log_success "Configurations compiled successfully"
    else
      log_warning "Configuration compilation had failures"
      log_info "Run './lib/build/compile-configs.sh ${ROOT_DIR}' to retest"
    fi
  fi
else
  log_warning "Compilation script not found or not executable"
fi

log_section "HEALTH CHECK"
if [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would run dotfiles tests"
elif [[ -x "${ROOT_DIR}/tools/test-dotfiles.sh" ]]; then
  log_info "Running dotfiles tests..."
  if "${ROOT_DIR}/tools/test-dotfiles.sh"; then
    log_success "All tests passed"
  else
    log_warning "Some tests failed (check output above)"
    log_info "Run './tools/test-dotfiles.sh' to retest"
  fi
else
  log_info "Test suite not available"
fi

log_section "PERFORMANCE BENCHMARK"
if [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would run quick startup benchmark (3 runs)"
elif [[ -x "${ROOT_DIR}/tools/benchmark-shell-startup.sh" ]]; then
  log_info "Running quick startup benchmark (3 runs)..."
  if "${ROOT_DIR}/tools/benchmark-shell-startup.sh" 3; then
    log_success "Benchmark completed"
  else
    log_warning "Benchmark failed (check output above)"
  fi
else
  log_info "Benchmark tool not available"
fi

log_section "INSTALLATION COMPLETE"
log_success "Dotfiles successfully configured!"
log_info "Uninstall: Run './uninstall.sh' if you need to remove everything"

# Handle shell activation based on context and user preference
if [[ "$NO_RELOAD" == "true" ]]; then
  log_section "ACTIVATION SKIPPED"
  printf "\n${GREEN}🚀 Installation complete!${NC}\n\n"
  printf "${YELLOW}To activate your new configuration:${NC}\n"
  printf "  • Close and reopen your terminal, OR\n"
  printf "  • Run: ${BLUE}exec zsh${NC}\n\n"
elif [[ -t 0 && -t 1 && -t 2 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  # TTY is available and we're in an interactive terminal
  log_section "ACTIVATION"
  printf "\n${GREEN}🚀 Installation complete!${NC}\n\n"

  # Check if we're already in zsh
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry "Would reload zsh configuration"
    else
      log_info "Reloading zsh configuration..."
      # Source the new config instead of exec to avoid suspension issues
      if [[ -f "${HOME}/.zshrc" ]]; then
        if source "${HOME}/.zshrc" 2>/dev/null; then
          log_success "Configuration reloaded successfully!"
        else
          log_warning "Configuration reload had warnings (this is usually normal for first setup)"
          log_info "If you encounter issues, try: exec zsh"
        fi
        printf "\n${BLUE}Your shell is now using the optimized configuration!${NC}\n\n"
      else
        log_error "Configuration file not found: ${HOME}/.zshrc"
        printf "${YELLOW}Please run: ${BLUE}exec zsh${NC} to start a new shell\n\n"
      fi
    fi
  elif [[ "${SHELL:-}" == *"zsh"* ]]; then
    log_info "Your default shell is zsh"
    printf "${YELLOW}To activate the new configuration:${NC} ${BLUE}exec zsh${NC}\n\n"
    printf "${YELLOW}Or simply close and reopen your terminal${NC}\n\n"
  else
    log_info "Your default shell is not zsh"
    printf "${YELLOW}To activate the new configuration:${NC}\n"
    printf "  1. Set zsh as default: ${BLUE}chsh -s \$(which zsh)${NC}\n"
    printf "  2. Start a new terminal or run: ${BLUE}exec zsh${NC}\n\n"
  fi
else
  # Non-interactive or no TTY available (e.g., output redirection, automation)
  log_section "ACTIVATION REQUIRED"
  printf "\n${GREEN}🚀 Installation complete!${NC}\n\n"
  printf "${YELLOW}To activate your new configuration:${NC}\n"
  printf "  • Close and reopen your terminal, OR\n"
  printf "  • Run: ${BLUE}exec zsh${NC}\n\n"
  log_info "Note: Automatic shell reload was skipped due to non-interactive context"
fi
