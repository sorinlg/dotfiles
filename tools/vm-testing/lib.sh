#!/bin/bash

# Shared helpers for tools/vm-testing/*. Source it, don't execute it.
#
# Image tiers (the macOS version is part of every name so a future major
# version can be pulled alongside and the old one pruned: tart-golden.sh --prune):
#   OCI cache  ghcr.io/cirruslabs/macos-<ver>-vanilla   upstream image, no Homebrew
#   tier 1     dotfiles-golden-<ver>                    vanilla + our ssh key seeded
#   tier 2     dotfiles-golden-<ver>-brew               tier 1 + Homebrew (the README's step 1)
# Disposable per-run clones (smoke-test-<worktree>) are cloned from a tier.

VM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # consumed by the scripts that source this file
VM_ROOT_DIR="$(cd "${VM_LIB_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${BLUE}▶${NC}  %s\n" "$1"; }
log_success() { printf "${GREEN}✅${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
log_error() { printf "${RED}❌${NC} %s\n" "$1" >&2; }
log_section() { printf "\n${BLUE}━━━ %s ━━━${NC}\n" "$1"; }

MACOS_VERSION="${TART_MACOS_VERSION:-tahoe}"
# shellcheck disable=SC2034
VANILLA_IMAGE="${TART_VANILLA_IMAGE:-ghcr.io/cirruslabs/macos-${MACOS_VERSION}-vanilla:latest}"
GOLDEN_VM="${TART_GOLDEN_VM:-dotfiles-golden-${MACOS_VERSION}}"
# shellcheck disable=SC2034
GOLDEN_BREW_VM="${GOLDEN_VM}-brew"
GUEST_USER="${TART_GUEST_USER:-admin}"
GUEST_PASSWORD="${TART_GUEST_PASSWORD:-admin}"
# Bridge onto the host's default-route interface when it is a physical "enN"
# one (hardcoding en0 failed on a host whose uplink was en8: the guest never
# got a DHCP lease). A userspace tunnel (utun*) default route falls back to en0.
detect_bridge_interface() {
  local iface
  iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
  if [[ "${iface}" == en* ]]; then echo "${iface}"; else echo en0; fi
}
NET_BRIDGE_INTERFACE="${TART_NET_BRIDGE_INTERFACE:-$(detect_bridge_interface)}"
BOOT_TIMEOUT_SECONDS=180

# The keypair must be identical for every checkout on this machine (see
# fetch-tart-ssh-key.sh): the golden images are machine-global, so a key that
# differs per worktree would only match the worktree that seeded them.
TEST_KEY_PATH="${VM_LIB_DIR}/tart_test_key"
TEST_KEY_PUB_PATH="${TEST_KEY_PATH}.pub"

# Pubkey auth sidesteps the guest's intermittent password-auth rejection
# (sshd -> PAM -> opendirectoryd; ~15% of password attempts vs 0/60 for pubkey).
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -i "${TEST_KEY_PATH}")
# Used exactly once per golden image, to seed the key. Forcing password-only
# avoids "Too many authentication failures" from ssh-agent identities.
PASSWORD_SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PubkeyAuthentication=no -o PreferredAuthentications=password)

LOG_FILE="${LOG_FILE:-$(mktemp "${TMPDIR:-/tmp}/tart-vm-testing-log.XXXXXX")}"

# `tart list` columns are "Source Name Disk Size Accessed State": Name is column 2.
tart_vm_exists() {
  tart list 2>/dev/null | awk 'NR>1{print $2}' | grep -qx "$1"
}

# Tart authenticates to ghcr.io with whatever is in Keychain before trying
# anonymous access, and a stale credential is rejected outright. Prefer a
# known-good one from `gh`, unless the caller already exported their own.
export_registry_credentials() {
  if [[ -z "${TART_REGISTRY_USERNAME:-}" && -z "${TART_REGISTRY_PASSWORD:-}" ]] \
    && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    TART_REGISTRY_USERNAME="$(gh api user --jq .login)"
    TART_REGISTRY_PASSWORD="$(gh auth token)"
    export TART_REGISTRY_USERNAME TART_REGISTRY_PASSWORD
    log_info "Using gh-derived credentials for ghcr.io (avoids stale Keychain entries)"
  fi
}

