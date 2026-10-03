# Managed by dotfiles. Local/private settings can go in ~/.localrc.

# Resolve the checkout from the machine-local pointer installed by script/link.
if [[ -z "${DOTFILES:-}" ]]; then
  _zshrc_file="${${(%):-%N}:A}"
  _dotfiles_candidate="${_zshrc_file:h:h:h}"

  _dotfiles_root_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/root"
  if [[ -r "$_dotfiles_root_file" ]]; then
    _dotfiles_root="$(<"$_dotfiles_root_file")"
  fi

  if [[ -n "${_dotfiles_root:-}" && -d "$_dotfiles_root/topics" ]]; then
    export DOTFILES="$_dotfiles_root"
  elif [[ -d "$_dotfiles_candidate/topics" ]]; then
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

# compinit once, before any topic file: mise's hook calls compdef and runs a
# full uncached compinit of its own when compdef does not exist yet.
# Completion dirs from installers must be on fpath first, or their _*
# functions never make it into the dump.
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
_zcompdump_stale=("$_zcompdump"(N.mh+24))
# Full check (new _* files, insecure dirs) at most once a day; else trust the dump.
if [[ ! -s "$_zcompdump" || -n "$_zcompdump_stale" ]]; then
  compinit -d "$_zcompdump"
  touch "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
[[ "$_zcompdump.zwc" -nt "$_zcompdump" ]] || zcompile "$_zcompdump"

# Everything except path/completion.
for file in ${${config_files:#*/path.zsh}:#*/completion.zsh}; do
  source "$file"
done

# completion.zsh last.
for file in ${(M)config_files:#*/completion.zsh}; do
  source "$file"
done

unset config_files file dir _zshrc_file _dotfiles_candidate _dotfiles_root_file _dotfiles_root _zcompdump _zcompdump_stale

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


[ -f ~/.fly_profiles.sh ] && . ~/.fly_profiles.sh

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
# fpath + compinit for grok happen once, above.
# <<< grok installer <<<

# Added by cua-driver-rs installer — see https://github.com/trycua/cua
export PATH="/Users/abhishek/.local/bin:$PATH"

# Turso
export PATH="$PATH:/Users/abhishek/.turso"

# AgentField CLI
export PATH="/Users/abhishek/.agentfield/bin:$PATH"
