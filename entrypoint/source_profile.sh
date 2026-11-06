#!/usr/bin/env zsh

# compute project root folder using ZSH builtins
_profile_repo_root="${${(%):-%N}:A:h:h}"

# Export DOTFILES_DIR for use by functions
export DOTFILES_DIR="${_profile_repo_root}"

# load config if it exists
[[ -f "$_profile_repo_root/config.sh" ]] && . "$_profile_repo_root/config.sh"

# compute library root folder
_lib_path="${_profile_repo_root}/lib"

# set execution environment
# Cache kernel type using OSTYPE builtin
__kernel="${OSTYPE%%[0-9.]*}"
__tools="${_profile_repo_root}/tools"
__gopath="${_config_go_path}"
__local_bin="${HOME}/.bin"

# prepare local bin folder
[[ -d "${__local_bin}" ]] || mkdir -p "${__local_bin}"
export PATH="${__local_bin}:${PATH}"

# Load completion utilities early (needed by tool configurations)
. "${_lib_path}/utils-completion"

# Load all configuration modules (ZSH automatically uses .zwc if available)
# 80-tools-atuin loads after the 3-tools-* group: fzf-tab/fzf rebind Ctrl-R to
# fzf-history-widget during their own init, so atuin's bindkey has to run
# after them to win.
_zsh_configs=(
    "1-shell-setup"
    "2-shell-completion-zsh-load"
    "3-tools-aws"
    "3-tools-fzf"
    "3-tools-ghostty"
    "3-tools-git"
    "3-tools-k8s"
    "3-tools-misc"
    "80-tools-atuin"
)

for config in "${_zsh_configs[@]}"; do
    . "${_lib_path}/zsh/${config}"
done
unset _zsh_configs config

# Load external work configurations if specified
if [[ -n "${_work_config_path:-}" && -n "${_work_shell_config:-}" ]]; then
    local work_shell_file="${_work_config_path}/${_work_shell_config}"
    if [[ -f "$work_shell_file" ]]; then
        . "$work_shell_file"
    fi
fi

# Load completion scripts - awss lazy loaded
_awss_lazy_init() {
    [[ -n $_awss_lazy_loaded ]] && return
    _awss_lazy_loaded=1
    . "${__tools}/awss/awss_completion.sh"
}

# Register completions after all tools are loaded
if (( $+functions[compdef] )); then
    # Register awss completion with lazy loading
    _awss_completion_wrapper() {
        _awss_lazy_init
        if declare -f _awss_completion >/dev/null 2>&1; then
            _awss_completion "$@"
        else
            _default
        fi
    }
    if (( $+commands[awss] )); then
        compdef _awss_completion_wrapper awss 2>/dev/null
    fi

    # terraform completion is now handled by generic function

    # Register tf-manage2 completion (optimized approach)
    if (( $+commands[tf] )); then
        # Add homebrew functions to fpath immediately (required for autoload to work)
        local homebrew_functions_path="${_homebrew_prefix:-/opt/homebrew}/share/zsh/site-functions"
        if (( ! ${fpath[(Ie)$homebrew_functions_path]} )); then
            fpath=($homebrew_functions_path $fpath)
        fi

        # Autoload the completion function (doesn't actually load it yet, lazy by design)
        autoload -U _tf && compdef _tf tf 2>/dev/null
    fi
fi
