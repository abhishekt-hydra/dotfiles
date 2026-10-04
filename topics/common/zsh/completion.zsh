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

_fzf_keybindings_loaded=
for _fzf_keybindings in "${_fzf_keybindings_candidates[@]}"; do
  if [[ -r "$_fzf_keybindings" ]]; then
    source "$_fzf_keybindings"
    _fzf_keybindings_loaded=1
    break
  fi
done

# fzf from mise ships only the binary, with no shell/ dir. fzf 0.48+ prints
# its own key bindings (plus ** completion; fzf-tab still owns Tab).
if [[ -z "$_fzf_keybindings_loaded" ]] && (( $+commands[fzf] )); then
  source <(fzf --zsh 2>/dev/null)
fi

unset _fzf_keybindings _fzf_keybindings_candidates _fzf_keybindings_loaded

# Completion behavior:
# - show/select the completion menu on the first Tab
# - match case-insensitively, so `cd desk<Tab>` finds `Desktop`
zmodload zsh/complist
setopt AUTO_LIST AUTO_MENU COMPLETE_IN_WORD

zstyle ':completion:*' menu select=1
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':fzf-tab:*' case-sensitive no
