#!/usr/bin/env bash

# Comprehensive Dotfiles Test Suite
# Tests shell functionality, file structure, and completion system
#
# Completion tests include:
# K8s Tools: kubectl, k9s, helm, k (function), argocd, flux
# Infrastructure: aws (custom completion), terraform (bash completion), tf-manage2 (homebrew completion)
# Utilities: op (1password), kcl (configuration language)
# System: git (built-in zsh completion)
# Framework: Generic completion utilities (_register_lazy_completion_*)

set -e

echo "🔍 Dotfiles Test Suite"

failures=0

record_failure() {
    failures=$((failures + 1))
}

run_with_timeout() {
    local seconds="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "${seconds}s" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${seconds}s" "$@"
    else
        "$@"
    fi
}

# Test 1: Shell works
zsh -c 'exit' 2>/dev/null && echo "✅ Shell spawn: PASS" || { echo "❌ Shell spawn: FAIL"; record_failure; }

# Test 2: Config files exist
[[ -f ~/.zshrc ]] && echo "✅ Config files: PASS" || { echo "❌ Config files: FAIL"; record_failure; }

# Test 3: Compilation exists
[[ -f lib/zsh/1-shell-setup.zwc ]] && echo "✅ Compilation: PASS" || { echo "❌ Compilation: FAIL"; record_failure; }

# Test 4: Repository structure
[[ -d "lib/zsh" ]] && echo "✅ Repository: PASS" || { echo "❌ Repository: FAIL"; record_failure; }

# Test 5: Meslo Nerd Font resolvable (referenced by lib/ghostty/config).
# Homebrew's font-meslo-lg-nerd-font cask registers the family as
# "MesloLGS Nerd Font", NOT "MesloLGS NF" (that name belongs to Powerlevel10k's
# own separately-patched font, a different file entirely).
meslo_font_family="MesloLGS Nerd Font"
if command -v fc-list >/dev/null 2>&1 && fc-list | grep -q "${meslo_font_family}:"; then
    echo "✅ Font ${meslo_font_family}: PASS"
elif system_profiler SPFontsDataType 2>/dev/null | grep -q "Family: ${meslo_font_family}$"; then
    echo "✅ Font ${meslo_font_family}: PASS"
else
    echo "❌ Font ${meslo_font_family}: FAIL (not resolvable via fc-list or system_profiler)"
    record_failure
fi

echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Testing Completions"

# Test completions for key tools (with lazy loading)
test_completion() {
    local tool="$1"
    local completion_func="$2"
    local trigger_cmd="$3"

    if command -v "$tool" >/dev/null 2>&1; then
        if run_with_timeout 3 zsh -i -c "$trigger_cmd >/dev/null 2>&1; [[ \${+functions[$completion_func]} -eq 1 ]]" 2>/dev/null; then
            echo "✅ $tool completion: PASS"
        else
            echo "❌ $tool completion: FAIL"
            record_failure
        fi
    else
        echo "⚠️  $tool: not installed"
    fi
}

# Test completion-only registration (no command wrapper, but completion infra exists)
test_generic_completion() {
    local tool="$1"
    local expected_completion_func="$2"
    local trigger_cmd="$3"

    if command -v "$tool" >/dev/null 2>&1; then
        # Test that completion infrastructure is registered (lazy init function exists)
        # and that TAB completion would work (compdef is registered)
        local lazy_init_func="_${tool}_compl_lazy_init"
        if run_with_timeout 3 zsh -i -c "type $lazy_init_func >/dev/null 2>&1 && compdef -d $tool 2>/dev/null" 2>/dev/null; then
            echo "✅ $tool completion: PASS"
        else
            echo "❌ $tool completion: FAIL"
            record_failure
        fi
    else
        echo "⚠️  $tool: not installed"
    fi
}

# Test alias/function completions (like k alias that uses kubectl completion)
test_function_completion() {
    local func_name="$1"
    local expected_completion_func="$2"
    local trigger_cmd="$3"
    local description="$4"

    # Test that completion infrastructure is registered for the alias/function
    local lazy_init_func="_${func_name}_compl_lazy_init"
    if run_with_timeout 3 zsh -i -c "type $lazy_init_func >/dev/null 2>&1 && compdef -d $func_name 2>/dev/null" 2>/dev/null; then
        echo "✅ $func_name completion: PASS"
    else
        echo "❌ $func_name completion: FAIL"
        record_failure
    fi
}

