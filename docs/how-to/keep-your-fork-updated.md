# Keep your fork updated

1. Sync your fork's default branch with upstream:

   ```sh
   gh repo sync --source sorinlg/dotfiles
   git pull
   ```

   If you have local commits, add the upstream once and merge instead:

   ```sh
   git remote add upstream https://github.com/sorinlg/dotfiles.git
   git fetch upstream
   git merge upstream/main
   ```

2. Reinstall to apply it (`install.sh` is safe to re-run):

   ```sh
   ./install.sh
   ```

3. Check nothing regressed:

   ```sh
   mise run test
   ```

Keep personal values in `config.sh` and your [work profile](add-a-work-profile.md) rather than editing tracked files: that is what keeps merges conflict-free.
