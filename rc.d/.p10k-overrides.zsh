################################################
#  standard class colors                       #
################################################
export _COLOR_TEST=082      # green
export _COLOR_DEV=039       # blue
export _COLOR_CI=105        # purple (ANSI 256)
export _COLOR_PRE=208       # orange
export _COLOR_PROD=160      # red
export _COLOR_DEFAULT=226   # yellow

typeset -g MY_STANDARD_CLASSES=(
  '*prod*'          PROD
  '*pre*'           PRE
  '*stage*'         PRE
  '*staging*'       PRE
  '*dev*'           DEV
  '*ci*'            CI
  '*integration*'   CI
  '*build*'         CI
  '*lab*'           TEST
  '*sandbox*'       TEST
  '*test*'          TEST
  '*'               DEFAULT
)

apply_color_fg() {
  local str=$1
  local _config_prefix=$2
  local pat class var color

  classes_var="${_config_prefix}_CLASSES"
  for pat class in "${(@P)classes_var}"; do
    if [[ $str == ${~pat} ]]; then
      var="${_config_prefix}_${(U)class}_FOREGROUND"
      color="${(P)var}"
      break
    fi
  done

  # If no match was found, use the default color
  if [[ -z $color ]]; then
    var="${_config_prefix}_DEFAULT_FOREGROUND"
    color="${(P)var}"
  fi

  # Apply the color to the string
  echo -n "%F{$color}$str%f"
}

# The list of segments shown on the left. Fill it with the most important segments.
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  # =========================[ Line #1 ]=========================
  dir                     # current directory
  vcs                     # git status
  aws                     # aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
  kubecontext             # current kubernetes context (https://kubernetes.io/)
  # =========================[ Line #2 ]=========================
  newline                 # \n
  prompt_char             # prompt symbol
)

