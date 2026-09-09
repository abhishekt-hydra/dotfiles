#!/usr/bin/env bash

# A bounded tmux status widget. Every client may execute this script, but a
# shared cache and mkdir lock ensure only one invocation samples counters per
# refresh interval. Supports macOS and Linux without optional packages.

readonly REFRESH_SECONDS=2
readonly CACHE_DIR="${TMPDIR:-/tmp}/tmux-network-speed-${UID:-$(id -u)}"
readonly CACHE_FILE="$CACHE_DIR/display"
readonly STATE_FILE="$CACHE_DIR/state"
readonly LOCK_DIR="$CACHE_DIR/lock"

umask 077
mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0
chmod 700 "$CACHE_DIR" 2>/dev/null || true

print_cached() {
  [[ -r "$CACHE_FILE" ]] && cat "$CACHE_FILE"
}

cache_is_fresh() {
  local now="$1" last_timestamp

  [[ -r "$STATE_FILE" && -s "$CACHE_FILE" ]] || return 1
  read -r last_timestamp _ < "$STATE_FILE" || return 1
  [[ "$last_timestamp" =~ ^[0-9]+$ ]] || return 1
  (( now >= last_timestamp && now - last_timestamp < REFRESH_SECONDS ))
}

release_lock() {
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Recover only a lock whose recorded owner is no longer alive. This keeps
    # a crashed status command from freezing the display indefinitely.
    local owner_pid
    if [[ -r "$LOCK_DIR/pid" ]]; then
      read -r owner_pid < "$LOCK_DIR/pid" || true
      if [[ "$owner_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
        rm -f "$LOCK_DIR/pid"
        rmdir "$LOCK_DIR" 2>/dev/null || true
        mkdir "$LOCK_DIR" 2>/dev/null || return 1
      else
        return 1
      fi
    else
      return 1
    fi
  fi

  printf '%s\n' "$$" > "$LOCK_DIR/pid" || {
    rmdir "$LOCK_DIR" 2>/dev/null || true
    return 1
  }
}

human_rate() {
  awk -v download="$1" -v upload="$2" '
    function format_rate(value, unit, scaled) {
      unit = 1
      scaled = value
      while (scaled >= 1024 && unit < 4) {
        scaled /= 1024
        unit++
      }
      return sprintf("%.2f %s", scaled, units[unit])
    }
    BEGIN {
      split("B/s kB/s MB/s GB/s", units, " ")
      printf "↓ %s • ↑ %s\n", format_rate(download), format_rate(upload)
    }
  '
}

default_interface() {
  if command -v ip >/dev/null 2>&1; then
    ip -4 route show default 2>/dev/null | awk 'NR == 1 { print $5; exit }'
  else
    route -n get default 2>/dev/null | awk '/interface: / { print $2; exit }'
  fi
}

interface_counters() {
  local interface="$1"
  if [[ -r "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
    paste -d ' ' \
      "/sys/class/net/$interface/statistics/rx_bytes" \
      "/sys/class/net/$interface/statistics/tx_bytes"
  else
    netstat -nbI "$interface" 2>/dev/null | awk '
      $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ { rx = $7; tx = $10 }
      END { if (rx != "" && tx != "") print rx, tx }
    '
  fi
}

main() {
  local now interface counters rx tx last_timestamp last_rx last_tx elapsed
  local download upload display state_tmp cache_tmp

  now=$(date +%s)
  if cache_is_fresh "$now"; then
    print_cached
    return
  fi

  if ! acquire_lock; then
    print_cached
    return
  fi
  trap release_lock EXIT HUP INT TERM

  # Another client may have refreshed while this invocation waited for the lock.
  now=$(date +%s)
  if cache_is_fresh "$now"; then
    print_cached
    return
  fi

  interface=$(tmux show-option -gqv '@dracula-network-bandwidth')
  if [[ -z "$interface" ]]; then
    interface=$(default_interface)
  fi

  if [[ -z "$interface" ]]; then
    print_cached
    return
  fi

  counters=$(interface_counters "$interface")
  read -r rx tx <<< "$counters"
  if [[ ! "$rx" =~ ^[0-9]+$ || ! "$tx" =~ ^[0-9]+$ ]]; then
    print_cached
    return
  fi

  display="[$interface] ↓ -- • ↑ --"
  if [[ -r "$STATE_FILE" ]]; then
    read -r last_timestamp last_rx last_tx < "$STATE_FILE" || true
    if [[ "$last_timestamp" =~ ^[0-9]+$ && "$last_rx" =~ ^[0-9]+$ && "$last_tx" =~ ^[0-9]+$ ]]; then
      elapsed=$((now - last_timestamp))
      if (( elapsed > 0 && rx >= last_rx && tx >= last_tx )); then
        download=$(((rx - last_rx) / elapsed))
        upload=$(((tx - last_tx) / elapsed))
        display="[$interface] $(human_rate "$download" "$upload")"
      fi
    fi
  fi

  state_tmp="$STATE_FILE.$$"
  cache_tmp="$CACHE_FILE.$$"
  printf '%s %s %s\n' "$now" "$rx" "$tx" > "$state_tmp" && mv -f "$state_tmp" "$STATE_FILE"
  printf '%s\n' "$display" > "$cache_tmp" && mv -f "$cache_tmp" "$CACHE_FILE"
  printf '%s\n' "$display"
}

main