echo "📋 K8s Tools Completions"
echo "────────────────────────"
# Kubernetes tools registered with generic functions
test_generic_completion "kubectl" "_kubectl" "kubectl version --client"
test_generic_completion "k9s" "_k9s" "k9s version"
test_generic_completion "helm" "_helm" "helm version"

# Test k function (wrapper for kubectl)
test_function_completion "k" "_kubectl" "k version --client" "kubectl wrapper function"

# Advanced K8s tools
test_generic_completion "argocd" "_argocd" "argocd version --client"
test_generic_completion "flux" "_flux" "flux version --client"

echo ""
echo "🛠️  Infrastructure Tools Completions"
echo "────────────────────────────────────"
# AWS CLI (uses bash completion via aws_completer)
if command -v aws >/dev/null 2>&1; then
    # Test that AWS lazy loading works (custom completion with bash completion)
    # 15s: the first `aws --version` after a fresh install is slow (cold Python cache)
    if run_with_timeout 15 zsh -i -c "aws --version >/dev/null 2>&1; type _aws_completion_init >/dev/null 2>&1" 2>/dev/null; then
        echo "✅ aws completion: PASS"
    else
        echo "❌ aws completion: FAIL"
        record_failure
    fi
else
    echo "⚠️  aws: not installed"
fi

# Terraform (uses bash completion via completion-only registration)
if command -v terraform >/dev/null 2>&1; then
    # Test that terraform completion infrastructure is registered
    if run_with_timeout 3 zsh -i -c "type _terraform_compl_lazy_init >/dev/null 2>&1 && compdef -d terraform 2>/dev/null" 2>/dev/null; then
        echo "✅ terraform completion: PASS"
    else
        echo "❌ terraform completion: FAIL"
        record_failure
    fi
else
    echo "⚠️  terraform: not installed"
fi

# Atuin (eager shell hook + lazy subcommand completion)
# Note: checks ATUIN_SESSION (set unconditionally by `atuin init zsh`) rather than
# `bindkey`, since zle/job-control may be unavailable in non-tty test environments.
if command -v atuin >/dev/null 2>&1; then
    if run_with_timeout 3 zsh -i -c '[[ -n "$ATUIN_SESSION" ]]' 2>/dev/null; then
        echo "✅ atuin shell integration: PASS"
    else
        echo "❌ atuin shell integration: FAIL"
        record_failure
    fi
    if run_with_timeout 3 zsh -i -c "type _atuin_compl_lazy_init >/dev/null 2>&1" 2>/dev/null; then
        echo "✅ atuin completion: PASS"
    else
        echo "❌ atuin completion: FAIL"
        record_failure
    fi
    # Sync is only expected once Atuin is logged in (install.sh logs in via 1Password
    # when _atuin_op_item is configured); a fresh fork has no account to sync from.
    if ! run_with_timeout 5 atuin status 2>/dev/null | grep -q '^Username:'; then
        echo "⚠️  atuin sync: skipped (not logged in)"
    else
        atuin_history_count=$(run_with_timeout 5 atuin history list --format="{time}" 2>/dev/null | wc -l | tr -d '[:space:]')
        if [[ "$atuin_history_count" -gt 0 ]] 2>/dev/null; then
            echo "✅ atuin sync: PASS"
        else
            echo "❌ atuin sync: FAIL"
            record_failure
        fi
    fi
else
    echo "⚠️  atuin: not installed"
fi

# tf-manage2 (uses homebrew-distributed completion)
if command -v tf >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c '[[ ${+functions[_tf]} -eq 1 || ${+functions[_tf_manage2]} -eq 1 ]]' 2>/dev/null; then
        echo "✅ tf completion: PASS"
    else
        echo "❌ tf completion: FAIL"
        record_failure
    fi
else
    echo "⚠️  tf: not installed"
fi

echo ""
echo "🔧 Utility Tools Completions"
echo "─────────────────────────────"
# 1Password CLI
test_generic_completion "op" "_op" "op --version"

# KCL (Configuration Language)
test_generic_completion "kcl" "_kcl" "kcl version"

echo ""
echo "💻 Development Tools Discovery"
echo "────────────────────────────"
# Test that tools are discoverable in PATH (not shadowed by functions)
# Python tools (should use shims, not functions)
if command -v python3 >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'type python3 | grep -v "shell function"' >/dev/null 2>&1; then
        echo "✅ python3: discoverable in PATH"
    else
        echo "❌ python3: shadowed by function"
        record_failure
    fi
else
    echo "⚠️  python3: not installed"
fi

