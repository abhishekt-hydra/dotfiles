# Prompt: plain zsh, no plugins, nothing left running in the background.
#
# Replaces powerlevel10k, whose gitstatusd daemon + three detached worker
# shells cost ~5 MB per open shell -- with a couple hundred tmux/herdr panes
# that was well over a gigabyte. Same layout and cool 256-color palette:
#
#   ~/path/to/repo main ⇡1 !2 ?3                 ✘1 4s ✦ venv user@host 14:02
#   ❯
#
# Git costs one `git status` per prompt. Past ~8k indexed files the dirty
# check is skipped (branch + ahead/behind only, in grey), mirroring the old
# POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY guard, so huge trees never stall.

zmodload -F zsh/stat b:zstat
zmodload zsh/datetime
autoload -Uz add-zsh-hook

typeset -g VIRTUAL_ENV_DISABLE_PROMPT=1
typeset -gi _prompt_git_max_index_bytes=$(( 1024 * 1024 ))
typeset -gi _prompt_exec_threshold=3
typeset -g _prompt_cmd_start= _prompt_drawn=
typeset -g _prompt_lc _prompt_lp _prompt_rc _prompt_rp

# _prompt_add l|r STYLE TEXT -- append a segment to the left or right side,
# tracking the plain text alongside so the line can be padded to full width.
_prompt_add() {
  local seg="$2${3//\%/%%}%b%f"
  if [[ $1 == l ]]; then
    _prompt_lc+="$seg "; _prompt_lp+="$3 "
  else
    _prompt_rc+=" $seg"; _prompt_rp+=" $3"
  fi
}

_prompt_dir() {
  local d=${(%):-%~} style='%F{75}'
  [[ -w $PWD ]] || style='%F{205}'
  if [[ $d == */* && $d != / ]]; then
    _prompt_lc+="$style${${d%/*}//\%/%%}/%B%F{117}${${d##*/}//\%/%%}%b%f "
  else
    _prompt_lc+="%B%F{117}${d//\%/%%}%b%f "
  fi
  _prompt_lp+="$d "
}

_prompt_git() {
  local gitdir line head oid ab
  gitdir=$(git rev-parse --git-dir 2>/dev/null) || return
  local -a size
  local -i ahead=0 behind=0 staged=0 unstaged=0 untracked=0 conflicted=0 big=0
  zstat -A size +size -- "$gitdir/index" 2>/dev/null \
    && (( size[1] > _prompt_git_max_index_bytes )) && big=1

  if (( big )); then
    head=$(git symbolic-ref --short -q HEAD) \
      || head="@$(git rev-parse --short HEAD 2>/dev/null)"
    if ab=$(git rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null); then
      ahead=${ab%%[[:space:]]*} behind=${ab##*[[:space:]]}
    fi
  else
    for line in "${(@f)$(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)}"; do
      case $line in
        '# branch.head '*) head=${line#\# branch.head } ;;
        '# branch.oid '*)  oid=${line#\# branch.oid } ;;
        '# branch.ab '*)   ab=${line#\# branch.ab }; ahead=${${ab%% *}#+}; behind=${${ab##* }#-} ;;
        [12]' '*)          [[ ${line[3]} != . ]] && (( staged++ ))
                           [[ ${line[4]} != . ]] && (( unstaged++ )) ;;
        'u '*)             (( conflicted++ )) ;;
        '? '*)             (( untracked++ )) ;;
      esac
    done
    [[ $head == '(detached)' ]] && head="@${oid[1,8]}"
  fi
  [[ -n $head ]] || return

  local style='%F{79}'
  if (( big )); then style='%F{244}'
  elif (( conflicted )); then style='%F{205}'
  elif (( staged || unstaged )); then style='%F{111}'
  elif (( untracked )); then style='%F{140}'
  fi
  _prompt_add l $style $head
  (( behind ))     && _prompt_add l '%F{79}'  "⇣$behind"
  (( ahead ))      && _prompt_add l '%F{79}'  "⇡$ahead"
  (( conflicted )) && _prompt_add l '%F{205}' "~$conflicted"
  (( staged ))     && _prompt_add l '%F{111}' "+$staged"
  (( unstaged ))   && _prompt_add l '%F{111}' "!$unstaged"
  (( untracked ))  && _prompt_add l '%F{140}' "?$untracked"
}

_prompt_duration() {
  local -i s=$1
  if (( s >= 86400 )); then print -r -- "$((s/86400))d $((s%86400/3600))h $((s%3600/60))m $((s%60))s"
  elif (( s >= 3600 )); then print -r -- "$((s/3600))h $((s%3600/60))m $((s%60))s"
  elif (( s >= 60 )); then print -r -- "$((s/60))m $((s%60))s"
  else print -r -- "${s}s"
  fi
}

_prompt_preexec() {
  _prompt_cmd_start=$EPOCHREALTIME
  # Build after every other precmd hook (direnv, mise, ...) so the prompt
  # reflects the environment they just loaded.
  [[ ${precmd_functions[-1]} == _prompt_precmd ]] \
    || precmd_functions=(${precmd_functions:#_prompt_precmd} _prompt_precmd)
}

_prompt_precmd() {
  local -i exit_status=$?
  _prompt_lc= _prompt_lp= _prompt_rc= _prompt_rp=

  _prompt_dir
  _prompt_git

  (( exit_status )) && _prompt_add r '%F{205}' "✘$exit_status"
  if [[ -n $_prompt_cmd_start ]]; then
    local -i elapsed=$(( EPOCHREALTIME - _prompt_cmd_start ))
    (( elapsed >= _prompt_exec_threshold )) && _prompt_add r '%F{103}' "$(_prompt_duration $elapsed)"
    _prompt_cmd_start=
  fi
  (( ${#jobstates} )) && _prompt_add r '%F{110}' '✦'
  [[ -n $DIRENV_DIR ]] && _prompt_add r '%F{103}' 'direnv'
  [[ -n $VIRTUAL_ENV ]] && _prompt_add r '%F{110}' "${VIRTUAL_ENV:t}"
  if (( EUID == 0 )); then
    _prompt_add r '%F{205}' "${(%):-%n@%m}"
  elif [[ -n $SSH_CONNECTION ]]; then
    _prompt_add r '%F{103}' "${(%):-%n@%m}"
  fi
  local now; strftime -s now %H:%M $EPOCHSECONDS
  _prompt_add r '%F{244}' $now

  local top=$_prompt_lc
  local -i pad=$(( COLUMNS - ${(m)#_prompt_lp} - ${(m)#_prompt_rp} - 1 ))
  (( pad > 0 )) && top+="${(l:pad:: :)}${_prompt_rc}"

  # Blank line between commands, but not above the very first prompt.
  [[ -n $_prompt_drawn ]] && top=$'\n'$top
  _prompt_drawn=1

  PROMPT="$top"$'\n''%(?.%F{80}.%F{205})❯%f '
  RPROMPT=
}

add-zsh-hook preexec _prompt_preexec
add-zsh-hook precmd _prompt_precmd
