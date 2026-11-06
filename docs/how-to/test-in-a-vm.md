# Test in a VM

Run the full install in a disposable macOS VM ([Tart](https://tart.run), Apple Silicon only) before it reaches your real machine. Re-run whenever `install.sh`, `Brewfile` or anything under `lib/` or `rc.d/` changes.

1. One-time setup:

   ```sh
   brew install cirruslabs/cli/tart sshpass
   gh auth login        # optional: avoids stale registry credentials when pulling images
   mise run tart:golden # pulls the base image and builds two local images, several GB
   ```

2. Run the test (a window opens so you can watch):

   ```sh
   /bin/bash tools/vm-testing/tart-smoke-test.sh
   ```

   `mise run tart:test` is equivalent but fails to find the guest on some macOS versions (see Troubleshooting).

   It clones a golden image, installs Homebrew, runs `install.sh`, runs `tools/test-dotfiles.sh`, then deletes the clone.

3. Keep the VM to poke around afterwards:

   ```sh
   /bin/bash tools/vm-testing/tart-smoke-test.sh --keep
   ```

   The script prints the IP and an `ssh` command. Remove it with `mise run tart:clean`.

Useful variants:

```sh
mise run tart:test -- --no-graphics      # headless
mise run tart:test -- --tier brew        # skip the Homebrew install, faster iteration
mise run tart:golden -- --rebuild        # rebuild the golden images from scratch
mise run tart:golden -- --prune          # drop golden images and cached images of other macOS versions
mise run tart:clean -- --all             # also delete both golden images and the cached image
```

To try another macOS release, set `TART_MACOS_VERSION` (for example `sequoia`) and run `tart:golden`; add `--prune` afterwards to reclaim the old version's disk.

## Troubleshooting

- **Guest never gets an IP:** the VM bridges onto your default network interface. Override with `TART_NET_BRIDGE_INTERFACE='en0'` (Wi-Fi) or the interface of your wired connection.
- **"never reported an IP" although the VM is running:** on recent macOS the host ARP table can read as empty for processes launched through some parents (seen with Homebrew's bash and with `mise run`), so the guest's address is never found. The scripts use `#!/bin/bash` (Apple's) for that reason. If `mise run tart:test` hits this, run the script directly from your shell, which works:

  ```sh
  /bin/bash tools/vm-testing/tart-smoke-test.sh --keep
  ```

- **No internet in the guest:** Tart's default NAT cannot ride a VPN tunnel, so the scripts use bridged networking. A network that requires device enrollment will still block the guest.
- **Several worktrees:** every checkout must use the same SSH key, because the key is baked into the golden image. Set `TART_SSH_KEY_OP_REF` to a 1Password item, or copy `tools/vm-testing/tart_test_key*` between checkouts.

See [Commands reference](../reference/commands.md) for every variable.