# The list of segments shown on the right. Fill it with less important segments.
  # Right prompt on the last prompt line (where you are typing your commands) gets
  # automatically hidden when the input line reaches it. Right prompt above the
  # last prompt line gets hidden if it would overlap with left prompt.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    # =========================[ Line #1 ]=========================
    status                  # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs         # presence of background jobs
    direnv                  # direnv status (https://direnv.net/)
    asdf                    # asdf version manager (https://github.com/asdf-vm/asdf)
    virtualenv              # python virtual environment (https://docs.python.org/3/library/venv.html)
    # anaconda                # conda environment (https://conda.io/)
    # pyenv                   # python environment (https://github.com/pyenv/pyenv)
    goenv                   # go environment (https://github.com/syndbg/goenv)
    nodenv                  # node.js version from nodenv (https://github.com/nodenv/nodenv)
    # nvm                     # node.js version from nvm (https://github.com/nvm-sh/nvm)
    nodeenv                 # node.js environment (https://github.com/ekalinin/nodeenv)
    # node_version          # node.js version
    # go_version            # go version (https://golang.org)
    # rust_version          # rustc version (https://www.rust-lang.org)
    # dotnet_version        # .NET version (https://dotnet.microsoft.com)
    # php_version           # php version (https://www.php.net/)
    # laravel_version       # laravel php framework version (https://laravel.com/)
    # java_version          # java version (https://www.java.com/)
    # package               # name@version from package.json (https://docs.npmjs.com/files/package.json)
    # rbenv                   # ruby version from rbenv (https://github.com/rbenv/rbenv)
    rvm                     # ruby version from rvm (https://rvm.io)
    fvm                     # flutter version management (https://github.com/leoafarias/fvm)
    luaenv                  # lua version from luaenv (https://github.com/cehoffman/luaenv)
    jenv                    # java version from jenv (https://github.com/jenv/jenv)
    plenv                   # perl version from plenv (https://github.com/tokuhirom/plenv)
    perlbrew                # perl version from perlbrew (https://github.com/gugod/App-perlbrew)
    phpenv                  # php version from phpenv (https://github.com/phpenv/phpenv)
    scalaenv                # scala version from scalaenv (https://github.com/scalaenv/scalaenv)
    haskell_stack           # haskell version from stack (https://haskellstack.org/)
    # kubecontext             # current kubernetes context (https://kubernetes.io/)
    terraform               # terraform workspace (https://www.terraform.io)
    terraform_version     # terraform version (https://www.terraform.io)
    # aws                     # aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
    aws_eb_env              # aws elastic beanstalk environment (https://aws.amazon.com/elasticbeanstalk/)
    azure                   # azure account name (https://docs.microsoft.com/en-us/cli/azure)
    gcloud                  # google cloud cli account and project (https://cloud.google.com/)
    google_app_cred         # google application credentials (https://cloud.google.com/docs/authentication/production)
    toolbox                 # toolbox name (https://github.com/containers/toolbox)
    context                 # user@hostname
    nordvpn                 # nordvpn connection status, linux only (https://nordvpn.com/)
    ranger                  # ranger shell (https://github.com/ranger/ranger)
    yazi                    # yazi shell (https://github.com/sxyazi/yazi)
    nnn                     # nnn shell (https://github.com/jarun/nnn)
    lf                      # lf shell (https://github.com/gokcehan/lf)
    xplr                    # xplr shell (https://github.com/sayanarijit/xplr)
    vim_shell               # vim shell indicator (:sh)
    midnight_commander      # midnight commander shell (https://midnight-commander.org/)
    nix_shell               # nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html)
    chezmoi_shell           # chezmoi shell (https://www.chezmoi.io/)
    # vi_mode               # vi mode (you don't need this if you've enabled prompt_char)
    # vpn_ip                # virtual private network indicator
    # load                  # CPU load
    # disk_usage            # disk usage
    # ram                   # free RAM
    # swap                  # used swap
    todo                    # todo items (https://github.com/todotxt/todo.txt-cli)
    timewarrior             # timewarrior tracking status (https://timewarrior.net/)
    taskwarrior             # taskwarrior task count (https://taskwarrior.org/)
    per_directory_history   # Oh My Zsh per-directory-history local/global indicator
    # cpu_arch              # CPU architecture
    time                    # current time
    battery                 # internal battery
    # =========================[ Line #2 ]=========================
    newline
    # ip                    # ip address and bandwidth usage for a specified network interface
    # public_ip             # public IP address
    # proxy                 # system-wide http/https/ftp proxy
    # wifi                  # wifi speed
    # example               # example user-defined segment (see prompt_example function below)
  )

##################################[ dir: current directory ]##################################
# Current directory background color.
typeset -g POWERLEVEL9K_DIR_BACKGROUND=234
# Default current directory foreground color.
typeset -g POWERLEVEL9K_DIR_FOREGROUND=208
# Enable bold text
typeset -g POWERLEVEL9K_DIR_PATH_HIGHLIGHT_BOLD=true
# Hide the folder icon before the current directory.
typeset -g POWERLEVEL9K_DIR_VISUAL_IDENTIFIER_EXPANSION=''
# If directory is too long, shorten some of its segments to the shortest possible unique
# prefix. The shortened directory can be tab-completed to the original.
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last

################################################
#  AWS                                         #
################################################
function aws_custom_contents() {
  # switch on $P9K_KUBECONTEXT_NAME
  # if it contains "prod" return "PROD"
  # if it contains "sandbox" return "TEST"
  __aws_extra_info="${${:-$P9K_AWS_REGION}:#default}"
  [ -n "${__aws_extra_info}" ] && __aws_extra_info=" (${__aws_extra_info})"

  echo -n "$(apply_color_fg "${P9K_AWS_PROFILE}" 'MY_AWS')${__aws_extra_info}"
}

# always show AWS segment
unset POWERLEVEL9K_AWS_SHOW_ON_COMMAND

# configure color classes
typeset -g MY_AWS_CLASSES=( ${MY_STANDARD_CLASSES[@]} )
typeset -g MY_AWS_TEST_FOREGROUND=${_COLOR_TEST}
typeset -g MY_AWS_DEV_FOREGROUND=${_COLOR_DEV}
typeset -g MY_AWS_CI_FOREGROUND=${_COLOR_CI}
typeset -g MY_AWS_PRE_FOREGROUND=${_COLOR_PRE}
typeset -g MY_AWS_PROD_FOREGROUND=${_COLOR_PROD}

