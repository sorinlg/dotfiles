#!/usr/bin/env sh

# Check number of arguments
if [ "$#" -gt 1 ]; then
  echo "Usage: source_profile [profile]"
  return 1
fi

# unset AWS_ variables
awsc

# Set profile name (but don't export AWS_PROFILE to avoid SSO conflicts)
if [ "$#" -eq 1 ]; then
  selected_profile=$1
else
  # Use zsh parameter expansion to remove spaces instead of external sed command
  local selected_profile=$(_get_aws_profiles | fzf --tac)
  selected_profile="${selected_profile// /}"  # Remove all spaces using ${var// /} pattern
fi

echo "Loading credentials for profile: $selected_profile"

# Create temporary file with AWS_ variables
creds_file="$(mktemp "/tmp/aws_env.${selected_profile}.XXXXXX")"

# Write AWS_ variables to file (exclude AWS_PROFILE to prevent SSO conflicts)
# Docker credential helper will use explicit credentials instead of trying SSO
aws-vault exec $selected_profile -- env | grep AWS_ | grep -v AWS_PROFILE | grep -v BASH_FUNC | sed 's/^/export /' > "${creds_file}"

# Source the file
source "${creds_file}"
