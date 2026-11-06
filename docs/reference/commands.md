# Commands reference

## mise tasks

Run `mise tasks` for the live list. Extra arguments go after `--`.

| Task | Does |
|---|---|
| `setup` | Run `./install.sh` (`--no-reload`, `--dry-run`, `--help`) |
| `uninstall` | Run `./uninstall.sh` (interactive) |
| `test` | Run `tools/test-dotfiles.sh` |
| `benchmark -- N` | Time shell startup over N runs |
| `clean`, `clean-all` | Remove temp files, or also backups and compiled files |
| `compile` | Compile zsh files to `.zwc` bytecode |
| `k9s-skins` | Generate k9s skins and sofka color overrides from prompt colors |
| `git-signing -- <pubkey>` | Register a public key in `allowed_signers` |
| `config:dotfiles:pull`, `config:dotfiles:push` | Restore or back up `config.sh` via 1Password |
| `config:diff`, `config:app:pull`, `config:app:push` | Diff, capture or apply app preferences (`-- --app rectangle\|clipy\|monitorcontrol`) |
| `tart:golden` | Build golden VM images (`--rebuild`, `--prune`) |
| `tart:test` | Fresh-install test in a VM (`--tier golden\|brew`, `--no-graphics`, `--keep`) |
| `tart:clean` | Delete the test VM (`--all`: also golden images and the cached image) |
| `tart:key:get` | Create or fetch the VM test SSH key |

## Shell helpers

| Command | Does |
|---|---|
| `reload-shell` | Restart the shell with the new configuration |
| `update-shell` | Update dotfiles and reinstall |
| `awss` | Interactive AWS profile and region switcher |
| `ks` | Kubernetes context switcher |

## Environment variables

| Variable | Read by | Effect |
|---|---|---|
| `DOTFILES_DIR` | `install.sh` | Checkout location written into `~/.zshrc` (default: the repo root) |
| `ZSH_PLUGINS_DIR` | `install.sh` | Plugin directory (default `~/.config/zsh/plugins`) |
| `DOTFILES_SKIP_OP_CHECK` | `install.sh` | Skip the 1Password CLI check |
| `DOTFILES_SKIP_NODE_BOOTSTRAP` | `install.sh` | Skip the `nvm install --lts` step |
| `DOTFILES_SKIP_GO_BOOTSTRAP` | `install.sh` | Skip the GVM and Go install |
| `PROFILING_MODE=1` | shell startup | Print a zsh startup profile |
| `TART_MACOS_VERSION` | `tools/vm-testing` | macOS release for the VM images (default `tahoe`) |
| `TART_NET_BRIDGE_INTERFACE` | `tools/vm-testing` | Host interface the VM bridges onto (default: the default-route interface) |
| `TART_SSH_KEY_OP_REF` | `tools/vm-testing` | `op://` item holding the VM test key; unset generates one locally |
| `TART_GOLDEN_VM`, `TART_VANILLA_IMAGE`, `TART_RUN_VM_NAME` | `tools/vm-testing` | Override image and VM names |
| `TART_GUEST_USER`, `TART_GUEST_PASSWORD` | `tools/vm-testing` | Guest login (default `admin`/`admin`) |
| `TART_REGISTRY_USERNAME`, `TART_REGISTRY_PASSWORD` | `tart` | Registry credentials; derived from `gh` when unset |
