alias reload!='exec zsh'
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lah --icons=auto --group-directories-first'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
fi
