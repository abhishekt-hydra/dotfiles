# Keep macOS awake with the lid closed when `caffeinate -d` is used.
#
# Prompts once with `sudo -v` before changing pmset, then refreshes that
# authorization while the hold runs so cleanup can restore the prior state.
# The optional CaffeinateLid menu-bar app and `hotspot` helpers are discovered
# at runtime; neither is required for ordinary caffeinate use.

typeset -g CAFFEINATE_LID_DIR="${TMPDIR:-/tmp}/caffeinate-lid.$UID"
typeset -g CAFFEINATE_LID_APP="$HOME/Library/Application Support/CaffeinateLid/CaffeinateLid.app"

_caffeinate_lid_indicator() {
  [[ -d "$CAFFEINATE_LID_APP" ]] || return 0
  open -g -a "$CAFFEINATE_LID_APP" --args "$CAFFEINATE_LID_DIR" 2>/dev/null
}

_caffeinate_lid_lock() {
  local i
  for i in {1..50}; do
    mkdir "$CAFFEINATE_LID_DIR/lock" 2>/dev/null && return 0
    sleep 0.1
  done
  return 1
}

_caffeinate_lid_unlock() {
  rmdir "$CAFFEINATE_LID_DIR/lock" 2>/dev/null
}

# Holder names contain the owning shell PID. Remove ones whose shell died.
_caffeinate_lid_reap() {
  local f pid
  for f in "$CAFFEINATE_LID_DIR"/holder.*(N); do
    pid="${${${f:t}#holder.}%%.*}"
    kill -0 "$pid" 2>/dev/null || rm -f "$f"
  done
}

