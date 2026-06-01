# Managed by dotfiles. Local/private settings can go in ~/.localrc.

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

# completion.zsh last.
autoload -Uz compinit
compinit
for file in ${(M)config_files:#*/completion.zsh}; do
  source "$file"
done

unset config_files file dir _zshrc_file _dotfiles_candidate
