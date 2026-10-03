# Zinit + shell plugins inspired by the previous ~/.zshrc.

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]] && command -v git >/dev/null 2>&1; then
  mkdir -p "${ZINIT_HOME:h}"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  # Suppress zinit's `zpl`/`zplg`/`zi`/`zini` shorthands. `zi` in particular
  # would shadow zoxide's interactive picker, since zsh resolves aliases before
  # functions. Must be set before sourcing; zinit merges any pre-existing keys.
  typeset -gA ZINIT
  ZINIT[NO_ALIASES]=1

  source "$ZINIT_HOME/zinit.zsh"

  # eza config: set before loading OMZ eza plugin.
  zstyle ':omz:plugins:eza' 'dirs-first' yes
  zstyle ':omz:plugins:eza' 'git-status' yes
  zstyle ':omz:plugins:eza' 'header' yes
  zstyle ':omz:plugins:eza' 'icons' yes

  # Turbo mode: `wait lucid` loads these right after the first prompt draws,
  # not before it. Oh My Zsh libs we use, without loading all of OMZ.
  # direnv is hooked in tools.zsh, so OMZP::direnv is not loaded here.
  zinit wait lucid for \
    OMZL::git.zsh \
    OMZL::directories.zsh \
    OMZL::theme-and-appearance.zsh \
    OMZP::git
  (( $+commands[brew] )) && zinit wait lucid for OMZP::brew
  (( $+commands[eza] )) && zinit wait lucid for OMZP::eza

  # zsh-autosuggestions loads with the other widget plugins in completion.zsh.
fi
