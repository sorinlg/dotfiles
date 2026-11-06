#!/bin/bash
# Apple's /bin/bash on purpose (not env bash): descendants of Homebrew's ad-hoc signed bash
# read an empty ARP table on recent macOS, which makes `tart ip` fail for bridged guests.
# Keep these scripts bash 3.2 compatible.

# Clones a golden Tart macOS image (see lib.sh for the tiers), runs
# dotfiles/install.sh inside the clone end-to-end, asserts the bootstrap
# succeeded, then deletes the clone. The golden images are never touched, so
# repeated runs always start from the same clean state.
#
# See README.md in this directory for the command sequence and cost.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/vm-testing/lib.sh
source "${SCRIPT_DIR}/lib.sh"

GRAPHICS=true
KEEP_VM=false
TIER=golden
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-graphics) GRAPHICS=false ;;
    --keep) KEEP_VM=true ;;
    --tier)
      TIER="${2:-}"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--tier golden|brew] [--no-graphics] [--keep] [--help]"
      echo "  --tier golden   (default) Clone the vanilla golden image: Homebrew is installed in the"
      echo "                  clone first, like a colleague's brand-new Mac"
      echo "  --tier brew     Clone the brew-warmed golden image: skips the Homebrew bootstrap (faster iteration)"
      echo "  --no-graphics   Boot headless instead of with a visible window (default: visible)"
      echo "  --keep          Leave the disposable VM running after the test for manual inspection"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

case "${TIER}" in
  golden) SOURCE_VM="${GOLDEN_VM}" ;;
  brew) SOURCE_VM="${GOLDEN_BREW_VM}" ;;
  *)
    echo "Unknown --tier '${TIER}' (expected golden or brew)" >&2
    exit 1
    ;;
esac

ROOT_DIR="${VM_ROOT_DIR}"
# Named after the worktree directory (not a timestamp): each worktree gets its
# own stable VM and can run in parallel with others; a rerun reuses the name
# after removing any leftover.
RUN_VM_NAME="${TART_RUN_VM_NAME:-smoke-test-$(basename "${ROOT_DIR}")}"
GRAPHICS_FLAG="--no-graphics"
[[ "${GRAPHICS}" == "true" ]] && GRAPHICS_FLAG=""

cleanup() {
  local exit_code=$?
  log_section "TEARDOWN"
  if [[ "${KEEP_VM}" == "true" ]]; then
    log_info "Leaving VM running for manual inspection (--keep): ${RUN_VM_NAME}"
    log_info "IP: ${GUEST_IP:-unknown} — ssh -i ${TEST_KEY_PATH} ${GUEST_USER}@${GUEST_IP:-<ip>}"
    log_info "Clean up later with: tart stop ${RUN_VM_NAME} && tart delete ${RUN_VM_NAME}"
  else
    kill "${TART_RUN_PID:-0}" >/dev/null 2>&1 || true
    if tart_vm_exists "${RUN_VM_NAME}"; then
      tart stop "${RUN_VM_NAME}" >/dev/null 2>&1 || true
      tart delete "${RUN_VM_NAME}" >/dev/null 2>&1 && log_success "Deleted disposable clone: ${RUN_VM_NAME}"
    fi
  fi
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Smoke test failed. Captured log:"
    cat "${LOG_FILE}" >&2
  fi
  rm -f "${LOG_FILE}"
  exit ${exit_code}
}
trap cleanup EXIT

ssh_guest() {
  ssh_to "${GUEST_IP}" "$@"
}

log_section "PREREQUISITES"
validate_prereqs --needs-key --needs-sshpass || exit 1
ensure_test_key
export_registry_credentials
log_success "tart found: $(tart --version 2>/dev/null || echo unknown)"

log_section "GOLDEN IMAGE"
if ! tart_vm_exists "${SOURCE_VM}"; then
  log_info "${SOURCE_VM} not found locally, building it (one-time; see tart-golden.sh)..."
  "${SCRIPT_DIR}/tart-golden.sh"
fi
log_success "Using ${SOURCE_VM} (tier: ${TIER})"

