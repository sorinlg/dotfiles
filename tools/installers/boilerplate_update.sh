#!/usr/bin/env bash

set -xe

BOILERPLATE_VERSION='v0.5.16'
ARCH='darwin_arm64'

# download binary from https://github.com/gruntwork-io/boilerplate/releases/download/v0.5.16/boilerplate_darwin_arm64
sudo wget -O /usr/local/bin/boilerplate https://github.com/gruntwork-io/boilerplate/releases/download/${BOILERPLATE_VERSION}/boilerplate_${ARCH}

# make it executable
sudo chmod +x /usr/local/bin/boilerplate
