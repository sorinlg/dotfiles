#!/bin/bash
# Apple's /bin/bash on purpose (not env bash): descendants of Homebrew's ad-hoc signed bash
# read an empty ARP table on recent macOS, which makes `tart ip` fail for bridged guests.
# Keep these scripts bash 3.2 compatible.

# Provides the SSH keypair used to reach the Tart test VMs, written to
# tools/vm-testing/tart_test_key{,.pub} (gitignored).
#
# The key must be the SAME for every checkout on this machine, because the
# golden images are machine-global and the public key is baked into them.
#   - TART_SSH_KEY_OP_REF set (e.g. "op://Personal/dotfiles - tart - ssh"):
#     fetch "<ref>/private key" and "<ref>/public key" from 1Password, so the
#     key is shared across machines and worktrees.
#   - otherwise: generate an ed25519 key locally once. Fine for a single clone;
#     if you use several worktrees, set TART_SSH_KEY_OP_REF (or copy the key
#     files between them) so they all match the golden image.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/vm-testing/lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [[ -n "${TART_SSH_KEY_OP_REF:-}" ]]; then
  command -v op >/dev/null 2>&1 || { log_error "TART_SSH_KEY_OP_REF is set but the 1Password CLI (op) is not installed."; exit 1; }
  log_info "Fetching Tart test SSH key from 1Password (${TART_SSH_KEY_OP_REF})..."
  op read "${TART_SSH_KEY_OP_REF}/private key" --out-file "${TEST_KEY_PATH}" --file-mode 0600 --force >/dev/null
  op read "${TART_SSH_KEY_OP_REF}/public key" --out-file "${TEST_KEY_PUB_PATH}" --file-mode 0644 --force >/dev/null
else
  log_info "TART_SSH_KEY_OP_REF not set, generating a local test key..."
  rm -f "${TEST_KEY_PATH}" "${TEST_KEY_PUB_PATH}"
  ssh-keygen -q -t ed25519 -N "" -C "dotfiles-tart-test" -f "${TEST_KEY_PATH}"
fi
log_success "Tart test SSH key ready: ${TEST_KEY_PATH}{,.pub}"
rm -f "${LOG_FILE}"
