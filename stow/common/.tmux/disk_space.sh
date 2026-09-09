#!/usr/bin/env bash

# Portable tmux/Dracula status widget. Both macOS and GNU df provide this
# output shape for the root filesystem.
df -h / | awk 'NR == 2 {printf "💾 %s/%s (%s)", $4, $2, $5}'
