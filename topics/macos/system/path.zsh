# macOS-specific PATH entries.
typeset -U path PATH

for dir in \
  /opt/homebrew/bin \
  /opt/homebrew/sbin \
  /usr/local/bin \
  /usr/local/sbin
do
  [[ -d "$dir" ]] && path=("$dir" $path)
done

export PATH
