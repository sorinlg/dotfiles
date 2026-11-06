#!/usr/bin/env sh

## Ensure ~/.docker/config.json uses docker-credential-env:
## - top-level credsStore = "env"
## - the registries below map to "env" under credHelpers
## without taking ownership of the rest of the file (other auths/credHelpers
## entries are machine/account-specific, not repo state - add-only, never
## removed here).
## Idempotent: a second run is a byte-for-byte no-op once already configured.
_docker_configure_credential_env() {
  local config_dir="${HOME}/.docker"
  local config_file="${config_dir}/config.json"

  if ! command -v jq >/dev/null 2>&1; then
    log_warning "jq not found - skipping docker credsStore configuration"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_dry "Would ensure credsStore=env and managed credHelpers entries in $config_file"
    return 0
  fi

  mkdir -p "$config_dir"
  [[ -f "$config_file" ]] || echo '{}' > "$config_file"

  # Registries that must resolve credentials through docker-credential-env
  # in addition to the default credsStore.
  local -a env_registries=(
    "ghcr.io"
    "329693315563.dkr.ecr.us-gov-east-1.amazonaws.com"
    "466553149513.dkr.ecr.us-gov-east-1.amazonaws.com"
    "672819064798.dkr.ecr.eu-west-1.amazonaws.com"
  )

  local registries_json
  registries_json="$(printf '%s\n' "${env_registries[@]}" | jq -R . | jq -s .)"

  local tmp_file
  tmp_file="$(mktemp "${config_dir}/config.json.XXXXXX")"
  if jq --argjson regs "$registries_json" \
        '.credsStore = "env"
         | .credHelpers = ((.credHelpers // {}) + (reduce $regs[] as $r ({}; .[$r] = "env")))' \
        "$config_file" > "$tmp_file" \
      && jq empty "$tmp_file" 2>/dev/null; then
    if diff -q <(jq -S . "$config_file") <(jq -S . "$tmp_file") >/dev/null 2>&1; then
      rm -f "$tmp_file"
    else
      mv "$tmp_file" "$config_file"
    fi
  else
    rm -f "$tmp_file"
    log_warning "Failed to update $config_file - left unchanged"
    return 1
  fi
}
export _docker_configure_credential_env >/dev/null
