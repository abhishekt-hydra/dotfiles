# Optional interactive tools. Guard everything so fresh machines still open a shell.

if command -v zoxide >/dev/null 2>&1; then
  # `zi` picker: eza preview of the directory about to be jumped to. zoxide
  # feeds fzf "<score> <path>" lines, hence {2..} to recover the path.
  export _ZO_FZF_OPTS="--height=40% --reverse --border \
    --preview 'eza -1 --icons=auto --color=always --group-directories-first {2..}' \
    --preview-window=right:50%"

  # --cmd cd makes `cd` itself frecency-aware: `cd voterlist` works from
  # anywhere, while `cd ~/foo`, `cd ..` and `cd -` keep their normal meaning.
  # Only interactive shells are affected -- scripts never source this file.
  # Caveat: a mistyped directory name is no longer guaranteed to fail; if it
  # fuzzy-matches a known path, `cd` jumps there. With no match at all it
  # prints "zoxide: no match found" and leaves $PWD alone.
  eval "$(zoxide init zsh --cmd cd)"

  # --cmd renames both commands, so restore the z spellings by hand.
  alias z='cd'
  alias zi='cdi'
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