# Ruby tools (should use shims, not functions)
if command -v ruby >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'type ruby | grep -v "shell function"' >/dev/null 2>&1; then
        echo "✅ ruby: discoverable in PATH"
    else
        echo "❌ ruby: shadowed by function"
        record_failure
    fi
else
    echo "⚠️  ruby: not installed"
fi

# Java tools (should be in PATH, not functions)
if command -v java >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'type java | grep -v "shell function"' >/dev/null 2>&1; then
        echo "✅ java: discoverable in PATH"
    else
        echo "❌ java: shadowed by function"
        record_failure
    fi
else
    echo "⚠️  java: not installed"
fi

# Go tools (should be in PATH, not functions)
if command -v go >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'type go | grep -v "shell function"' >/dev/null 2>&1; then
        echo "✅ go: discoverable in PATH"
    else
        echo "❌ go: shadowed by function"
        record_failure
    fi
else
    echo "⚠️  go: not installed"
fi

# Node.js tools (should be in PATH via nvm's PATH pre-population, not functions)
if command -v node >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'type node | grep -v "shell function"' >/dev/null 2>&1; then
        echo "✅ node: discoverable in PATH"
    else
        echo "❌ node: shadowed by function"
        record_failure
    fi
else
    echo "⚠️  node: not installed"
fi

if command -v npx >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'type npx | grep -v "shell function"' >/dev/null 2>&1; then
        echo "✅ npx: discoverable in PATH"
    else
        echo "❌ npx: shadowed by function"
        record_failure
    fi
else
    echo "⚠️  npx: not installed"
fi

echo ""
echo "🐃 GNU Userland (darwin)"
echo "────────────────────────"
if [[ "$(uname -s)" == "Darwin" ]]; then
    for gnu_check in "sed:sed --version" "grep:grep --version" "awk:awk --version" "find:find --version" "tar:tar --version" "make:make --version" "ls:ls --version" "getopt:getopt --version"; do
        gnu_tool="${gnu_check%%:*}"
        if run_with_timeout 2 zsh -i -c "${gnu_check#*:} 2>/dev/null | grep -qi -e gnu -e util-linux" 2>/dev/null; then
            echo "✅ ${gnu_tool}: GNU"
        else
            echo "❌ ${gnu_tool}: not GNU (check Brewfile / lib/zsh/3-tools-misc)"
            record_failure
        fi
    done
    if run_with_timeout 2 zsh -i -c 'man -w sed 2>/dev/null | grep -q gnuman' 2>/dev/null; then
        echo "✅ man sed: GNU page"
    else
        echo "❌ man sed: not GNU page (MANPATH)"
        record_failure
    fi
    if run_with_timeout 2 zsh -i -c 'ls -d / && ll -d / && echo x | grep x' >/dev/null 2>&1; then
        echo "✅ ls/ll/grep aliases: PASS"
    else
        echo "❌ ls/ll/grep aliases: FAIL"
        record_failure
    fi
    if command -v eza >/dev/null 2>&1; then
        echo "✅ eza: installed"
    else
        echo "❌ eza: missing (used by fzf-tab cd preview)"
        record_failure
    fi
else
    echo "⚠️  skipped: not darwin"
fi

echo ""
echo "🎨 Prompt Git Formatter"
echo "───────────────────────"
# ⇢ must not duplicate ⇡ when the push target equals the upstream branch
p10k_fmt() {
    zsh -fc 'source "$1" >/dev/null 2>&1
        VCS_STATUS_LOCAL_BRANCH=feat/x VCS_STATUS_REMOTE_NAME=origin VCS_STATUS_REMOTE_BRANCH=$2 \
        VCS_STATUS_PUSH_REMOTE_NAME=$3 VCS_STATUS_COMMITS_AHEAD=4 VCS_STATUS_PUSH_COMMITS_AHEAD=4
        my_git_formatter; print -r -- "$my_git_format"' _ "$(cd "$(dirname "$0")/.." && pwd)/rc.d/.p10k-overrides.zsh" "$@"
}
if [[ "$(p10k_fmt feat/x origin)" != *⇢* && "$(p10k_fmt feat/x fork)" == *⇢4* ]]; then
    echo "✅ push-ahead count dedup: PASS"
else
    echo "❌ push-ahead count dedup: FAIL"
    record_failure
fi

