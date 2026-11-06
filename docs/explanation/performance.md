# Performance

Shell startup is a feature. Targets: under 100 ms excellent, under 300 ms good, under 500 ms acceptable. Measure with `mise run benchmark -- 5`.

Three techniques keep it fast:

- **Lazy loading.** Completions and heavy tools (kubectl, terraform, aws, nvm, gvm) register a stub and load for real on first use. The shared helpers are `_register_lazy_completion_zsh` and `_register_lazy_completion_bash` in `lib/utils-completion`.
- **Bytecode.** `install.sh` compiles the zsh modules to `.zwc` files, which zsh prefers automatically. They are generated, not committed.
- **Builtins over forks.** Startup code uses zsh parameter expansion instead of spawning `dirname`, `basename` or `readlink`.

Any change on the startup path (`entrypoint/`, `lib/zsh/`, a new completion) should be benchmarked before and after. Add a completion only when you will use it often: each one is a startup-cost trade-off.
