#!/bin/bash
# Apple's /bin/bash on purpose (not env bash): descendants of Homebrew's ad-hoc signed bash
# read an empty ARP table on recent macOS, which makes `tart ip` fail for bridged guests.
# Keep these scripts bash 3.2 compatible.

# Cleans up Tart VMs left behind by tart-smoke-test.sh --keep. By default
# only removes this worktree's disposable run VM; --all also removes both
# golden tiers for this macOS version and the cached upstream OCI image
# (forcing a full re-pull and re-provision next time).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/vm-testing/lib.sh
source "${SCRIPT_DIR}/lib.sh"

CLEAN_ALL=false
for arg in "$@"; do
  case "$arg" in
    --all) CLEAN_ALL=true ;;
    --help|-h)
      echo "Usage: $0 [--all] [--help]"
      echo "  --all   Also delete both golden tiers (${GOLDEN_VM}, ${GOLDEN_BREW_VM}) and the cached ${MACOS_VERSION} vanilla OCI image"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

validate_prereqs "$@" || exit 1

RUN_VM_NAME="${TART_RUN_VM_NAME:-smoke-test-$(basename "${VM_ROOT_DIR}")}"
delete_vm "${RUN_VM_NAME}"

if [[ "${CLEAN_ALL}" == "true" ]]; then
  delete_vm "${GOLDEN_BREW_VM}"
  delete_vm "${GOLDEN_VM}"
  delete_oci_cache_matching "macos-${MACOS_VERSION}-vanilla"
fi
rm -f "${LOG_FILE}"