echo ""
echo "🏛️  System Tools Completions"
echo "────────────────────────────"
# Git (uses built-in zsh completion setup)
if command -v git >/dev/null 2>&1; then
    if run_with_timeout 2 zsh -i -c 'compdef _git git; [[ ${+functions[_git]} -eq 1 ]]' 2>/dev/null; then
        echo "✅ git completion: PASS"
    else
        echo "❌ git completion: FAIL"
        record_failure
    fi
    if run_with_timeout 2 zsh -i -c 'typeset -f _git_ci | grep -q "_git_commit"' 2>/dev/null; then
        echo "✅ git ci completion: PASS"
    else
        echo "❌ git ci completion: FAIL"
        record_failure
    fi
else
    echo "⚠️  git: not installed"
fi

echo ""
echo "🔀 Git Alias Behaviour"
echo "──────────────────────"
# git ci: Refs: <TICKET> trailer derived from branch name (lib/git/aliases)
if command -v git >/dev/null 2>&1; then
    ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    ALIASES_FILE="${ROOT_DIR}/lib/git/aliases"
    tmp_repo=$(mktemp -d)

    git_test() {
        # include.path pulls in lib/git/aliases, which itself sets
        # commit.gpgsign=true (for real signing via 1Password) — -c values
        # are applied in the order given, so the override must come after
        # the include, or the alias file's gpgsign=true silently wins.
        git -C "$tmp_repo" -c user.name=test -c user.email=test@test \
            -c include.path="$ALIASES_FILE" -c commit.gpgsign=false "$@"
    }

    git_test init -q

    # ticket branch -> trailer added automatically
    git_test checkout -q -b feature/CLOUD-1234-x
    echo x >"$tmp_repo/a" && git_test add a
    git_test ci -q -m "test commit" >/dev/null
    if git_test log -1 --format=%B | grep -q '^Refs: CLOUD-1234$'; then
        echo "✅ git ci trailer (ticket branch): PASS"
    else
        echo "❌ git ci trailer (ticket branch): FAIL"
        record_failure
    fi

    # non-ticket branch -> no trailer added
    git_test checkout -q -b user/fix-2-typos
    echo y >>"$tmp_repo/a" && git_test add a
    git_test ci -q -m "test commit 2" >/dev/null
    if git_test log -1 --format=%B | grep -q '^Refs:'; then
        echo "❌ git ci trailer (non-ticket branch): FAIL"
        record_failure
    else
        echo "✅ git ci trailer (non-ticket branch): PASS"
    fi

    # REFS override forces a specific ticket
    echo z >>"$tmp_repo/a" && git_test add a
    REFS=CLOUD-999 git_test ci -q -m "test commit 3" >/dev/null
    if git_test log -1 --format=%B | grep -q '^Refs: CLOUD-999$'; then
        echo "✅ git ci REFS override: PASS"
    else
        echo "❌ git ci REFS override: FAIL"
        record_failure
    fi

    # amend backfills the trailer and stays idempotent (used by the amend alias)
    git_test checkout -q -b release/EPD-7-amend-test
    echo w >>"$tmp_repo/a" && git_test add a
    git_test commit -q -m "seed commit" >/dev/null
    git_test ci --amend --no-edit -q >/dev/null
    git_test ci --amend --no-edit -q >/dev/null
    refs_count=$(git_test log -1 --format=%B | grep -c '^Refs: EPD-7$')
    if [[ "$refs_count" -eq 1 ]]; then
        echo "✅ git ci --amend trailer idempotency: PASS"
    else
        echo "❌ git ci --amend trailer idempotency: FAIL (found $refs_count Refs lines)"
        record_failure
    fi

    rm -rf "$tmp_repo"
else
    echo "⚠️  git: not installed"
fi

echo ""
echo "🧪 Testing Generic Completion Framework"
echo "───────────────────────────────────────"
# Test that the generic completion utilities are available
if run_with_timeout 2 zsh -i -c 'declare -f _register_lazy_completion_zsh >/dev/null 2>&1' 2>/dev/null; then
    echo "✅ Generic completion framework: PASS"
else
    echo "❌ Generic completion framework: FAIL"
    record_failure
fi

# Test completion state tracking
if run_with_timeout 2 zsh -i -c 'declare -f _is_completion_loaded >/dev/null 2>&1' 2>/dev/null; then
    echo "✅ Completion utilities: PASS"
else
    echo "❌ Completion utilities: FAIL"
    record_failure
fi

echo "━━━━━━━━━━━━━━━━━━━━━━"
if [[ $failures -eq 0 ]]; then
    echo "✅ Tests complete"
else
    echo "❌ Tests complete with $failures failure(s)"
    exit 1
fi
