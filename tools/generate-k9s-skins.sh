#!/usr/bin/env zsh
# K9s/sofka Color Generator
# Generates k9s skins and sofka per-context color overrides from powerlevel10k color definitions
# Usage:
#   ./generate-k9s-skins.sh              # Generate skins only
#   ./generate-k9s-skins.sh --discover   # Generate skins + context configs
#   ./generate-k9s-skins.sh --force      # Overwrite existing skins

set -euo pipefail

# Script directory resolution
SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"

# Source color utilities
source "${ROOT_DIR}/lib/utils-k9s-colors"

# Detect OS and set appropriate k9s directories
detect_k9s_dirs() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses ~/Library/Application Support
        echo "${HOME}/Library/Application Support/k9s"
    else
        # Linux/Unix uses XDG directories
        echo "${XDG_CONFIG_HOME:-$HOME/.config}/k9s"
    fi
}

detect_k9s_clusters_dir() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses ~/Library/Application Support
        echo "${HOME}/Library/Application Support/k9s/clusters"
    else
        # Linux/Unix uses XDG data directory
        echo "${XDG_DATA_HOME:-$HOME/.local/share}/k9s/clusters"
    fi
}

detect_sofka_clusters_dir() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/sofka/clusters"
}

# Sanitize cluster name for k9s directory structure
# k9s replaces : and / with single - in directory names
_k9s_sanitize_cluster_name() {
    local cluster="$1"
    # Replace : and / with single -
    echo "${cluster}" | sed 's/[:\/]/-/g'
}

# sofka replaces every character outside [A-Za-z0-9._-] with -
_sofka_sanitize_name() {
    echo "$1" | sed 's/[^A-Za-z0-9._-]/-/g'
}

# Progress bar helper
_show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r🔍 Processing contexts: ["
    printf "%${filled}s" | tr ' ' '='
    if [[ $current -lt $total ]]; then
        printf ">"
        printf "%$((empty - 1))s" | tr ' ' ' '
    else
        printf "%${empty}s" | tr ' ' ' '
    fi
    printf "] %d/%d (%d%%)" "$current" "$total" "$percentage"

    if [[ $current -eq $total ]]; then
        printf "\n"
    fi
}

# Parse arguments
for arg in "$@"; do
    case $arg in
        --help|-h)
            cat <<EOF
Usage: $(basename $0)

Generate k9s skins/context configs and sofka color overrides from powerlevel10k colors.

What it does:
  • Generates k9s skin files (always replaces existing)
  • Discovers kubectl contexts and creates configs
  • Preserves existing k9s configs that already have skins
  • Writes sofka per-context color overrides and a [CLASS] badge (DEFAULT has no badge)
  • Regenerates sofka files it manages; skips hand-written ones
  • Maps contexts to classes using p10k color patterns
  • Each tool is optional: only installed ones are generated

Output:
  k9s skin files: ~/.config/k9s/skins/
  k9s context configs: ~/.local/share/k9s/clusters/{cluster}/{context}/
  sofka overrides: ~/.config/sofka/clusters/{cluster}/{context}/config.toml

Options:
  --help, -h    Show this help message

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Configuration - OS-aware paths
K9S_BASE_DIR=$(detect_k9s_dirs)
K9S_SKINS_DIR="${K9S_BASE_DIR}/skins"
K9S_CLUSTERS_DIR=$(detect_k9s_clusters_dir)

SOFKA_CLUSTERS_DIR=$(detect_sofka_clusters_dir)
SOFKA_MARKER="# managed-by: dotfiles tools/generate-k9s-skins.sh"

HAVE_K9S=false
HAVE_SOFKA=false
command -v k9s >/dev/null 2>&1 && HAVE_K9S=true
command -v sofka >/dev/null 2>&1 && HAVE_SOFKA=true

if [[ "$HAVE_K9S" == false && "$HAVE_SOFKA" == false ]]; then
    echo "⚠️  Neither k9s nor sofka found, nothing to generate"
    exit 0
fi

