#!/usr/bin/env zsh

# Zsh-native completion for awss command
_awss_completion() {
  local -a profiles
  local expl

  # Get AWS profiles from the function
  profiles=(${(f)"$(_get_aws_profiles)"})

  # Use _describe for nice completion display
  _describe -t profiles 'AWS profiles' profiles && return 0

  return 1
}

# Completion registration will be handled after awss alias is defined
# Users can manually register with: compdef _awss_completion awss
