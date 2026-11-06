---
name: dotfiles-usage
description: Use when installing, configuring, testing or changing this dotfiles repo, or when asked how to do something with it. Points to the right doc and the routine steps (config backup, VM test, benchmark).
---

# Using this dotfiles repo

Documentation lives in `docs/` (Diataxis). Find the task, open the doc, follow it; do not
reconstruct steps from memory.

| Task | Doc |
|---|---|
| First look, safely in a VM | `docs/tutorials/first-install.md` |
| Fork, configure, install | `docs/how-to/fork-and-install.md` |
| Pull in upstream changes | `docs/how-to/keep-your-fork-updated.md` |
| Company-specific settings | `docs/how-to/add-a-work-profile.md` |
| Commit signing | `docs/how-to/set-up-commit-signing.md` |
| App preferences (Rectangle, Clipy, MonitorControl) | `docs/how-to/sync-app-preferences.md` |
| Verify an install change in a throwaway VM | `docs/how-to/test-in-a-vm.md` |
| A setting, task or variable | `docs/reference/config.md`, `docs/reference/commands.md` |
| Why it is built this way | `docs/explanation/` |

## Routine steps worth surfacing

- **After editing `config.sh`, back it up** (it is gitignored, so this is its only copy):
  `mise run config:dotfiles:push` (needs the 1Password CLI; shows a diff and asks first).
  On a new machine restore it with `mise run config:dotfiles:pull`.
- **Changed `install.sh`, `Brewfile`, `lib/` or `rc.d/`?** Run `mise run test`, then a fresh-install
  check: `/bin/bash tools/vm-testing/tart-smoke-test.sh` (see the VM how-to for why not `mise run`).
- **Touched shell startup (`entrypoint/`, `lib/zsh/`, completions)?** Run `mise run benchmark -- 5`
  before and after; keep startup under 300 ms.
- **Before committing:** keep personal values out of tracked files. Identity, keys and paths go in
  `config.sh`; company values go in a work profile repo. Check `git status` does not list `config.sh`.
