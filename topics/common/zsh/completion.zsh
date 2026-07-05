# Loaded after compinit by stow/common/.zshrc.

if typeset -f zinit >/dev/null 2>&1; then
  zinit light Aloxaf/fzf-tab

  # Syntax highlighting should load after widgets/plugins.
  zinit light zsh-users/zsh-syntax-highlighting
fi

# fzf keybindings: Ctrl-R history, Ctrl-T files, Alt-C dirs.
_fzf_keybindings_candidates=(
  "${HOMEBREW_PREFIX:-}/opt/fzf/shell/key-bindings.zsh"
  "$(command -v brew >/dev/null 2>&1 && brew --prefix fzf 2>/dev/null)/shell/key-bindings.zsh"
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

# Up-arrow -> fzf dropdown of history entries that START WITH what's
# already typed (empty line -> full history). The picked command is put
# on the line for editing, not executed. Down-arrow keeps its default.
if command -v fzf >/dev/null 2>&1; then
  fzf-history-prefix-up() {
    emulate -L zsh
    local prefix=$LBUFFER selected
    if [[ -n $prefix ]]; then
      selected=$(fc -rln 1 \
        | awk -v p="$prefix" 'substr($0,1,length(p))==p && !seen[$0]++' \
        | fzf --height=40% --reverse --scheme=history \
              --prompt='history> ' --query="$prefix")
    else
      selected=$(fc -rln 1 | awk '!seen[$0]++' \
        | fzf --height=40% --reverse --scheme=history --prompt='history> ')
    fi
    if [[ -n $selected ]]; then
      BUFFER=$selected
      CURSOR=${#BUFFER}
    fi
    zle reset-prompt
  }
  zle -N fzf-history-prefix-up
  # Bind both normal (^[[A) and application-mode (^[OA) cursor keys for tmux.
  bindkey '^[[A' fzf-history-prefix-up
  bindkey '^[OA' fzf-history-prefix-up
fi
