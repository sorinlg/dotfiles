# Set up commit signing

1. Put your SSH public key in `config.sh`:

   ```sh
   git_signing_key='ssh-ed25519 AAAA...'
   ```

2. If your key lives in 1Password, also set its signer:

   ```sh
   _git_ssh_sign_program='/Applications/1Password.app/Contents/MacOS/op-ssh-sign'
   ```

3. Reinstall, then register the key so `git log --show-signature` can verify it:

   ```sh
   ./install.sh
   mise run git-signing -- "$(cat ~/.ssh/id_ed25519.pub)"
   ```

Leave `git_signing_key` empty to leave signing off. Signing is configured in `~/.gitconfig_credentials`, generated from `lib/git/credentials.tmpl`.
