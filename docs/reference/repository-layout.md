# Repository layout

| Path | Contents |
|---|---|
| `install.sh`, `uninstall.sh` | Installer and remover |
| `config.sh.example` | Template for your gitignored `config.sh` |
| `Brewfile` | Packages, installed with `brew bundle` |
| `mise.toml` | Task definitions (`mise tasks`) |
| `entrypoint/source_profile.sh` | Loaded from `~/.zshrc`; sources everything below |
| `rc.d/` | `.zshrc` template and files symlinked into `$HOME` |
| `lib/zsh/` | Shell modules, loaded in filename order (see [Architecture](../explanation/architecture.md)) |
| `lib/utils*` | Link, template and seed helpers; completion framework; app-defaults registry |
| `lib/git/` | Git aliases, templates, completion |
| `lib/<app>/` | Config for one app: ghostty, cmux, vscode, zed, atuin, ccstatusline, codex, clipy, rectangle, monitorcontrol, itsycal, mimestream, docker, vim |
| `lib/build/` | Bytecode compilation |
| `tools/` | Scripts: `awss`, test suite, benchmark, cleanup, config sync, k9s skins |
| `tools/vm-testing/` | Tart-based fresh-install test |
| `docs/` | This documentation |
