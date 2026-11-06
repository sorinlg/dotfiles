# Config reference

All settings live in `config.sh` at the repo root (gitignored; start from `config.sh.example`). It is sourced by the installer and by every new shell.

| Key | Default | Purpose |
|---|---|---|
| `git_name`, `git_email` | none, required | Identity written to `~/.gitconfig_credentials` |
| `git_signing_key` | empty | SSH public key for commit signing; empty disables signing |
| `_git_ssh_sign_program` | empty | Signer binary, for example 1Password's `op-ssh-sign` |
| `_git_allowed_signers_file` | `~/.ssh/allowed_signers` | File git uses to verify signatures |
| `_homebrew_prefix` | `/opt/homebrew` | Use `/usr/local` on Intel |
| `_homebrew_github_token` | empty | Optional; raises Homebrew's GitHub API rate limit |
| `_config_go_path`, `_go_root` | none | Go paths used until Go is managed by GVM |
| `_go_private` | empty | Value for `GOPRIVATE`, for example `github.com/your-org/*` |
| `_brewfile_extra` | empty | Space-separated extra Brewfiles installed after `Brewfile` |
| `_atuin_op_item` | empty | 1Password item (`op://Vault/Item`) used to log in to Atuin sync; empty skips Atuin login and the `op` requirement |
| `_work_config_path` | empty | Directory of your [work profile](../how-to/add-a-work-profile.md) |
| `_work_shell_config` | empty | Shell file inside it, sourced after all core modules |
| `_work_git_config` | empty | Git config inside it, included from `~/.gitconfig` |
| `_k9s_sync_colours` | `true` | Generate k9s and sofka color overrides from the prompt colors on install |
| `GIT_PS1_*` | see example | Git prompt display options |

Atuin login expects the item to have `username` and `password` fields and an `Atuin Sync` section with a `Sync Key` field.

## Backing up `config.sh`

`mise run config:dotfiles:push` and `config:dotfiles:pull` store and restore `config.sh` as a 1Password document (requires `op`). Both show a diff and ask first.
