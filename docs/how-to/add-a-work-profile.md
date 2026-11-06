# Add a work profile

Company-specific settings (proxy certificates, private Go modules, work packages, work git identity) live in a separate repo, loaded through `config.sh`.

1. Fork the sample next to your work code:

   ```sh
   gh repo fork sorinlg/dotfiles-work-example --org your-org --clone ~/work/your-org/dotfiles-work
   ```

2. Edit its `shell-config.sh`, `gitconfig` and `Brewfile`.

3. Point `config.sh` at it:

   ```sh
   _work_config_path="${HOME}/work/your-org/dotfiles-work"
   _work_shell_config='shell-config.sh'
   _work_git_config='gitconfig'
   _brewfile_extra="${_work_config_path}/Brewfile"
   _go_private='github.com/your-org/*'
   ```

4. Reinstall:

   ```sh
   ./install.sh
   ```

`shell-config.sh` is sourced after every core module, so it can override them. `gitconfig` is included from `~/.gitconfig`.