# Collects every prerequisite failure and reports them together.
# Usage: validate_prereqs [--needs-key] [--needs-sshpass]
validate_prereqs() {
  local needs_key=false needs_sshpass=false errors=() arg
  for arg in "$@"; do
    case "${arg}" in
      --needs-key) needs_key=true ;;
      --needs-sshpass) needs_sshpass=true ;;
    esac
  done

  command -v tart >/dev/null 2>&1 \
    || errors+=("tart is not installed (see tools/vm-testing/README.md, One-time setup)")
  if [[ "${needs_sshpass}" == "true" ]] && ! command -v sshpass >/dev/null 2>&1; then
    errors+=("sshpass is not installed (needed once per golden image to seed the ssh key): brew install sshpass")
  fi
  if ! ifconfig "${NET_BRIDGE_INTERFACE}" >/dev/null 2>&1; then
    errors+=("bridge interface ${NET_BRIDGE_INTERFACE} does not exist (set TART_NET_BRIDGE_INTERFACE)")
  fi
  if [[ "${needs_key}" == "true" && -n "${TART_SSH_KEY_OP_REF:-}" && ( ! -f "${TEST_KEY_PATH}" || ! -f "${TEST_KEY_PUB_PATH}" ) ]]; then
    command -v op >/dev/null 2>&1 \
      || errors+=("ssh key files are missing and the 1Password CLI (op) is not installed to fetch them")
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    local e
    for e in "${errors[@]}"; do log_error "${e}"; done
    return 1
  fi
}

ensure_test_key() {
  if [[ ! -f "${TEST_KEY_PATH}" || ! -f "${TEST_KEY_PUB_PATH}" ]]; then
    "${VM_LIB_DIR}/fetch-tart-ssh-key.sh"
  fi
}

# The default "dhcp" resolver never sees bridged VMs, and "agent" can take
# >180s to start answering; "arp" reads the host ARP table and resolves in ~10s.
#
# The guest's MAC as it appears in `arp -an` (lowercase, no leading zeros).
guest_mac() {
  local cfg="${TART_HOME:-${HOME}/.tart}/vms/$1/config.json"
  [[ -f "${cfg}" ]] || return 0
  sed -n 's/.*"macAddress" *: *"\([^"]*\)".*/\1/p' "${cfg}" | tr 'A-F' 'a-f' \
    | awk -F: 'BEGIN{OFS=":"} NR==1{for(i=1;i<=NF;i++){sub(/^0+/,"",$i); if($i=="")$i="0"}; print $1,$2,$3,$4,$5,$6}'
}

# TODO: find why the host ARP table reads empty under `mise run` (the direct
# `/bin/bash tools/vm-testing/...` launch works), then drop the workaround notes in the docs.
# Resolves a bridged guest's IP, polling until it has sent traffic (the host
# ARP table has no entry before that). Two strategies, because on recent macOS
# a process's ancestry can make `arp` return an EMPTY table to some callers
# (seen under Homebrew's bash for `tart ip`): `tart ip --resolver arp` first,
# then a direct lookup of the guest's MAC through Apple's /bin/sh.
wait_for_guest_ip() {
  local deadline=$((SECONDS + BOOT_TIMEOUT_SECONDS)) ip mac
  mac="$(guest_mac "$1")"
  while [[ ${SECONDS} -lt ${deadline} ]]; do
    if ip="$(tart ip "$1" --resolver arp 2>/dev/null)" && [[ -n "${ip}" ]]; then
      echo "${ip}"
      return 0
    fi
    if [[ -n "${mac}" ]]; then
      ip="$(/bin/sh -c '/usr/sbin/arp -an' 2>/dev/null | awk -v m="${mac}" 'tolower($0) ~ " at " m " " {gsub(/[()]/,"",$2); print $2; exit}')"
      if [[ -n "${ip}" ]]; then
        echo "${ip}"
        return 0
      fi
    fi
    sleep 3
  done
  return 0
}

