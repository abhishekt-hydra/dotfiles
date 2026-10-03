# Loaded after compinit by dotfiles/common/.zshrc.
# fzf-tab, autosuggestions and syntax highlighting load from plugins.txt.

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
