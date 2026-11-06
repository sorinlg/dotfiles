# VM testing

Fresh-install test in a disposable macOS VM, built on [Tart](https://tart.run).

```sh
mise run tart:golden   # one time: build the golden images
mise run tart:test     # clone, boot, install, assert, delete
```

Full instructions, flags and troubleshooting: [docs/how-to/test-in-a-vm.md](../../docs/how-to/test-in-a-vm.md). Variables: [docs/reference/commands.md](../../docs/reference/commands.md).

| File | Role |
|---|---|
| `lib.sh` | Shared helpers and image naming (tiers explained in its header) |
| `tart-golden.sh` | Builds and prunes the golden images |
| `tart-smoke-test.sh` | The test itself |
| `tart-clean.sh` | Removes the test VM and, with `--all`, the golden images |
| `fetch-tart-ssh-key.sh` | Creates or fetches the VM test key |
| `config.sh.vm` | Dummy `config.sh` used inside the VM |
