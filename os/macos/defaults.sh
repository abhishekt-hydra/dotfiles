#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS defaults can only run on Darwin."
  exit 0
fi

# Sensible, low-risk macOS defaults. Add personal tweaks here.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.dock autohide -bool true

killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true

echo "macOS defaults applied."