# The caller holds the lock. Restore the saved setting only after the final
# holder has gone away, then return Wi-Fi from the hotspot if that helper is
# installed.
_caffeinate_lid_restore_if_idle() {
  _caffeinate_lid_reap
  local -a holders=("$CAFFEINATE_LID_DIR"/holder.*(N))
  (( ${#holders} )) && return 0

  local prior
  if [[ -r "$CAFFEINATE_LID_DIR/prior" ]]; then
    prior="$(<"$CAFFEINATE_LID_DIR/prior")"
    if [[ "$prior" == <-> && "$prior" -le 1 ]]; then
      sudo -n /usr/bin/pmset -a disablesleep "$prior"
    else
      print -u2 'caffeinate: saved lid-sleep state is invalid; not changing it'
    fi
  fi

  rm -f "$CAFFEINATE_LID_DIR/prior"
  (( $+functions[hotspot_leave] )) && hotspot_leave
}

_caffeinate_lid_acquire() {
  local token="$1" prior pmset_state
  [[ -L "$CAFFEINATE_LID_DIR" ]] && return 1
  mkdir -p -m 700 "$CAFFEINATE_LID_DIR" || return 1
  chmod 700 "$CAFFEINATE_LID_DIR" 2>/dev/null || return 1
  _caffeinate_lid_lock || return 1
  _caffeinate_lid_reap

  local -a holders=("$CAFFEINATE_LID_DIR"/holder.*(N))
  if (( ${#holders} == 0 )); then
    if ! pmset_state="$(/usr/bin/pmset -g)"; then
      print -u2 'caffeinate: could not read the current lid-sleep setting'
      _caffeinate_lid_unlock
      return 1
    fi
    prior="$(print -r -- "$pmset_state" | /usr/bin/awk '$1 == "SleepDisabled" && $2 ~ /^[01]$/ { print $2; exit }')"
    # pmset omits SleepDisabled when it is off, which is equivalent to 0.
    prior="${prior:-0}"
    if [[ "$prior" != <-> || "$prior" -gt 1 ]]; then
      print -u2 'caffeinate: could not read the current lid-sleep setting'
      _caffeinate_lid_unlock
      return 1
    fi
    print -r -- "$prior" >| "$CAFFEINATE_LID_DIR/prior"

    if ! sudo -n /usr/bin/pmset -a disablesleep 1; then
      rm -f "$CAFFEINATE_LID_DIR/prior"
      _caffeinate_lid_unlock
      return 1
    fi
  fi

  : > "$CAFFEINATE_LID_DIR/holder.$token"
  _caffeinate_lid_indicator
  _caffeinate_lid_unlock
}

_caffeinate_lid_release() {
  local token="$1"
  [[ -e "$CAFFEINATE_LID_DIR/holder.$token" ]] || return 0
  _caffeinate_lid_lock || return 1
  rm -f "$CAFFEINATE_LID_DIR/holder.$token"
  _caffeinate_lid_restore_if_idle
  _caffeinate_lid_unlock
  rmdir "$CAFFEINATE_LID_DIR" 2>/dev/null
}

# Shell exit, Ctrl-C, SIGHUP, and SIGTERM all run the zshexit hooks. Release
# only holders owned by this shell; other concurrent caffeinates keep theirs.
_caffeinate_lid_atexit() {
  [[ -d "$CAFFEINATE_LID_DIR" ]] || return 0
  local f
  for f in "$CAFFEINATE_LID_DIR"/holder.$$.*(N); do
    _caffeinate_lid_release "${${f:t}#holder.}"
  done
}

# SIGKILL cannot run cleanup hooks. The next interactive prompt reaps any
# dead owners and restores sleep when none remain.
_caffeinate_lid_sweep() {
  [[ -d "$CAFFEINATE_LID_DIR" ]] || return 0
  local -a holders=("$CAFFEINATE_LID_DIR"/holder.*(N))
  (( ${#holders} )) || return 0

  local f
  for f in $holders; do
    kill -0 "${${${f:t}#holder.}%%.*}" 2>/dev/null && return 0
  done

  _caffeinate_lid_lock || return 0
  _caffeinate_lid_restore_if_idle
  _caffeinate_lid_unlock
  rmdir "$CAFFEINATE_LID_DIR" 2>/dev/null
}

_caffeinate_lid_join_hotspot() {
  (( $+functions[hotspot] )) || return 0
  hotspot
}

# macOS sudo credentials normally expire after a few minutes. Refresh the
# already-authorized timestamp without ever prompting in this background loop;
# the foreground `sudo -v` below is the sole password prompt.
_caffeinate_lid_keep_sudo_alive() {
  while sleep 60; do
    sudo -n -v || return 0
  done
}

# Turn the displays off once when the lid closes. This does not sleep the
# system, so the caffeinated workload continues running.
_caffeinate_lid_watch_display() {
  local state previous=No
  while sleep 1; do
    state="$(/usr/sbin/ioreg -r -k AppleClamshellState -d 4 |
      /usr/bin/awk '/AppleClamshellState/ { print $NF; exit }')"
    if [[ "$state" == Yes && "$previous" != Yes ]]; then
      /usr/bin/pmset displaysleepnow
    fi
    previous="$state"
  done
}

caffeinate() {
  local arg cleaned lid=0 options=1 token sudo_keepalive_pid display_watcher_pid
  local -a native_args
  for arg in "$@"; do
    if (( options )) && [[ "$arg" == -- ]]; then
      options=0
      native_args+=("$arg")
      continue
    fi
    if (( options )) && [[ "$arg" == -* && "$arg" != --* && "${arg#-}" == *d* ]]; then
      lid=1
      cleaned="${arg#-}"
      cleaned="${cleaned//d/}"
      [[ -n "$cleaned" ]] && native_args+=("-$cleaned")
    else
      native_args+=("$arg")
    fi
  done

  (( lid )) || { command /usr/bin/caffeinate "$@"; return }

  if ! sudo -v; then
    print -u2 'caffeinate: sudo authentication failed; continuing without lid sleep prevention'
    command /usr/bin/caffeinate "${native_args[@]}"
    return
  fi

  token="$$.$RANDOM$RANDOM"
  if ! _caffeinate_lid_acquire "$token"; then
    print -u2 'caffeinate: could not disable lid sleep; continuing without it'
    command /usr/bin/caffeinate "${native_args[@]}"
    return
  fi

  _caffeinate_lid_keep_sudo_alive &
  sudo_keepalive_pid=$!
  _caffeinate_lid_watch_display &
  display_watcher_pid=$!
  print -u2 'caffeinate: lid sleep disabled; display will turn off when lid closes — restores when this exits'
  # Pin sleep first, then travel. A hotspot failure never blocks caffeinate.
  _caffeinate_lid_join_hotspot || print -u2 'caffeinate: hotspot join failed; continuing on current network'
  {
    command /usr/bin/caffeinate "${native_args[@]}"
  } always {
    kill "$display_watcher_pid" 2>/dev/null || true
    wait "$display_watcher_pid" 2>/dev/null || true
    kill "$sudo_keepalive_pid" 2>/dev/null || true
    wait "$sudo_keepalive_pid" 2>/dev/null || true
    _caffeinate_lid_release "$token"
  }
}

autoload -Uz add-zsh-hook
add-zsh-hook zshexit _caffeinate_lid_atexit
add-zsh-hook precmd _caffeinate_lid_sweep
