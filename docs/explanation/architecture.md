# Architecture

`install.sh` does three kinds of work: install packages (Homebrew, zsh plugins, Node and Go toolchains), place configuration, and verify the result (compile, test, benchmark).

Configuration is placed in one of three ways, each a small function in `lib/utils`:

- **Link** (`_do_link`): a symlink from your home directory to the repo, for files the repo owns. Edit the repo file and the change is live.
- **Template** (`_do_template`): a file generated from `*.tmpl` with values from `config.sh`, for things that differ per person, like your git identity and signing setup. Generated files are gitignored.
- **Seed** (`_do_seed`): a copy made once, for files an app rewrites itself (Codex). The app owns it afterwards.

Apps that store settings in macOS `defaults` rather than a file (Rectangle, Clipy, MonitorControl) are imported from a captured plist, and kept in sync by `config:app:pull|push`. One registry in `lib/utils-app-defaults` describes them all.

## Loading order

A new shell reads `~/.zshrc`, which sources `entrypoint/source_profile.sh`. That loads `config.sh`, then the modules in `lib/zsh/` by filename prefix:

- `1-*` basic shell setup, history, keybindings, plugins
- `2-*` initializes completion; must precede anything that registers completions
- `3-*` per-tool configuration
- `80-*` tools that must load last, such as Atuin, which has to rebind Ctrl-R after fzf does

Your [work profile](../how-to/add-a-work-profile.md) is sourced after all of them, so it can override anything.

## Where your own settings go

Values go in `config.sh`. Company settings go in a work profile repo. Everything else is a change to your fork. Keeping the first two out of tracked files is what lets you merge upstream without conflicts.