# set default colors
typeset -g POWERLEVEL9K_AWS_DEFAULT_BACKGROUND=234
typeset -g POWERLEVEL9K_AWS_DEFAULT_FOREGROUND=4

# include region in a different color
typeset -g POWERLEVEL9K_AWS_CONTENT_EXPANSION='${$(aws_custom_contents)}'

################################################
#  Kubernetes                                  #
################################################
function kubecontext_custom_contents() {
  # switch on $P9K_KUBECONTEXT_NAME
  # if it contains "prod" return "PROD"
  # if it contains "sandbox" return "TEST"
  __k8s_color="%F{${POWERLEVEL9K_KUBECONTEXT_FOREGROUND}}"
  __reset_color='%f'

  __k8s_sep="${__k8s_color}/${__reset_color}"

  __ns_info="${${:-$P9K_KUBECONTEXT_NAMESPACE}:#default}"
  [ -n "${__ns_info}" ] && __ns_info="${__k8s_sep}${__ns_info}"

  echo -n "$(apply_color_fg "${P9K_KUBECONTEXT_NAME}" 'MY_KUBECONTEXT')${__ns_info}"
}

# always show kubecontext segment
unset POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND

# configure color classes
typeset -g MY_KUBECONTEXT_CLASSES=( ${MY_STANDARD_CLASSES[@]} )
typeset -g MY_KUBECONTEXT_TEST_FOREGROUND=${_COLOR_TEST}
typeset -g MY_KUBECONTEXT_DEV_FOREGROUND=${_COLOR_DEV}
typeset -g MY_KUBECONTEXT_CI_FOREGROUND=${_COLOR_CI}
typeset -g MY_KUBECONTEXT_PRE_FOREGROUND=${_COLOR_PRE}
typeset -g MY_KUBECONTEXT_PROD_FOREGROUND=${_COLOR_PROD}
typeset -g MY_KUBECONTEXT_DEFAULT_FOREGROUND=${_COLOR_DEFAULT}

# disable default colors
unset POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND
unset POWERLEVEL9K_KUBECONTEXT_DEFAULT_BACKGROUND

# set default colors
typeset -g POWERLEVEL9K_KUBECONTEXT_BACKGROUND=234
typeset -g POWERLEVEL9K_KUBECONTEXT_FOREGROUND=5

# disable default content expansion
unset POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION

# include namespace in a different color
typeset -g POWERLEVEL9K_KUBECONTEXT_CONTENT_EXPANSION='${$(kubecontext_custom_contents)}'

