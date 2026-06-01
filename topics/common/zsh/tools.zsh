# Optional interactive tools. Guard everything so fresh machines still open a shell.

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# VS Code shell integration.
if [[ "${TERM_PROGRAM:-}" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  _code_shell_integration="$(code --locate-shell-integration-path zsh 2>/dev/null || true)"
  [[ -n "$_code_shell_integration" && -r "$_code_shell_integration" ]] && source "$_code_shell_integration"
  unset _code_shell_integration
fi
