#!/usr/bin/env bash
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

BG="#111111"
BLOCK="#3d4056"
ORANGE="#ffb86c"
CYAN="#8be9fd"
DARK="#111111"

iface="${STATUSBAR_IFACE:-en0}"

# zjstatus invokes this every second. Keep that render cheap, and refresh the
# expensive probes on their own cadence.
RENDER_INTERVAL=1
SYS_INTERVAL=3
NET_INTERVAL=2
DISK_INTERVAL=60
BATT_INTERVAL=15
LOCK_STALE_AFTER=5

now="$(/bin/date +%s)"
cache_dir="${TMPDIR:-/tmp}/zellij-statusbar-${USER:-user}"
state_cache="$cache_dir/metrics.cache"
render_cache="$cache_dir/rendered.cache"
lock_dir="$cache_dir/render.lock"
/bin/mkdir -p "$cache_dir"

# Defaults are also the lock-contention fallback when no cache exists yet.
sys_t=0
cpu="…"
ram_used="?"
ram_total="?"
net_t=0
net_ok=0
net_in=0
net_out=0
down_rate=0
up_rate=0
disk_t=0
disk="SSD ?Gi free"
batt_t=0
batt="AC"
state_dirty=0
lock_id="$$:$now"
have_lock=0

is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

file_mtime() {
  /usr/bin/stat -f %m "$1" 2>/dev/null || printf '0'
}

fresh_timestamp() {
  local ts="${1:-0}" interval="${2:-0}"
  is_int "$ts" && (( ts > 0 && now >= ts && now - ts < interval ))
}

print_render_cache() {
  [[ -s "$render_cache" ]] || return 1
  /bin/cat "$render_cache"
}

debug_log="${STATUSBAR_DEBUG_LOG:-$cache_dir/debug.log}"
debug_event() {
  [[ "${STATUSBAR_DEBUG:-0}" == "1" ]] || return 0
  printf '%s pid=%s %s\n' "$(/bin/date '+%s')" "$$" "$*" >> "$debug_log" 2>/dev/null || true
}

acquire_lock() {
  local lock_mtime

  if /bin/mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$lock_id" > "$lock_dir/owner" 2>/dev/null || true
    return 0
  fi

  lock_mtime="$(file_mtime "$lock_dir")"
  if is_int "$lock_mtime" && (( now >= lock_mtime && now - lock_mtime > LOCK_STALE_AFTER )); then
    /bin/rm -rf "$lock_dir" 2>/dev/null || true
    if /bin/mkdir "$lock_dir" 2>/dev/null; then
      printf '%s\n' "$lock_id" > "$lock_dir/owner" 2>/dev/null || true
      return 0
    fi
  fi

  return 1
}

release_lock() {
  local owner=""
  [[ -r "$lock_dir/owner" ]] && owner="$(<"$lock_dir/owner")"
  if [[ "$owner" == "$lock_id" ]]; then
    /bin/rm -f "$lock_dir/owner" 2>/dev/null || true
    /bin/rmdir "$lock_dir" 2>/dev/null || true
  fi
}

# Fast path: same-second renders should not even try to take the lock, and bash
# exits here before parsing the expensive probe functions below.
if [[ -s "$render_cache" ]]; then
  render_mtime="$(file_mtime "$render_cache")"
  if fresh_timestamp "$render_mtime" "$RENDER_INTERVAL"; then
    print_render_cache && exit 0
  fi
fi

# Non-blocking stampede control. If another invocation is refreshing, return the
# last complete render immediately. If none exists, fall through and build a
# minimal fallback from metric state after the helper functions are parsed.
if acquire_lock; then
  have_lock=1
  trap 'release_lock; /bin/rm -f "$state_cache.$$" "$render_cache.$$" 2>/dev/null || true' EXIT
else
  debug_event "lock busy; returning cached/fallback render"
  print_render_cache && exit 0
fi

rate_fmt() {
  local bytes="${1:-0}" whole frac
  is_int "$bytes" || bytes=0

  if (( bytes >= 1048576 )); then
    whole=$(( bytes / 1048576 ))
    frac=$(( (bytes % 1048576) * 100 / 1048576 ))
    printf '%d.%02d MB/s' "$whole" "$frac"
  elif (( bytes >= 1024 )); then
    whole=$(( bytes / 1024 ))
    frac=$(( (bytes % 1024) * 100 / 1024 ))
    printf '%d.%02d kB/s' "$whole" "$frac"
  else
    printf '%d B/s' "$bytes"
  fi
}

