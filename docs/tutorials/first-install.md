# Your first install

In this tutorial you will fork the repo, configure it, and watch a complete install run inside a disposable macOS virtual machine, so nothing on your own Mac changes. You need an Apple Silicon Mac, about 60 GB of free disk, and about 30 minutes (most of it waiting for downloads).

1. Fork and clone:

   ```sh
   gh repo fork sorinlg/dotfiles --clone ~/dotfiles
   cd ~/dotfiles
   ```

2. Install the VM tooling:

   ```sh
   brew install cirruslabs/cli/tart sshpass mise
   ```

3. Create your config. The VM test uses its own dummy config, but you need yours for step 6:

   ```sh
   cp config.sh.example config.sh
   ```

   Open `config.sh` and set `git_name` and `git_email`.

4. Build the base images (one time, several GB):

   ```sh
   mise run tart:golden
   ```

5. Run the install in a fresh VM and keep it open:

   ```sh
   /bin/bash tools/vm-testing/tart-smoke-test.sh --keep
   ```

   (`mise run tart:test -- --keep` does the same but cannot find the VM's address on some macOS versions; see the [troubleshooting note](../how-to/test-in-a-vm.md#troubleshooting).)

   A macOS window opens. The script installs Homebrew, copies your checkout in, runs `install.sh`, and runs the test suite. It ends with `Fresh-install smoke test passed`.

6. Click into the VM window, open Ghostty (or Terminal), and look around: the prompt, completions (press Tab after `git `), `awss`, `ks`.

7. Delete the VM when you are done:

   ```sh
   mise run tart:clean
   ```

You have now seen the full install working without risk. To do it for real, follow [Fork and install](../how-to/fork-and-install.md).