#####################################[ vcs: git status ]######################################
function my_git_formatter() {
  emulate -L zsh

  if [[ -n $P9K_CONTENT ]]; then
    # If P9K_CONTENT is not empty, use it. It's either "loading" or from vcs_info (not from
    # gitstatus plugin). VCS_STATUS_* parameters are not available in this case.
    typeset -g my_git_format=$P9K_CONTENT
    return
  fi

  # Styling for different parts of Git status.
  local       meta='%7F' # white foreground
  local      clean='%0F' # black foreground
  local   modified='%0F' # black foreground
  local  untracked='%0F' # black foreground
  local conflicted='%1F' # red foreground

  local res

  if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
    local branch=${(V)VCS_STATUS_LOCAL_BRANCH}
    # If local branch name is at most 32 characters long, show it in full.
    # Otherwise show the first 12 … the last 12.
    # Tip: To always show local branch name in full without truncation, delete the next line.
    (( $#branch > 32 )) && branch[18,-1]="…"  # <-- this line
    res+="${clean}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${branch//\%/%%}"
  fi

  if [[ -n $VCS_STATUS_TAG
        # Show tag only if not on a branch.
        # Tip: To always show tag, delete the next line.
        && -z $VCS_STATUS_LOCAL_BRANCH  # <-- this line
      ]]; then
    local tag=${(V)VCS_STATUS_TAG}
    # If tag name is at most 32 characters long, show it in full.
    # Otherwise show the first 12 … the last 12.
    # Tip: To always show tag name in full without truncation, delete the next line.
    # (( $#tag > 32 )) && tag[13,-13]="…"  # <-- this line
    res+="${meta}#${clean}${tag//\%/%%}"
  fi

  # Display the current Git commit if there is no branch and no tag.
  # Tip: To always display the current Git commit, delete the next line.
  [[ -z $VCS_STATUS_LOCAL_BRANCH && -z $VCS_STATUS_TAG ]] &&  # <-- this line
    res+="${meta}@${clean}${VCS_STATUS_COMMIT[1,8]}"

  # Show tracking branch name if it differs from local branch.
  if [[ -n ${VCS_STATUS_REMOTE_BRANCH:#$VCS_STATUS_LOCAL_BRANCH} ]]; then
    res+="${meta}:${clean}${(V)VCS_STATUS_REMOTE_BRANCH//\%/%%}"
  fi

  # Display "wip" if the latest commit's summary contains "wip" or "WIP".
  if [[ $VCS_STATUS_COMMIT_SUMMARY == (|*[^[:alnum:]])(wip|WIP)(|[^[:alnum:]]*) ]]; then
    res+=" ${modified}wip"
  fi

  if (( VCS_STATUS_COMMITS_AHEAD || VCS_STATUS_COMMITS_BEHIND )); then
    # ⇣42 if behind the remote.
    (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}⇣${VCS_STATUS_COMMITS_BEHIND}"
    # ⇡42 if ahead of the remote; no leading space if also behind the remote: ⇣42⇡42.
    (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" "
    (( VCS_STATUS_COMMITS_AHEAD  )) && res+="${clean}⇡${VCS_STATUS_COMMITS_AHEAD}"
  elif [[ -n $VCS_STATUS_REMOTE_BRANCH ]]; then
    # Tip: Uncomment the next line to display '=' if up to date with the remote.
    # res+=" ${clean}="
  fi

  # Push remote counts duplicate ⇡/⇣ when the push target is the upstream branch
  # (e.g. remote.pushDefault set to the upstream remote).
  if [[ $VCS_STATUS_PUSH_REMOTE_NAME != $VCS_STATUS_REMOTE_NAME ||
        $VCS_STATUS_REMOTE_BRANCH != $VCS_STATUS_LOCAL_BRANCH ]]; then
    # ⇠42 if behind the push remote.
    (( VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" ${clean}⇠${VCS_STATUS_PUSH_COMMITS_BEHIND}"
    (( VCS_STATUS_PUSH_COMMITS_AHEAD && !VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" "
    # ⇢42 if ahead of the push remote; no leading space if also behind: ⇠42⇢42.
    (( VCS_STATUS_PUSH_COMMITS_AHEAD  )) && res+="${clean}⇢${VCS_STATUS_PUSH_COMMITS_AHEAD}"
  fi
  # *42 if have stashes.
  (( VCS_STATUS_STASHES        )) && res+=" ${clean}*${VCS_STATUS_STASHES}"
  # 'merge' if the repo is in an unusual state.
  [[ -n $VCS_STATUS_ACTION     ]] && res+=" ${conflicted}${VCS_STATUS_ACTION}"
  # ~42 if have merge conflicts.
  (( VCS_STATUS_NUM_CONFLICTED )) && res+=" ${conflicted}~${VCS_STATUS_NUM_CONFLICTED}"
  # +42 if have staged changes.
  (( VCS_STATUS_NUM_STAGED     )) && res+=" ${modified}+${VCS_STATUS_NUM_STAGED}"
  # !42 if have unstaged changes.
  (( VCS_STATUS_NUM_UNSTAGED   )) && res+=" ${modified}!${VCS_STATUS_NUM_UNSTAGED}"
  # ?42 if have untracked files. It's really a question mark, your font isn't broken.
  # See POWERLEVEL9K_VCS_UNTRACKED_ICON above if you want to use a different icon.
  # Remove the next line if you don't want to see untracked files at all.
  (( VCS_STATUS_NUM_UNTRACKED  )) && res+=" ${untracked}${(g::)POWERLEVEL9K_VCS_UNTRACKED_ICON}${VCS_STATUS_NUM_UNTRACKED}"
  # "─" if the number of unstaged files is unknown. This can happen due to
  # POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY (see below) being set to a non-negative number lower
  # than the number of files in the Git index, or due to bash.showDirtyState being set to false
  # in the repository config. The number of staged and untracked files may also be unknown
  # in this case.
  (( VCS_STATUS_HAS_UNSTAGED == -1 )) && res+=" ${modified}─"

  typeset -g my_git_format=$res
}

################################################
#  Performance Optimizations                  #
################################################

# Set reasonable limit for git repo scanning for better performance
typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=4000

################################################
#  Customizations                             #
################################################
## Show command execution time if it exceeds this threshold (in seconds).
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=2

################[ terraform_version: It shows active terraform version (https://www.terraform.io) ]#################
typeset -g POWERLEVEL9K_TERRAFORM_VERSION_SHOW_ON_COMMAND='terraform|tf'

################################################
#  Terminal shell integration                 #
################################################
# Emit p10k's own OSC 133 semantic prompt markers (`133;A` prompt-start,
# `133;B` input-start) on every render, resize redraws included.
typeset -g POWERLEVEL9K_TERM_SHELL_INTEGRATION=true

# ...and make $PS1 advertise that we do, which the setting above does NOT do on
# its own.
#
# cmux ships Ghostty's shell integration, which emits a `133;P`
# (prompt-continuation) marker instead of `133;A` unless PS1 already carries a
# prompt-start marker. cmux then fails to recognise a resize redraw as a prompt,
# treats it as fresh output, and leaves an orphaned prompt row behind on every
# SIGWINCH - dragging a pane divider stacks up dozens of them. Its guard is a
# plain substring test:
#
#     if [[ $PS1 != *$'%{\e]133;A'* ]]; then ... emit 133;P ... fi
#
# POWERLEVEL9K_TERM_SHELL_INTEGRATION alone never satisfies that test: p10k keeps
# the marker in _p9k_prompt_prefix_left and expands it at render time, so `$PS1`
# itself only ever contains the `133;B` half. The conditional below carries the
# literal marker inside a branch that needs >=1000 background jobs to render, so
# the escape is never actually emitted - rendering stays byte-identical - but the
# guard now matches and cmux takes the `133;A` path.
#
# This must hang off p10k-on-pre-prompt: p10k forces _p9k_precmd to the end of
# precmd_functions and rebuilds PROMPT afterwards, so a plain precmd hook's
# append is silently discarded.
#
# See cmux#2789, cmux#3052, powerlevel10k#1200.
function p10k-on-pre-prompt() {
  [[ $PS1 == *$'%{\e]133;A'* ]] || PS1+=$'%(1000j.%{\e]133;A\a%}.)'
}

# Codex Desktop exposes only a code-theme selector, not custom ANSI colors.
# Its integrated terminal is xterm.js, so sync its runtime palette with the
# Monokai Pro Filter Spectrum palette configured in Ghostty. CODEX_APP_TITLE is
# injected only into Codex Desktop terminal sessions, keeping other terminals
# on their native palette.
function _codex_terminal_sync_palette() {
  precmd_functions=("${(@)precmd_functions:#_codex_terminal_sync_palette}")

  local -a palette=(
    '#363537' '#FC618D' '#7BD88F' '#FCE566'
    '#FD9353' '#948AE3' '#5AD4E6' '#F7F1FF'
    '#696769' '#FC618D' '#7BD88F' '#FCE566'
    '#FD9353' '#948AE3' '#5AD4E6' '#F7F1FF'
  )
  local index

  for index in {0..15}; do
    printf '\e]4;%d;%s\a' "$index" "${palette[index + 1]}"
  done
  printf '\e]10;#F7F1FF\a\e]11;#000000\a\e]12;#F7F1FF\a'
}

if [[ -n ${CODEX_APP_TITLE-} && ${TERM-} == xterm-256color ]]; then
  typeset -ag precmd_functions
  precmd_functions=(_codex_terminal_sync_palette "${precmd_functions[@]}")
fi
