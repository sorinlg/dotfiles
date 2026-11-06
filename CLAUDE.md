# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

User-facing documentation lives in `docs/` (Diátaxis: tutorials, how-to, reference, explanation); keep it lean and update it with the change that makes it stale.

## Repository Overview

This is a personal dotfiles repository that provides a customized CLI profile for zsh, built on top of oh-my-zsh with powerlevel10k theme. The repository uses a modular architecture with symlink-based configuration management.

## Setup and Installation

### Prerequisites
Before installation, configure personal settings in `config.sh`:
```bash
git_name='Your Name'
git_email='your.email@domain.com'
_config_go_path='your_go_path'
_homebrew_github_token='your_github_token'
```

### Installation
```bash
./install.sh
```

This script handles:
- Installing required tools via Homebrew (git, gawk, fzf, switcher)
- Setting up oh-my-zsh and plugins (zsh-syntax-highlighting, zsh-autosuggestions, fzf-tab)
- Installing powerlevel10k theme
- Creating symlinks for configuration files
- Activating the new profile

## Architecture

The repository follows a structured approach:

### Core Structure
- `entrypoint/source_profile.sh` - Main entry point that loads all configurations
- `lib/` - Library of configuration modules
  - `lib/utils` - Utility functions (`_do_link`, `_do_template`)
  - `lib/zsh/` - Modular zsh configuration files loaded in order
  - `lib/git/` - Git configuration templates and aliases
  - `lib/vim/` - Vim configurations
- `rc.d/` - Runtime configuration files (symlinked to home directory)
- `tools/` - Custom shell tools and scripts
- `config.sh` - Personal configuration variables

### Configuration Loading Order
The system loads configurations in this sequence:
1. Shell completion (bash/zsh)
2. Shell history and keybindings
3. Oh-my-zsh setup
4. Tool-specific configurations (aws, fzf, git, k8s, misc, vim)
5. Final zsh completion loading

### Custom Tools
- `awss` - AWS profile and region switcher with shell completion

## Configuration Management

The system uses two main utility functions from `lib/utils`:

- `_do_link()` - Creates/updates symlinks, handles broken links automatically
- `_do_template()` - Processes template files with variable substitution (##GIT_NAME##, ##GIT_EMAIL##)

Configuration files are organized by category in `lib/zsh/` with numeric prefixes indicating load order:
- `1-*` - Basic shell setup
- `2-*` - Shell completion init (`compdef`/`compinit`) — must load before any `3-*`/`80-*` tool file that registers completions
- `3-*` - Tool-specific configurations
- `80-*` - Tools that must load after the `3-*` group (e.g. to win a keybinding another tool rebinds during its own init)

## Common Development Commands

`mise tasks` lists every task below; each also remains runnable as a direct script (mise is additive, not required). `mise run <task> -- <args>` forwards trailing args to the underlying script.

### Installation and Updates
```bash
mise run setup                  # Full installation/reinstallation (./install.sh)
mise run setup -- --no-reload   # Install without activating new shell
mise run uninstall               # Uninstall (./uninstall.sh, interactive)
```

### Testing and Validation
```bash
mise run test                       # Run comprehensive test suite
mise run benchmark -- 3             # Benchmark shell performance (3 runs)
mise run benchmark -- 10            # More thorough benchmark (10 runs)
```

### Maintenance and Cleanup
```bash
mise run clean                          # Basic cleanup (temp files)
mise run clean-all                      # Full cleanup including compiled files
mise run clean -- --dry-run --all       # Preview cleanup actions
mise run compile                        # Compile zsh configs to .zwc bytecode
mise run k9s-skins                      # Generate k9s skins + sofka color overrides (p10k class colors)
mise run git-signing -- <ssh-pub-key>   # Set up SSH commit signing
```

### Development Workflow
When making changes to configurations:
1. Edit files in the repository (never modify home directory files directly)
2. Test changes: `mise run test`
3. Check performance impact: `mise run benchmark -- 5`
4. Clean up development artifacts: `mise run clean`
5. Re-run installer if needed: `mise run setup -- --no-reload`

## Performance Architecture

The system is optimized for fast shell startup (~100ms target):
- **Lazy Loading**: Completions and heavy tools are loaded on-demand
- **ZSH Compilation**: Configuration files are compiled to `.zwc` bytecode
- **Generic Completion Framework**: Located in `lib/utils-completion`, provides utilities for lazy loading completions
- **Modular Loading**: Tools load in sequence via `entrypoint/source_profile.sh`

### Completion System Architecture
The completion system uses a sophisticated lazy loading approach:
- `_register_lazy_completion_zsh()` - Registers completions that load on first use
- `_register_lazy_completion_bash()` - Handles bash completion integration
- Tool-specific completions in `3-tools-*` files use these utilities
- AWS CLI uses custom bash completion wrapper (`_aws_completion_init`)
- Terraform uses generic lazy loading (`_terraform_lazy_init`)

## Development Notes

- All configuration changes should be made in the repository, not directly in home directory files
- `install.sh` writes the checkout location into `~/.zshrc` from `rc.d/.zshrc.template` (`##DOTFILES_DIR##`), so the repo can live anywhere
- Custom tools are symlinked to `${HOME}/.bin` which is added to PATH
- Git configurations use template system for personalization with `##VARIABLE##` placeholders
- `g ci` (`lib/git/aliases`) auto-adds a `Refs: <TICKET>` trailer extracted from the branch name (e.g. `feature/CLOUD-1234-x` → `Refs: CLOUD-1234`); override with `REFS=KEY-1 g ci`, opt out with `REFS= g ci` or `g cin`
- The system automatically manages zsh plugins and theme installation
- Don't modify `rc.d/.p10k.zsh` - this is generated by `p10k configure`; use `rc.d/.p10k-overrides.zsh` for customizations
- Defaults-backed app preferences (Rectangle, Clipy, ...): registered in `lib/utils-app-defaults` (`_APP_DEFAULTS_REGISTRY`) — domain, process name, repo plist path, and the noise-key glob patterns to strip are all defined there as the single source of truth (not duplicated in prose here). `tools/config-sync.sh` (via `mise run config:app:pull -- --app <name>` / `config:app:push -- --app <name>` / `config:diff -- --app <name>`) curates, diffs, and asks for confirmation automatically — there's no need to hand-run `defaults export`/`plutil`/PlistBuddy anymore. `install.sh` imports every registered app's plist via the same registry in a loop (`_defaults_import_and_restart`) and restarts the app if running (prefs are cached in memory). Adding a new app = one registry entry, no edits to `install.sh` or `tools/config-sync.sh`.
- Rectangle: `lib/rectangle/com.knollsoft.Rectangle.plist` — it does not and cannot grant the Accessibility permission Rectangle needs to move windows; that's a manual one-time step (see README.md Prerequisites).
- Clipy: `lib/clipy/com.clipy-app.Clipy.plist` — curation keeps intentional user-configured behavior/position (hotkeys, history size, menu-bar icon position via `NSStatusItem Preferred Position Item-0`, `loginItem`) and strips updater/analytics/telemetry/timestamp bookkeeping (Sparkle, StoreKit, Firebase). It does not and cannot grant the Accessibility/Input Monitoring permissions Clipy needs for its global hotkeys; that's a manual one-time step (see README.md Prerequisites).
- Codex: `~/.codex/config.toml` is app-owned - Codex Desktop rewrites it in place (appending, not merging, TOML tables). It is **seeded once** from `lib/codex/config.toml` by `install.sh` (via `_do_seed`), never symlinked. Don't hand-edit `lib/codex/config.toml` expecting it to reach an existing machine.
- Docker: `docker-credential-env` is installed via `isometry/tap/docker-credential-env` in the Brewfile. `install.sh` (`lib/docker/configure-credential-env.sh`) ensures `~/.docker/config.json`'s `credsStore` is `"env"` and that the fixed registry list hardcoded in that script (`env_registries`) maps to `"env"` under `credHelpers`, via a targeted `jq` merge - add-only, it never touches `auths` or any other `credHelpers` entry already on the machine. To add a registry, edit `env_registries` in `lib/docker/configure-credential-env.sh`. Docker Desktop itself is Brewfile-cask-only (`cask "docker"`); its `settings.json` is not curated.
- Always test against regressions with `mise run test` (`tools/test-dotfiles.sh`); verify a from-scratch install with `mise run tart:test` (see `docs/how-to/test-in-a-vm.md`)
- Always check performance impact with `mise run benchmark` (`tools/benchmark-shell-startup.sh`) - aim for <500ms startup time
- Performance targets: Excellent (<100ms), Good (<300ms), Acceptable (<500ms)
- Regular cleanup with `mise run clean` (`tools/cleanup-dotfiles.sh`) keeps the repository tidy
- Node.js/npx: `install.sh` runs `nvm install --lts` right after `brew bundle` (brew only installs the `nvm` binary, not a node version) - node stays owned by nvm, not `mise`, to avoid two competing version sources. Opt out with `DOTFILES_SKIP_NODE_BOOTSTRAP=1` for disposable/CI installs.
- Compiled files (*.zwc) are automatically generated and should not be committed
- GNU userland (macOS): `lib/zsh/3-tools-misc` prepends each Brewfile GNU package's `libexec/gnubin` to PATH (and `gnuman` to MANPATH) for interactive shells. Scripts launched from the shell inherit it, so repo scripts must stay GNU/BSD-portable (e.g. `mktemp` with an explicit `XXXXXX` template, no `sed -i ''`). Add a new GNU package to both the Brewfile and the `_gnu_pkgs` list.
- When checking against leaking personal settings and sensitive information always check if detected files are present in git index. config.sh and @lib/git/config should be in @.gitignore