log_section "CLONE"
if tart_vm_exists "${RUN_VM_NAME}"; then
  log_warning "Found a leftover VM from a previous run: ${RUN_VM_NAME} — removing it first"
  tart stop "${RUN_VM_NAME}" >/dev/null 2>&1 || true
  tart delete "${RUN_VM_NAME}"
fi
tart clone "${SOURCE_VM}" "${RUN_VM_NAME}"
log_success "Cloned disposable VM: ${RUN_VM_NAME}"

log_section "BOOT"
# The host worktree is shared read-only via virtiofs so the bootstrap runs
# against this exact checkout (uncommitted changes included) without any git
# credentials in the VM. --net-bridged is required when the host's only working
# default route is a userspace VPN tunnel (e.g. a corporate VPN utun): Tart's
# default NAT can't ride it, so the guest couldn't reach the internet.
# shellcheck disable=SC2086
tart run "${RUN_VM_NAME}" ${GRAPHICS_FLAG} --dir="dotfiles-ro:${ROOT_DIR}:ro" --net-bridged="${NET_BRIDGE_INTERFACE}" &
TART_RUN_PID=$!
# With --keep the window must outlive this script.
[[ "${KEEP_VM}" == "true" ]] && disown "${TART_RUN_PID}"

log_info "Waiting for guest IP (up to ${BOOT_TIMEOUT_SECONDS}s)..."
GUEST_IP="$(wait_for_guest_ip "${RUN_VM_NAME}")"
if [[ -z "${GUEST_IP}" ]]; then
  log_error "Guest never reported an IP within ${BOOT_TIMEOUT_SECONDS}s."
  exit 1
fi
log_success "Guest IP: ${GUEST_IP}"

log_info "Waiting for SSH to accept connections..."
if ! wait_for_ssh "${GUEST_IP}"; then
  log_error "SSH never became reachable within ${BOOT_TIMEOUT_SECONDS}s."
  exit 1
fi
log_success "SSH is reachable"

if [[ "${TIER}" == "golden" ]]; then
  log_section "HOMEBREW BOOTSTRAP"
  log_info "Installing Homebrew in the clone (README bootstrap step 1; output streamed live)..."
  bootstrap_homebrew_in_guest ssh_to "${GUEST_IP}" || {
    log_error "Homebrew bootstrap failed"
    exit 1
  }
  log_success "Homebrew installed"
fi

log_section "BOOTSTRAP"
log_info "Copying the shared read-only worktree into a writable guest-local copy..."
ssh_exec_with_retry ssh_guest "cp -R '/Volumes/My Shared Files/dotfiles-ro' ~/dotfiles"

# A git worktree's .git is a pointer file to an absolute path in the main
# checkout, meaningless in the guest; it breaks install.sh's
# `git rev-parse --show-toplevel`. Reinit as a self-contained repo.
log_info "Reinitializing guest copy as a self-contained git repo..."
ssh_exec_with_retry ssh_guest "rm -rf ~/dotfiles/.git && git init -q ~/dotfiles"

log_info "Seeding VM-local config.sh (dummy identity, no secrets)..."
ssh_exec_with_retry ssh_guest "cp ~/dotfiles/tools/vm-testing/config.sh.vm ~/dotfiles/config.sh"

log_info "Running install.sh --no-reload inside the guest (output streamed live below)..."
# No signed-in 1Password in the guest, so skip that up-front gate; op-backed
# features still degrade gracefully with their own warnings. Runs via
# `zsh -lc` because Homebrew is only on PATH for login shells.
if ssh_exec_stream_with_retry ssh_guest "zsh -lc 'cd dotfiles && DOTFILES_SKIP_OP_CHECK=1 ./install.sh --no-reload'"; then
  log_success "install.sh completed"
else
  log_error "install.sh failed"
  exit 1
fi

log_section "ASSERTIONS"
log_info "Running tools/test-dotfiles.sh inside the guest (output streamed live below)..."
if ssh_exec_stream_with_retry ssh_guest "zsh -lc 'cd dotfiles && ./tools/test-dotfiles.sh'"; then
  log_success "test-dotfiles.sh passed"
else
  log_error "test-dotfiles.sh failed"
  exit 1
fi

log_section "RESULT"
log_success "Fresh-install smoke test passed"
