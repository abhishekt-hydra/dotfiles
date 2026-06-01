# Linux-specific PATH entries.
typeset -U path PATH

for dir in \
  "$HOME/.cargo/bin" \
  "$HOME/.local/share/mise/shims"
do
  [[ -d "$dir" ]] && path=("$dir" $path)
done

export PATH
