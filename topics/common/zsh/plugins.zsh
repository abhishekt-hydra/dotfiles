# Zinit + shell plugins inspired by the previous ~/.zshrc.

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]] && command -v git >/dev/null 2>&1; then
  mkdir -p "${ZINIT_HOME:h}"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  source "$ZINIT_HOME/zinit.zsh"

  # Oh My Zsh libs we use, without loading all of OMZ.
  zinit snippet OMZL::git.zsh
  zinit snippet OMZL::directories.zsh
  zinit snippet OMZL::theme-and-appearance.zsh
  zinit snippet OMZL::async_prompt.zsh

  # eza config: set before loading OMZ eza plugin.
  zstyle ':omz:plugins:eza' 'dirs-first' yes
  zstyle ':omz:plugins:eza' 'git-status' yes
  zstyle ':omz:plugins:eza' 'header' yes
  zstyle ':omz:plugins:eza' 'icons' yes

  zinit snippet OMZP::git
  command -v brew >/dev/null 2>&1 && zinit snippet OMZP::brew
  command -v direnv >/dev/null 2>&1 && zinit snippet OMZP::direnv
  command -v eza >/dev/null 2>&1 && zinit snippet OMZP::eza

  zinit light zsh-users/zsh-autosuggestions
fi
