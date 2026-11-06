#!/usr/bin/env zsh

# Review/pull/push config drift for two kinds of managed config:
#   - "dotfiles": config.sh <-> its 1Password backup ("dotfiles config.sh")
#   - "app":      a macOS `defaults`-backed app plist <-> its repo copy
#                 (registry: lib/utils-app-defaults)
#
# Usage:
#   config-sync.sh dotfiles-pull
#   config-sync.sh dotfiles-push
#   config-sync.sh diff [--app <name>] [--direction pull|push]
#   config-sync.sh app-pull --app <name>
#   config-sync.sh app-push --app <name>

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/lib/utils-app-defaults"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${BLUE}▶${NC}  %s\n" "$1"; }
log_success() { printf "${GREEN}✅${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
log_error() { printf "${RED}❌${NC} %s\n" "$1" >&2; }

_config_op_item="dotfiles config.sh"
_config_op_vault="Personal"
_config_file="config.sh"

_usage() {
  cat >&2 <<'EOF'
Usage:
  config-sync.sh dotfiles-pull
  config-sync.sh dotfiles-push
  config-sync.sh diff [--app <name>] [--direction pull|push]
  config-sync.sh app-pull --app <name>
  config-sync.sh app-push --app <name>
EOF
  exit 1
}

_require_op() {
  # Deliberately not gating on `op whoami` - on some machines the desktop-app
  # biometric integration authorizes individual `op` operations without a CLI
  # `op signin` session, so `whoami` reports "not signed in" as a false
  # negative even though real reads/writes work. Let the actual op command
  # below surface its own error if auth is genuinely missing.
  if ! command -v op >/dev/null 2>&1; then
    log_error "1Password CLI (op) is not installed."
    exit 1
  fi
}

# _confirm <prompt> -> 0 if the user answered y/Y
_confirm() {
  local prompt="$1" answer
  printf "%s [y/N] " "${prompt}"
  read -r answer
  [[ "${answer}" == "y" || "${answer}" == "Y" ]]
}

# _with_tmpdir <callback-fn-name> - runs callback with $1 set to a fresh
# tmpdir, guarantees cleanup via an EXIT trap even on early exit/error.
_with_tmpdir() {
  local cb="$1" tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' EXIT
  "${cb}" "${tmpdir}"
}

# _resolve_kind - sets _kind ("dotfiles"|"app") from whether --app was given,
# and for kind=app also resolves _app_domain/_app_process/_app_plist/_app_noise.
_resolve_kind() {
  if [[ -n "${_app_slug:-}" ]]; then
    _app_defaults_exists "${_app_slug}" || {
      log_error "Unknown app '${_app_slug}'. Known apps: ${(k)_APP_DEFAULTS_REGISTRY}"
      exit 1
    }
    _kind="app"
    _app_domain="$(_app_defaults_domain "${_app_slug}")"
    _app_process="$(_app_defaults_process "${_app_slug}")"
    _app_plist="$(_app_defaults_plist "${_app_slug}")"
    _app_noise="$(_app_defaults_noise "${_app_slug}")"
  else
    _kind="dotfiles"
  fi
}

# _fetch_pair <tmpdir> - populates _side_a_path/_side_a_exists (remote/live)
# and _side_b_path/_side_b_exists (local/repo).
_fetch_pair() {
  local tmpdir="$1"
  if [[ "${_kind}" == "dotfiles" ]]; then
    _side_a_path="${tmpdir}/1password-${_config_file}"
    if op document get "${_config_op_item}" --vault "${_config_op_vault}" --out-file "${_side_a_path}" --force >/dev/null 2>&1; then
      _side_a_exists=true
    else
      _side_a_exists=false
      : > "${_side_a_path}"
    fi
    _side_b_path="${_config_file}"
    if [[ -f "${_side_b_path}" ]]; then _side_b_exists=true; else _side_b_exists=false; fi
  else
    _side_a_path="${tmpdir}/live-$(basename "${_app_plist}")"
    if _app_defaults_domain_exists "${_app_domain}"; then
      local raw="${tmpdir}/raw.plist"
      defaults export "${_app_domain}" - > "${raw}"
      _app_defaults_curate "${raw}" "${_side_a_path}" "${_app_noise}"
      _side_a_exists=true
    else
      _side_a_exists=false
      : > "${_side_a_path}"
    fi
    _side_b_path="${_app_plist}"
    if [[ -f "${_side_b_path}" ]]; then _side_b_exists=true; else _side_b_exists=false; fi
  fi
}

_side_a_name() { if [[ "${_kind}" == "dotfiles" ]]; then echo "1password"; else echo "live-defaults"; fi; }
_side_b_name() { if [[ "${_kind}" == "dotfiles" ]]; then echo "local"; else echo "repo"; fi; }

# _print_diff - direction only changes which side is "source"/old vs
# "destination"/new in the labels; the two files being compared never change.
_print_diff() {
  local src dst src_label dst_label
  if [[ "${_direction}" == "pull" ]]; then
    src="${_side_a_path}"; dst="${_side_b_path}"
    src_label="$(_side_a_name)"; dst_label="$(_side_b_name)"
  else
    src="${_side_b_path}"; dst="${_side_a_path}"
    src_label="$(_side_b_name)"; dst_label="$(_side_a_name)"
  fi
  log_info "Diff (${src_label} → ${dst_label}):"
  # git/diff's positional order is (before, after) -- "-" lines come from the
  # first argument, "+" lines from the second. dst is the side about to be
  # overwritten (old/before); src is the incoming content (new/after). Pass
  # them in that order so removed/added lines read the intuitive way: what
  # disappears from the destination vs. what it gains.
  if command -v git >/dev/null 2>&1; then
    git --no-pager diff --no-index --color=always \
      --src-prefix="${dst_label}/" --dst-prefix="${src_label}/" \
      -- "${dst}" "${src}" || true
  else
    diff -u "${dst}" "${src}" || true
  fi
}

cmd_dotfiles_pull() {
  _require_op

  if [[ ! -f "${_config_file}" ]]; then
    # Fresh clone: nothing to lose, skip diff/confirm and fetch directly.
    log_info "Fetching ${_config_file} from 1Password (\"${_config_op_item}\")..."
    if op document get "${_config_op_item}" --vault "${_config_op_vault}" --out-file "${_config_file}" --force >/dev/null; then
      log_success "${_config_file} restored from 1Password"
    else
      log_error "Failed to fetch ${_config_file} from 1Password"
      exit 1
    fi
    return 0
  fi

  _kind="dotfiles"; _direction="pull"
  _with_tmpdir _dotfiles_pull_body
}
_dotfiles_pull_body() {
  local tmpdir="$1"
  _fetch_pair "${tmpdir}"

  if [[ "${_side_a_exists}" == false ]]; then
    log_error "No existing 1Password document found (\"${_config_op_item}\") - refusing to overwrite local ${_config_file} with nothing"
    exit 1
  fi

  if diff -q "${_side_a_path}" "${_side_b_path}" >/dev/null 2>&1; then
    log_success "Local ${_config_file} already matches the 1Password copy - nothing to pull"
    return 0
  fi

  _print_diff
  echo
  _confirm "Pull 1Password copy over local ${_config_file}?" || {
    log_warning "Aborted - local ${_config_file} left unchanged"
    exit 1
  }
  cp "${_side_a_path}" "${_config_file}"
  log_success "${_config_file} restored from 1Password"
}

cmd_dotfiles_push() {
  _require_op
  [[ -f "${_config_file}" ]] || { log_error "${_config_file} not found - nothing to push"; exit 1; }
  _kind="dotfiles"; _direction="push"
  _with_tmpdir _dotfiles_push_body
}
_dotfiles_push_body() {
  local tmpdir="$1"
  _fetch_pair "${tmpdir}"

  if [[ "${_side_a_exists}" == false ]]; then
    log_warning "No existing 1Password document found - will create a new one"
  elif diff -q "${_side_a_path}" "${_side_b_path}" >/dev/null 2>&1; then
    log_success "1Password copy is already up to date - nothing to push"
    return 0
  fi

  _print_diff
  echo
  _confirm "Push local ${_config_file} to 1Password, overwriting the item above?" || {
    log_warning "Aborted - 1Password copy left unchanged"
    exit 1
  }
  if [[ "${_side_a_exists}" == true ]]; then
    op document edit "${_config_op_item}" "${_config_file}" --vault "${_config_op_vault}"
  else
    op document create "${_config_file}" --title "${_config_op_item}" --file-name "config.sh" --vault "${_config_op_vault}"
  fi
  log_success "1Password copy of ${_config_file} updated"
}

cmd_diff() {
  [[ "${_kind}" == "dotfiles" ]] && _require_op
  _with_tmpdir _diff_body
}
_diff_body() {
  local tmpdir="$1"
  _fetch_pair "${tmpdir}"

  if [[ "${_side_a_exists}" == false ]]; then
    if [[ "${_kind}" == "dotfiles" ]]; then
      log_warning "No existing 1Password document found (\"${_config_op_item}\")"
    else
      log_warning "Domain ${_app_domain} has never been written - nothing to compare"
    fi
    return 0
  fi

  if [[ "${_side_b_exists}" == false ]]; then
    log_warning "Not found locally - only the remote/live copy exists"
    return 0
  fi

  if diff -q "${_side_a_path}" "${_side_b_path}" >/dev/null 2>&1; then
    log_success "No differences to show"
    return 0
  fi

  _print_diff
}

cmd_app_pull() {
  [[ -n "${_app_slug:-}" ]] || { log_error "app-pull requires --app <name>"; _usage; }
  _resolve_kind
  _direction="pull"
  _with_tmpdir _app_pull_body
}
_app_pull_body() {
  local tmpdir="$1"
  _fetch_pair "${tmpdir}"

  if [[ "${_side_a_exists}" == false ]]; then
    log_error "Domain ${_app_domain} has never been written - nothing to export"
    exit 1
  fi

  if [[ "${_side_b_exists}" == true ]] && diff -q "${_side_a_path}" "${_side_b_path}" >/dev/null 2>&1; then
    log_success "Repo copy already matches live ${_app_process} preferences - nothing to pull"
    return 0
  fi

  _print_diff
  echo
  _confirm "Overwrite repo copy (${_app_plist}) with curated live ${_app_process} preferences?" || {
    log_warning "Aborted - repo copy left unchanged"
    exit 1
  }
  mkdir -p "$(dirname "${_app_plist}")"
  cp "${_side_a_path}" "${_app_plist}"
  log_success "${_app_plist} updated from live ${_app_domain}"
}

cmd_app_push() {
  [[ -n "${_app_slug:-}" ]] || { log_error "app-push requires --app <name>"; _usage; }
  _resolve_kind
  [[ -f "${_app_plist}" ]] || { log_error "${_app_plist} not found - nothing to push"; exit 1; }
  _direction="push"
  _with_tmpdir _app_push_body
}
_app_push_body() {
  local tmpdir="$1"
  _fetch_pair "${tmpdir}"

  if [[ "${_side_a_exists}" == true ]] && diff -q "${_side_a_path}" "${_side_b_path}" >/dev/null 2>&1; then
    log_success "Live ${_app_process} preferences already match repo copy - nothing to push"
    return 0
  fi

  _print_diff
  echo
  _confirm "Import repo copy into live ${_app_domain} and restart ${_app_process} if running?" || {
    log_warning "Aborted - live preferences left unchanged"
    exit 1
  }
  _defaults_import_and_restart "${_app_domain}" "${_app_process}" "${_app_plist}"
  log_success "${_app_process} preferences imported from ${_app_plist}"
}

_subcommand="${1:-}"
[[ $# -gt 0 ]] && shift

_direction="pull"
_app_slug=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) _app_slug="$2"; shift 2 ;;
    --direction) _direction="$2"; shift 2 ;;
    *) log_error "Unknown flag: $1"; _usage ;;
  esac
done

if [[ "${_direction}" != "pull" && "${_direction}" != "push" ]]; then
  log_error "--direction must be 'pull' or 'push'"
  _usage
fi

case "${_subcommand}" in
  dotfiles-pull)
    [[ -n "${_app_slug}" ]] && { log_error "dotfiles-pull does not take --app"; exit 1; }
    cmd_dotfiles_pull
    ;;
  dotfiles-push)
    [[ -n "${_app_slug}" ]] && { log_error "dotfiles-push does not take --app"; exit 1; }
    cmd_dotfiles_push
    ;;
  diff)
    _resolve_kind
    cmd_diff
    ;;
  app-pull) cmd_app_pull ;;
  app-push) cmd_app_push ;;
  *) _usage ;;
esac
