#!/usr/bin/env bash

set -e

# Simple script to set up SSH commit signing

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <ssh-public-key>"
    echo ""
    echo "Examples:"
    echo "  $0 \"ssh-ed25519 <your public key>\""
    echo "  $0 \"\$(op read 'op://Personal/SSH Key/public key')\""
    echo "  $0 \"\$(cat ~/.ssh/id_ed25519.pub)\""
    exit 1
fi

SSH_PUBLIC_KEY="$1"

# Validate it looks like an SSH key
if [[ ! "$SSH_PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
    echo "Error: Invalid SSH public key format"
    echo "Key should start with ssh-rsa, ssh-ed25519, or ssh-ecdsa"
    exit 1
fi

# Get git email from config
GIT_EMAIL=$(git config user.email 2>/dev/null || echo "")

if [[ -z "$GIT_EMAIL" ]]; then
    read -p "Enter your git email: " GIT_EMAIL
fi

# Create allowed_signers file
echo "Creating ~/.ssh/allowed_signers..."
mkdir -p ~/.ssh
echo "$GIT_EMAIL $SSH_PUBLIC_KEY" > ~/.ssh/allowed_signers

echo "✅ Created allowed_signers file for $GIT_EMAIL"
echo ""
echo "Test with: git log --show-signature"
