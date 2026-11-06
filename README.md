# dotfiles

A fast zsh profile for macOS: powerlevel10k, lazy-loaded completions, AWS and Kubernetes helpers, Ghostty and editor configs, all installed with one script.

## Quick start

```sh
gh repo fork sorinlg/dotfiles --clone ~/dotfiles && cd ~/dotfiles
cp config.sh.example config.sh   # set git_name and git_email at least
./install.sh
```

Start with a fork, not a plain clone: your fork is where your own tweaks live, and you can pull upstream improvements into it later ([keep your fork updated](docs/how-to/keep-your-fork-updated.md)).

Needs macOS, [Homebrew](https://brew.sh), and `git`. No 1Password account is required.

## Documentation

| I want to... | Read |
|---|---|
| See it work safely before touching my Mac | [Tutorial: your first install](docs/tutorials/first-install.md) |
| Fork, configure and install | [Fork and install](docs/how-to/fork-and-install.md) |
| Pull in upstream changes | [Keep your fork updated](docs/how-to/keep-your-fork-updated.md) |
| Add company-specific settings | [Add a work profile](docs/how-to/add-a-work-profile.md) |
| Sign commits | [Set up commit signing](docs/how-to/set-up-commit-signing.md) |
| Keep app preferences in sync | [Sync app preferences](docs/how-to/sync-app-preferences.md) |
| Verify changes in a throwaway VM | [Test in a VM](docs/how-to/test-in-a-vm.md) |
| Look up a setting or command | [Config](docs/reference/config.md), [Commands](docs/reference/commands.md), [Layout](docs/reference/repository-layout.md) |
| Understand the design | [Architecture](docs/explanation/architecture.md), [Performance](docs/explanation/performance.md), [Privacy and forks](docs/explanation/privacy-and-forks.md) |

A ready-made company profile to fork lives in [dotfiles-work-example](https://github.com/sorinlg/dotfiles-work-example).

## License

[MIT](LICENSE). Third-party files keep their own licenses, see [NOTICE](NOTICE).
