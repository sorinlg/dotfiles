# cmux sources this file before loading its bundled Ghostty zsh integration.
# Powerlevel10k already emits OSC 133 shell-integration markers, so loading
# both integrations can produce competing prompt boundaries during resize.
if [[ -n ${CMUX_SHELL_INTEGRATION_DIR-} ]]; then
  export CMUX_LOAD_GHOSTTY_ZSH_INTEGRATION=0
fi
