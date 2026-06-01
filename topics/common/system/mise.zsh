# Activate mise-managed tools when mise is installed.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
