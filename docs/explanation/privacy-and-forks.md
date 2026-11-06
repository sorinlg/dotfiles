# Privacy and forks

This repo is meant to be forked, so it must never contain anything personal or company-specific. The rules that keep it that way:

- **Identity and secrets live in `config.sh`**, which is gitignored. The same goes for generated `lib/git/config` and `lib/git/credentials`.
- **Company settings live in a separate work profile repo** that can stay private. See [Add a work profile](../how-to/add-a-work-profile.md).
- **Nothing in the installer reads a secret from a file in the repo.** The only secret-backed feature, Atuin login, reads from 1Password at install time and is skipped when unconfigured.

Before committing a change, check that no host names, account IDs, tokens, personal paths or employer names slipped into tracked files, and that `git status` does not list `config.sh`.

## Why a fork, not a template

A fork keeps a link to upstream, so you can merge improvements ([guide](../how-to/keep-your-fork-updated.md)). The trade-off is that a fork of a public repo is public. If your customizations must be private, keep them in `config.sh` and a work profile, or duplicate the repo into a private one and add this one as `upstream`.

## History

This repository's history was recreated from a clean tree. Earlier history was discarded because it contained personal and employer-specific details that cannot be reliably scrubbed commit by commit.