# Color classes to generate
typeset -a COLOR_CLASSES=(TEST DEV CI PRE PROD DEFAULT)

echo "🎨 K9s/sofka Color Generator"
echo

# Generate skin files
generate_skin() {
    local class="$1"
    local skin_file="${K9S_SKINS_DIR}/${class}.yaml"

    # Get colors for this class
    local fg_color=$(_k9s_get_class_color "$class")
    if [[ $? -ne 0 ]]; then
        echo "⚠️  Warning: Could not determine color for ${class}, using default"
        fg_color="#ffffff"
    fi

    # Use same color for focus (no brightening) to match border/logo
    local focus_color="$fg_color"

    # Generate minimal skin YAML
    cat > "$skin_file" <<EOF
# K9s skin for ${class} environment
# Auto-generated from powerlevel10k colors
# Border color: ${fg_color}

k9s:
  # General body styles
  body:
    fgColor: white
    bgColor: black
    logoColor: "${fg_color}"

  # Frame and border styles
  frame:
    # Border colors (main visual indicator)
    border:
      fgColor: "${fg_color}"
      focusColor: "${focus_color}"

    # Title bar colors
    title:
      fgColor: white
      bgColor: black
      highlightColor: "${fg_color}"
      counterColor: "${focus_color}"
      filterColor: gray

    # Menu colors
    menu:
      fgColor: "${fg_color}"
      keyColor: "${fg_color}"
      numKeyColor: "${focus_color}"

    # Breadcrumb colors
    crumbs:
      fgColor: black
      bgColor: "${fg_color}"
      activeColor: "${focus_color}"

  # Table/List view colors
  views:
    table:
      fgColor: white
      bgColor: black
      cursorFgColor: black
      cursorBgColor: "${fg_color}"
      markFgColor: "${focus_color}"
EOF

    chmod 644 "$skin_file"
}

if [[ "$HAVE_K9S" == true ]]; then
    mkdir -p "$K9S_SKINS_DIR"
    echo "📂 Generating ${#COLOR_CLASSES[@]} skins"
    for class in $COLOR_CLASSES; do
        generate_skin "$class"
    done
fi

# Write sofka's per-context override. Prints one of: created, updated, unchanged, skipped
# (skipped = an existing file without the managed marker).
generate_sofka_context() {
    local cluster="$1" ctx="$2" class="$3"
    local hex="${CLASS_HEX[$class]:-#ffffff}"
    local config_dir="${SOFKA_CLUSTERS_DIR}/$(_sofka_sanitize_name "$cluster")/$(_sofka_sanitize_name "$ctx")"
    local config_file="${config_dir}/config.toml"

    local content="${SOFKA_MARKER} (regenerated on each run, do not edit)
[skin.colors]
mauve = \"${hex}\"
lavender = \"${hex}\"
teal = \"${hex}\"
"
    if [[ "$class" != "DEFAULT" ]]; then
        content+="
[context_badge]
label = \"${class}\"
color = \"mauve\"
"
    fi

    local result="created"
    if [[ -f "$config_file" ]]; then
        if ! grep -qF "$SOFKA_MARKER" "$config_file"; then
            echo "skipped"
            return
        fi
        if [[ "$(<"$config_file")" == "${content%$'\n'}" ]]; then
            echo "unchanged"
            return
        fi
        result="updated"
    fi

    mkdir -p "$config_dir"
    print -r -- "$content" > "$config_file"
    chmod 644 "$config_file"
    echo "$result"
}

# Context discovery (always enabled)
# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    echo "⚠️  kubectl not found, skipping context discovery"
    exit 0
fi

# Get all contexts
local contexts=($(kubectl config get-contexts -o name 2>/dev/null))