render_bar() {
  local clock down up
  clock="$(/bin/date '+%Y-%m-%d %H:%M:%S')"
  down="$(rate_fmt "$down_rate")"
  up="$(rate_fmt "$up_rate")"

  printf '#[bg=%s]' "$BG"
  printf '#[fg=%s,bg=%s,bold] %s%% ' "$ORANGE" "$BLOCK" "$cpu"
  printf '#[fg=%s,bg=%s,bold] RAM #[fg=%s,bg=%s,bold] %sGB/%s GB ' "$ORANGE" "$BG" "$ORANGE" "$BG" "$ram_used" "$ram_total"
  printf '#[fg=%s,bg=%s,bold] [%s] ↓  %s • ↑  %s ' "$DARK" "$CYAN" "$iface" "$down" "$up"
  printf '#[fg=%s,bg=%s,bold] %s ' "$ORANGE" "$BG" "$disk"
  printf '#[fg=%s,bg=%s,bold] %s ' "$ORANGE" "$BG" "$clock"
  printf '#[fg=%s,bg=%s,bold] ♥ %s ' "$ORANGE" "$BG" "$batt"
}

load_legacy_state() {
  local found=0

  if [[ -r "$cache_dir/cpu-ram.cache" ]]; then
    read -r sys_t cpu ram_used ram_total < "$cache_dir/cpu-ram.cache" || true
    found=1
  fi

  if [[ -r "$cache_dir/net-${iface}.cache" ]]; then
    read -r net_t net_in net_out down_rate up_rate < "$cache_dir/net-${iface}.cache" || true
    net_ok=1
    found=1
  fi

  if [[ -r "$cache_dir/disk.cache" ]]; then
    read -r disk_t disk < "$cache_dir/disk.cache" || true
    found=1
  fi

  if [[ -r "$cache_dir/battery.cache" ]]; then
    read -r batt_t batt < "$cache_dir/battery.cache" || true
    found=1
  fi

  (( found == 0 )) || state_dirty=1
}

validate_state() {
  is_int "$sys_t" || sys_t=0
  is_int "$cpu" || cpu="…"
  ram_used="${ram_used:-?}"
  ram_total="${ram_total:-?}"

  if ! is_int "$net_t" || ! is_int "$net_in" || ! is_int "$net_out"; then
    net_t=0
    net_in=0
    net_out=0
    net_ok=0
  fi
  is_int "$net_ok" || net_ok=0
  (( net_ok == 0 || net_ok == 1 )) || net_ok=0
  is_int "$down_rate" || down_rate=0
  is_int "$up_rate" || up_rate=0

  is_int "$disk_t" || disk_t=0
  disk="${disk:-SSD ?Gi free}"

  is_int "$batt_t" || batt_t=0
  batt="${batt:-AC}"
}

load_state() {
  local key value

  if [[ -r "$state_cache" ]]; then
    while IFS='=' read -r key value; do
      case "$key" in
        sys_t) sys_t="$value" ;;
        cpu) cpu="$value" ;;
        ram_used) ram_used="$value" ;;
        ram_total) ram_total="$value" ;;
        net_t) net_t="$value" ;;
        net_ok) net_ok="$value" ;;
        net_in) net_in="$value" ;;
        net_out) net_out="$value" ;;
        down_rate) down_rate="$value" ;;
        up_rate) up_rate="$value" ;;
        disk_t) disk_t="$value" ;;
        disk) disk="$value" ;;
        batt_t) batt_t="$value" ;;
        batt) batt="$value" ;;
      esac
    done < "$state_cache"
  else
    load_legacy_state
  fi

  validate_state
}

write_state() {
  local tmp="$state_cache.$$"
  {
    printf 'sys_t=%s\n' "$sys_t"
    printf 'cpu=%s\n' "$cpu"
    printf 'ram_used=%s\n' "$ram_used"
    printf 'ram_total=%s\n' "$ram_total"
    printf 'net_t=%s\n' "$net_t"
    printf 'net_ok=%s\n' "$net_ok"
    printf 'net_in=%s\n' "$net_in"
    printf 'net_out=%s\n' "$net_out"
    printf 'down_rate=%s\n' "$down_rate"
    printf 'up_rate=%s\n' "$up_rate"
    printf 'disk_t=%s\n' "$disk_t"
    printf 'disk=%s\n' "$disk"
    printf 'batt_t=%s\n' "$batt_t"
    printf 'batt=%s\n' "$batt"
  } > "$tmp" && /bin/mv "$tmp" "$state_cache"
}

