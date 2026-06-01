export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"

# Keep secrets and machine-local exports out of git.
[[ -f "$HOME/.localrc" ]] && source "$HOME/.localrc"
