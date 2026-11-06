#!/bin/bash
# Apple's /bin/bash on purpose (not env bash): descendants of Homebrew's ad-hoc signed bash
# read an empty ARP table on recent macOS, which makes `tart ip` fail for bridged guests.
# Keep these scripts bash 3.2 compatible.

# Builds the local golden macOS images used by tart-smoke-test.sh (see lib.sh
# for the tier layout). Idempotent: existing tiers are left alone.
#
#   tart-golden.sh                 build tier 1 (vanilla + ssh key) and tier 2 (+ Homebrew)
#   tart-golden.sh --rebuild       delete both tiers for this macOS version, then rebuild
#   tart-golden.sh --prune         also delete golden images + cached OCI images of OTHER macOS versions
#   TART_MACOS_VERSION=sequoia tart-golden.sh   build another macOS version alongside

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/vm-testing/lib.sh
source "${SCRIPT_DIR}/lib.sh"

REBUILD=false
PRUNE=false
for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD=true ;;
    --prune) PRUNE=true ;;
    --help|-h)
      sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

cleanup() {
  local exit_code=$?
  kill "${GUEST_RUN_PID:-0}" >/dev/null 2>&1 || true
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Golden image build failed. Captured log:"
    cat "${LOG_FILE}" >&2
  fi
  rm -f "${LOG_FILE}"
  exit ${exit_code}
}
trap cleanup EXIT

log_section "PREREQUISITES"
validate_prereqs --needs-sshpass --needs-key || exit 1
ensure_test_key
export_registry_credentials

if [[ "${PRUNE}" == "true" ]]; then
  log_section "PRUNE (other macOS versions)"
  while read -r name; do
    [[ -z "${name}" || "${name}" == "${GOLDEN_VM}" || "${name}" == "${GOLDEN_BREW_VM}" ]] && continue
    delete_vm "${name}"
  done < <(tart list 2>/dev/null | awk 'NR>1 && $1=="local" && $2 ~ /^dotfiles-golden-/{print $2}')
  while read -r name; do
    [[ -z "${name}" || "${name}" == *"macos-${MACOS_VERSION}-"* ]] && continue
    tart delete "${name}" >/dev/null 2>&1 && log_success "Deleted cached image: ${name}"
  done < <(tart list 2>/dev/null | awk 'NR>1 && $1=="OCI" && index($2,"ghcr.io/cirruslabs/macos-"){print $2}')
fi

if [[ "${REBUILD}" == "true" ]]; then
  log_section "REBUILD"
  delete_vm "${GOLDEN_BREW_VM}"
  delete_vm "${GOLDEN_VM}"
fi

# Boots $1 headless, sets GUEST_RUN_PID/GUEST_IP.
boot_headless() {
  tart run "$1" --no-graphics --net-bridged="${NET_BRIDGE_INTERFACE}" >>"${LOG_FILE}" 2>&1 &
  GUEST_RUN_PID=$!
  GUEST_IP="$(wait_for_guest_ip "$1")"
  [[ -n "${GUEST_IP}" ]]
}

stop_guest() {
  kill "${GUEST_RUN_PID:-0}" >/dev/null 2>&1 || true
  tart stop "$1" >/dev/null 2>&1 || true
}

# A failed build step rolls back the half-built tier: a partial image cached
# under the final name would otherwise be silently reused by every later run.
build_failed() {
  local vm="$1" msg="$2"
  log_error "${msg}"
  stop_guest "${vm}"
  tart delete "${vm}" >/dev/null 2>&1 || true
  exit 1
}

log_section "TIER 1: ${GOLDEN_VM} (vanilla + ssh key)"
if tart_vm_exists "${GOLDEN_VM}"; then
  log_info "Already present, skipping"
else
  log_info "Pulling ${VANILLA_IMAGE} (one-time, multi-GB)..."
  tart pull "${VANILLA_IMAGE}"
  tart clone "${VANILLA_IMAGE}" "${GOLDEN_VM}"

  log_info "Seeding ssh key (the only password-auth use, so it retries)..."
  boot_headless "${GOLDEN_VM}" || build_failed "${GOLDEN_VM}" "${GOLDEN_VM} never reported an IP within ${BOOT_TIMEOUT_SECONDS}s"
  wait_for_ssh_password "${GUEST_IP}" || build_failed "${GOLDEN_VM}" "SSH never became reachable (password auth) within ${BOOT_TIMEOUT_SECONDS}s"
  ssh_exec_with_retry ssh_to_password "${GUEST_IP}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat "${TEST_KEY_PUB_PATH}")' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" \
    || build_failed "${GOLDEN_VM}" "Failed to seed ssh key"
  wait_for_ssh "${GUEST_IP}" || build_failed "${GOLDEN_VM}" "Seeded key was not accepted"
  ssh_exec_with_retry ssh_to "${GUEST_IP}" "sudo -n true" \
    || build_failed "${GOLDEN_VM}" "admin has no passwordless sudo; Homebrew's installer needs it"
  stop_guest "${GOLDEN_VM}"
  log_success "Tier 1 ready"
fi

log_section "TIER 2: ${GOLDEN_BREW_VM} (+ Homebrew)"
if tart_vm_exists "${GOLDEN_BREW_VM}"; then
  log_info "Already present, skipping"
else
  tart clone "${GOLDEN_VM}" "${GOLDEN_BREW_VM}"
  boot_headless "${GOLDEN_BREW_VM}" || build_failed "${GOLDEN_BREW_VM}" "${GOLDEN_BREW_VM} never reported an IP within ${BOOT_TIMEOUT_SECONDS}s"
  wait_for_ssh "${GUEST_IP}" || build_failed "${GOLDEN_BREW_VM}" "SSH never became reachable within ${BOOT_TIMEOUT_SECONDS}s"
  log_info "Installing Homebrew (pulls Command Line Tools if missing; slow)..."
  bootstrap_homebrew_in_guest ssh_to "${GUEST_IP}" || build_failed "${GOLDEN_BREW_VM}" "Homebrew bootstrap failed"
  stop_guest "${GOLDEN_BREW_VM}"
  log_success "Tier 2 ready"
fi

log_section "RESULT"
tart list | awk -v a="${GOLDEN_VM}" -v b="${GOLDEN_BREW_VM}" 'NR==1 || $2==a || $2==b'