write_render() {
  local bar="$1" tmp="$render_cache.$$"
  printf '%s' "$bar" > "$tmp" && /bin/mv "$tmp" "$render_cache"
}

probe_sys() {
  local cores total_bytes

  cores="$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || printf '1')"
  is_int "$cores" || cores=1
  (( cores > 0 )) || cores=1

  cpu="$(/bin/ps -A -o %cpu= 2>/dev/null | /usr/bin/awk -v n="$cores" '{ s += $1 } END { printf "%.0f", s / n }')"
  is_int "$cpu" || cpu=0

  total_bytes="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || printf '0')"
  is_int "$total_bytes" || total_bytes=0

  read -r ram_used ram_total <<EOF_RAM
$(/usr/bin/vm_stat 2>/dev/null | /usr/bin/awk -v total="$total_bytes" '
  /page size of/ {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^[0-9]+$/) { page = $i; break }
    }
  }
  /Anonymous pages/ {
    v = $3; gsub(/[^0-9]/, "", v); anon = v + 0
  }
  /Pages wired down/ {
    v = $4; gsub(/[^0-9]/, "", v); wired = v + 0
  }
  END {
    if (page <= 0) page = 4096
    printf "%.0f %.0f", (page * (anon + wired)) / 1024 / 1024 / 1024, total / 1024 / 1024 / 1024
  }
')
EOF_RAM
  is_int "$ram_used" || ram_used="?"
  is_int "$ram_total" || ram_total="?"

  sys_t="$now"
  state_dirty=1
}

probe_net() {
  local old_t="$net_t" old_ok="$net_ok" old_in="$net_in" old_out="$net_out"
  local found in_bytes out_bytes dt

  read -r found in_bytes out_bytes <<EOF_NET
$(/usr/sbin/netstat -I "$iface" -bn 2>/dev/null | /usr/bin/awk '$3 ~ /^<Link#/ { printf "1 %s %s", $7 + 0, $10 + 0; found = 1; exit } END { if (!found) printf "0 0 0" }')
EOF_NET
  is_int "$found" || found=0
  is_int "$in_bytes" || in_bytes=0
  is_int "$out_bytes" || out_bytes=0

  down_rate=0
  up_rate=0

  if (( found == 1 )); then
    if (( old_ok == 1 && old_t > 0 && now > old_t && in_bytes >= old_in && out_bytes >= old_out )); then
      dt=$(( now - old_t ))
      down_rate=$(( (in_bytes - old_in) / dt ))
      up_rate=$(( (out_bytes - old_out) / dt ))
    fi
    net_ok=1
    net_in="$in_bytes"
    net_out="$out_bytes"
  else
    net_ok=0
    # Keep old counters so a disappearing interface does not create a huge rate
    # spike when it comes back.
    net_in="$old_in"
    net_out="$old_out"
  fi

  net_t="$now"
  state_dirty=1
}

probe_disk() {
  local disk_path="/"
  [[ -d /System/Volumes/Data ]] && disk_path="/System/Volumes/Data"
  disk="$(/bin/df -g "$disk_path" 2>/dev/null | /usr/bin/awk 'NR == 2 { printf "SSD %sGi free", $4 }')"
  disk="${disk:-SSD ?Gi free}"
  disk_t="$now"
  state_dirty=1
}

probe_battery() {
  batt="$(/usr/bin/pmset -g batt 2>/dev/null | /usr/bin/awk 'match($0, /[0-9]+%/) { print substr($0, RSTART, RLENGTH); exit }')"
  batt="${batt:-AC}"
  batt_t="$now"
  state_dirty=1
}

load_state

if (( have_lock == 0 )); then
  render_bar
  exit 0
fi

fresh_timestamp "$sys_t" "$SYS_INTERVAL" || probe_sys
fresh_timestamp "$net_t" "$NET_INTERVAL" || probe_net
fresh_timestamp "$disk_t" "$DISK_INTERVAL" || probe_disk
fresh_timestamp "$batt_t" "$BATT_INTERVAL" || probe_battery

(( state_dirty == 0 )) || write_state

bar="$(render_bar)"
write_render "$bar"
printf '%s' "$bar"
