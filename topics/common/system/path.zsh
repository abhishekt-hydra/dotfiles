# Shared PATH entries. Loaded before other topic files.
typeset -U path PATH

for dir in \
  "$DOTFILES/bin" \
  "$HOME/.local/bin" \
  "$HOME/bin"
do
  [[ -d "$dir" ]] && path=("$dir" $path)
done

export PATH
