# Shell plugins through antidote. The plugin list lives in plugins.txt.
#
# antidote is only loaded when plugins.txt is newer than the static file, so a
# normal shell just sources one pre-generated file of `source` lines.
# Update plugins: zsh-plugins-update

export ANTIDOTE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/antidote-bundles"
_antidote_dir="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
_plugins_txt="$DOTFILES/topics/common/zsh/plugins.txt"
_plugins_zsh="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/plugins.zsh"

zstyle ':antidote:bundle:*' zcompile 'yes'
zstyle ':antidote:static' zcompile 'yes'

# eza config: set before loading the OMZ eza plugin.
zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'show-group' yes
zstyle ':omz:plugins:eza' 'git-status' yes
zstyle ':omz:plugins:eza' 'header' yes
zstyle ':omz:plugins:eza' 'icons' yes

# conditional: tests used in plugins.txt.
_plugins_has_brew() { (( $+commands[brew] )) }
_plugins_has_eza() { (( $+commands[eza] )) }

_plugins_bundle() {
  if [[ ! -d "$_antidote_dir" ]]; then
    command -v git >/dev/null 2>&1 || return 1
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$_antidote_dir" || return 1
  fi
  fpath=("$_antidote_dir/functions" $fpath)
  autoload -Uz antidote
  mkdir -p "${_plugins_zsh:h}"
  antidote bundle <"$_plugins_txt" >|"$_plugins_zsh"
}

zsh-plugins-update() {
  _plugins_bundle && antidote update && antidote bundle <"$_plugins_txt" >|"$_plugins_zsh"
}

if [[ -r "$_plugins_txt" ]]; then
  [[ "$_plugins_zsh" -nt "$_plugins_txt" ]] || _plugins_bundle
  [[ -r "$_plugins_zsh" ]] && source "$_plugins_zsh"
fi