if [[ ${#contexts[@]} -eq 0 ]]; then
    echo "⚠️  No kubectl contexts found"
    exit 0
fi

# Source p10k overrides for pattern matching
if [[ -f "${ROOT_DIR}/rc.d/.p10k-overrides.zsh" ]]; then
    source "${ROOT_DIR}/rc.d/.p10k-overrides.zsh"
else
    echo "⚠️  Could not source p10k-overrides.zsh, pattern matching unavailable"
    exit 1
fi

# Hex color per class, computed once
typeset -A CLASS_HEX
for class in $COLOR_CLASSES; do
    CLASS_HEX[$class]=$(_k9s_get_class_color "$class") || CLASS_HEX[$class]="#ffffff"
done

# Pattern match each context
local created=0
local updated=0
local skipped=0
local sofka_created=0
local sofka_updated=0
local sofka_unchanged=0
local sofka_skipped=0
local total=${#contexts[@]}
local current=0

for ctx in $contexts; do
    current=$((current + 1))
    _show_progress $current $total

    # Get cluster name for this context
    local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$ctx')].context.cluster}" 2>/dev/null)

    if [[ -z "$cluster" ]]; then
        printf "\n⚠️  Could not determine cluster for context: $ctx\n"
        continue
    fi

    # Pattern match to determine skin
    local skin="DEFAULT"
    for pat class in "${(@)MY_STANDARD_CLASSES}"; do
        if [[ $ctx == ${~pat} ]]; then
            skin="$class"
            break
        fi
    done

    if [[ "$HAVE_SOFKA" == true ]]; then
        case "$(generate_sofka_context "$cluster" "$ctx" "$skin")" in
            created) sofka_created=$((sofka_created + 1)) ;;
            updated) sofka_updated=$((sofka_updated + 1)) ;;
            unchanged) sofka_unchanged=$((sofka_unchanged + 1)) ;;
            skipped) sofka_skipped=$((sofka_skipped + 1)) ;;
        esac
    fi

    [[ "$HAVE_K9S" == true ]] || continue

    # Sanitize cluster and context names for k9s directory structure
    local sanitized_cluster=$(_k9s_sanitize_cluster_name "$cluster")
    local sanitized_ctx=$(_k9s_sanitize_cluster_name "$ctx")

    # Config file path
    local config_dir="${K9S_CLUSTERS_DIR}/${sanitized_cluster}/${sanitized_ctx}"
    local config_file="${config_dir}/config.yaml"

    # Create directory
    mkdir -p "$config_dir"

    # Check if config already exists
    if [[ -f "$config_file" ]]; then
        # Config exists, check if it has a skin field
        if grep -q "^[[:space:]]*skin:" "$config_file" 2>/dev/null; then
            skipped=$((skipped + 1))
            continue
        else
            # Config exists but no skin field, add it
            # Backup original
            cp "$config_file" "${config_file}.bak"

            # Add skin field after cluster line, preserving all other fields
            awk -v skin="$skin" '
            /^k9s:/ { print; next }
            /^[[:space:]]+cluster:/ {
                print
                print "  skin: " skin
                next
            }
            { print }
            ' "$config_file" > "${config_file}.tmp"

            mv "${config_file}.tmp" "$config_file"
            updated=$((updated + 1))
        fi
    else
        # Create new minimal config with just cluster and skin
        # k9s will add other fields (namespace, view, etc.) as needed
        cat > "$config_file" <<EOF
k9s:
  cluster: ${cluster}
  skin: ${skin}
EOF

        chmod 644 "$config_file"
        created=$((created + 1))
    fi
done

if [[ "$HAVE_K9S" == true ]]; then
    echo "✅ k9s   - Created: ${created}, Updated: ${updated}, Skipped: ${skipped}"
fi
if [[ "$HAVE_SOFKA" == true ]]; then
    echo "✅ sofka - Created: ${sofka_created}, Updated: ${sofka_updated}, Unchanged: ${sofka_unchanged}, Skipped (hand-written): ${sofka_skipped}"
fi

# Summary
echo
echo "📋 Summary"
if [[ "$HAVE_K9S" == true ]]; then
    echo "k9s skin files: ${K9S_SKINS_DIR}/"
    echo "k9s context configs: ${K9S_CLUSTERS_DIR}/"
fi
if [[ "$HAVE_SOFKA" == true ]]; then
    echo "sofka overrides: ${SOFKA_CLUSTERS_DIR}/"
fi