ssh_to() {
  local ip="$1"
  shift
  # shellcheck disable=SC2029  # client-side expansion of the command is intended
  ssh "${SSH_OPTS[@]}" "${GUEST_USER}@${ip}" "$@"
}

ssh_to_password() {
  local ip="$1"
  shift
  sshpass -p "${GUEST_PASSWORD}" ssh "${PASSWORD_SSH_OPTS[@]}" "${GUEST_USER}@${ip}" "$@"
}

wait_for_ssh_using() {
  local ssh_fn="$1" ip="$2" elapsed=0
  until "${ssh_fn}" "${ip}" true 2>/dev/null; do
    elapsed=$((elapsed + 5))
    [[ ${elapsed} -ge ${BOOT_TIMEOUT_SECONDS} ]] && return 1
    sleep 5
  done
}

wait_for_ssh() { wait_for_ssh_using ssh_to "$1"; }
wait_for_ssh_password() { wait_for_ssh_using ssh_to_password "$1"; }

# Retries "$@" when it fails with ssh's own exit code 255 (connection/auth
# failure, as opposed to the remote command's status). Output goes to LOG_FILE.
ssh_exec_with_retry() {
  local max_attempts=5 attempt=1 rc
  while :; do
    # rc=$? must live in the else: an `if` with no else and a false condition
    # exits 0 (POSIX), silently discarding the real failure.
    if "$@" >>"${LOG_FILE}" 2>&1; then
      return 0
    else
      rc=$?
    fi
    if [[ ${rc} -eq 255 && ${attempt} -lt ${max_attempts} ]]; then
      log_warning "Transient SSH failure (attempt ${attempt}/${max_attempts}), retrying..."
      attempt=$((attempt + 1))
      sleep 1
      continue
    fi
    return "${rc}"
  done
}

# Same as ssh_exec_with_retry, but streams output live as well as logging it.
ssh_exec_stream_with_retry() {
  local max_attempts=5 attempt=1 rc
  while :; do
    if "$@" 2>&1 | tee -a "${LOG_FILE}"; then
      return 0
    else
      rc=${PIPESTATUS[0]}
    fi
    if [[ ${rc} -eq 255 && ${attempt} -lt ${max_attempts} ]]; then
      log_warning "Transient SSH failure (attempt ${attempt}/${max_attempts}), retrying..."
      attempt=$((attempt + 1))
      sleep 1
      continue
    fi
    return "${rc}"
  done
}

# Installs Homebrew in a guest the same way the README's bootstrap step 1 does,
# and puts it on PATH for login shells (the installer doesn't edit ~/.zprofile
# in non-interactive mode). Usage: bootstrap_homebrew_in_guest <ssh_fn> <ip>
bootstrap_homebrew_in_guest() {
  local ssh_fn="$1" ip="$2"
  # shellcheck disable=SC2016  # the $(curl ...) must expand in the guest, not here
  ssh_exec_stream_with_retry "${ssh_fn}" "${ip}" \
    'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' \
    || return 1
  ssh_exec_with_retry "${ssh_fn}" "${ip}" \
    "grep -qs 'brew shellenv' ~/.zprofile || echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile" \
    || return 1
  # A plain non-login ssh command doesn't source ~/.zprofile; every command
  # needing brew on PATH must run through `zsh -lc`.
  ssh_exec_with_retry "${ssh_fn}" "${ip}" "zsh -lc 'command -v brew'"
}

# Deletes every cached OCI entry whose name contains $1.
delete_oci_cache_matching() {
  local pattern="$1" name
  while read -r name; do
    [[ -z "${name}" ]] && continue
    tart delete "${name}" >/dev/null 2>&1 && log_success "Deleted cached image: ${name}"
  done < <(tart list 2>/dev/null | awk -v p="${pattern}" 'NR>1 && $1=="OCI" && index($2,p){print $2}')
}

delete_vm() {
  local name="$1"
  if ! tart_vm_exists "${name}"; then
    log_info "No VM named ${name} — nothing to clean up"
    return 0
  fi
  tart stop "${name}" >/dev/null 2>&1 || true
  tart delete "${name}"
  log_success "Deleted ${name}"
}
