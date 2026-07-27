# Managed by dotfiles. Local/private settings can go in ~/.localrc.

# Powerlevel10k instant prompt: repaints a cached prompt before the rest of this
# file runs. Must stay at the very top -- it has to win the race against any
# output below. `quiet` because the zinit bootstrap clone prints on first run of
# a fresh machine, which would otherwise trip the console-output warning.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Resolve repo path from the stowed ~/.zshrc symlink when possible.
if [[ -z "${DOTFILES:-}" ]]; then
  _zshrc_file="${${(%):-%N}:A}"
  _dotfiles_candidate="${_zshrc_file:h:h:h}"

  if [[ -d "$_dotfiles_candidate/topics" ]]; then
    export DOTFILES="$_dotfiles_candidate"
  elif [[ -d "$HOME/dotfiles/topics" ]]; then
    export DOTFILES="$HOME/dotfiles"
  elif [[ -d "$HOME/.dotfiles/topics" ]]; then
    export DOTFILES="$HOME/.dotfiles"
  else
    export DOTFILES="$HOME/dotfiles"
  fi
fi

case "$(uname -s)" in
  Darwin) export DOTFILES_OS="macos" ;;
  Linux) export DOTFILES_OS="linux" ;;
  *) export DOTFILES_OS="common" ;;
esac

# Load shell snippets from topic folders.
typeset -U config_files
config_files=()

for dir in \
  "$DOTFILES/topics/common" \
  "$DOTFILES/topics/$DOTFILES_OS" \
  "$DOTFILES/hosts/$(hostname -s)"
do
  [[ -d "$dir" ]] && config_files+=("$dir"/**/*.zsh(N))
done

# path.zsh first.
for file in ${(M)config_files:#*/path.zsh}; do
  source "$file"
done

# Everything except path/completion.
for file in ${${config_files:#*/path.zsh}:#*/completion.zsh}; do
  source "$file"
done

# Completion dirs from installers that append below must be on fpath before
# compinit runs, or their _* functions never make it into the dump.
fpath=(~/.grok/completions/zsh $fpath)

# completion.zsh last.
autoload -Uz compinit
compinit
for file in ${(M)config_files:#*/completion.zsh}; do
  source "$file"
done

unset config_files file dir _zshrc_file _dotfiles_candidate

# opencode
export PATH=/Users/abhishek/.opencode/bin:$PATH

# Zellij: show stable pane identity in pane frame title.
# Example: p3:Applications
if [[ -n "${ZELLIJ_PANE_ID:-}" ]]; then
  autoload -Uz add-zsh-hook
  _zellij_update_pane_title() {
    zellij action rename-pane "p${ZELLIJ_PANE_ID#terminal_}:${PWD##*/}" --pane-id "$ZELLIJ_PANE_ID" >/dev/null 2>&1
  }
  add-zsh-hook precmd _zellij_update_pane_title
fi
# Raise per-shell open-file limit. macOS currently reports kern.maxfilesperproc=92160;
# fall back if a parent process has a lower hard limit.
ulimit -n 92160 2>/dev/null || ulimit -n 65536 2>/dev/null || true
export PATH="/Users/abhishek/.evotai/bin:$PATH"

# bun completions
[ -s "/Users/abhishek/.bun/_bun" ] && source "/Users/abhishek/.bun/_bun"

# >>> grok installer >>>
# fpath entry and compinit hoisted above; the installer's trailing
# `compinit -C` reused a stale dump and never registered _grok.
export PATH="$HOME/.grok/bin:$PATH"
# <<< grok installer <<<

# Powerlevel10k appearance (hand-authored, not `p10k configure` output -- see the
# header in that file). Sourced last so it overrides anything the OMZ snippets set.
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
