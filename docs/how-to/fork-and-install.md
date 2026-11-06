# Fork and install

1. Fork and clone:

   ```sh
   gh repo fork sorinlg/dotfiles --clone ~/dotfiles
   cd ~/dotfiles
   ```

2. Create your config and edit it (see [Config reference](../reference/config.md)):

   ```sh
   cp config.sh.example config.sh
   ```

   At minimum set `git_name` and `git_email`. `config.sh` is gitignored, so it never leaves your machine.

3. Preview, then install:

   ```sh
   ./install.sh --dry-run
   ./install.sh
   ```

4. Open a new terminal, or run `exec zsh`.

Existing `~/.zshrc`, `~/.zshenv` and `~/.p10k*.zsh` are backed up with a timestamp suffix first. To undo everything, run `./uninstall.sh`.

**No 1Password?** Nothing to do: the `op` check is skipped while `_atuin_op_item` is empty.
**Not on Apple Silicon?** Set `_homebrew_prefix='/usr/local'` in `config.sh`.
**Customizing:** change files in your fork, never in your home directory. `install.sh` re-links them.
