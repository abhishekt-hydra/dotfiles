# Optional app/tool paths from existing machines.
typeset -U path PATH

for dir in \
  "$HOME/.bun/bin" \
  "$HOME/.fly/bin"
do
  [[ -d "$dir" ]] && path=("$dir" $path)
done

if [[ -d "$HOME/Library/pnpm" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
  path=("$PNPM_HOME" $path)
elif [[ -d "$HOME/.local/share/pnpm" ]]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  path=("$PNPM_HOME" $path)
fi

if [[ -d "$HOME/.bun" ]]; then
  export BUN_INSTALL="$HOME/.bun"
fi

if [[ -d "$HOME/.fly" ]]; then
  export FLYCTL_INSTALL="$HOME/.fly"
fi

export PATH
