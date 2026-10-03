# Loaded after compinit by dotfiles/common/.zshrc.

if typeset -f zinit >/dev/null 2>&1; then
  # Turbo mode, in this order: fzf-tab before the plugins that wrap widgets,
  # syntax highlighting last. zicdreplay replays the compdef calls zinit
  # captured from the turbo-loaded snippets.
  zinit wait lucid for \
    Aloxaf/fzf-tab \
    atload"_zsh_autosuggest_start" \
      zsh-users/zsh-autosuggestions \
    atinit"zicdreplay -q" \
      zdharma-continuum/fast-syntax-highlighting
fi

# fzf keybindings: Ctrl-R history, Ctrl-T files, Alt-C dirs.
_fzf_keybindings_candidates=(
  "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh"
  "/usr/local/opt/fzf/shell/key-bindings.zsh"
  "/usr/share/doc/fzf/examples/key-bindings.zsh"
  "/usr/share/fzf/key-bindings.zsh"
  "$HOME/.fzf/shell/key-bindings.zsh"
)

for _fzf_keybindings in "${_fzf_keybindings_candidates[@]}"; do
  if [[ -r "$_fzf_keybindings" ]]; then
    source "$_fzf_keybindings"
    break
  fi
done

unset _fzf_keybindings _fzf_keybindings_candidates

# Completion behavior:
# - show/select the completion menu on the first Tab
# - match case-insensitively, so `cd desk<Tab>` finds `Desktop`
zmodload zsh/complist
setopt AUTO_LIST AUTO_MENU COMPLETE_IN_WORD

zstyle ':completion:*' menu select=1
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':fzf-tab:*' case-sensitive no
