#!/usr/bin/env bash
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

BG="#111111"
BLOCK="#3d4056"
ORANGE="#ffb86c"
CYAN="#8be9fd"
DARK="#111111"

iface="en0"

# Cache intervals in seconds. Keep expensive probes out of the 1s render path.
RENDER_INTERVAL=1
SYS_INTERVAL=3
NET_INTERVAL=1
DISK_INTERVAL=60
BATT_INTERVAL=15

now="$(/bin/date +%s)"
cache_dir="${TMPDIR:-/tmp}/zellij-statusbar-${USER:-user}"
render_cache="$cache_dir/rendered.cache"
lock_dir="$cache_dir/render.lock"
mkdir -p "$cache_dir"

file_mtime() {
  /usr/bin/stat -f %m "$1" 2>/dev/null || printf '0'
}

# Full rendered-line cache: if several zjstatus instances invoke us in the same
# second, only the first one does syscalls; the rest just print this file.
if [[ -r "$render_cache" ]]; then
  render_mtime="$(file_mtime "$render_cache")"
  if [[ "$render_mtime" =~ ^[0-9]+$ ]] && (( now - render_mtime < RENDER_INTERVAL )); then
    /bin/cat "$render_cache"
    exit 0
  fi
fi

# Cross-process lock. If another invocation is refreshing, print the previous
# rendered line instead of stampeding ps/vm_stat/netstat/df/pmset. If this is
# the first run and no cache exists yet, wait briefly for the lock holder.
have_lock=0
if /bin/mkdir "$lock_dir" 2>/dev/null; then
  have_lock=1
else
  lock_mtime="$(file_mtime "$lock_dir")"
  if [[ "$lock_mtime" =~ ^[0-9]+$ ]] && (( now - lock_mtime > 5 )); then
    /bin/rmdir "$lock_dir" 2>/dev/null || true
    if /bin/mkdir "$lock_dir" 2>/dev/null; then
      have_lock=1
    fi
  fi
fi

if (( have_lock == 1 )); then
  trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
else
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -r "$render_cache" ]] && { /bin/cat "$render_cache"; exit 0; }
    /bin/sleep 0.05
  done
  exit 0
fi

rate_fmt() {
  awk -v b="${1:-0}" 'BEGIN {
    if (b >= 1048576) printf "%.2f MB/s", b / 1048576;
    else if (b >= 1024) printf "%.2f kB/s", b / 1024;
    else printf "%d B/s", b;
  }'
}

# CPU + RAM cache.
sys_cache="$cache_dir/cpu-ram.cache"
cpu="0"
ram_used="?"
ram_total="?"
if [[ -r "$sys_cache" ]]; then
  read -r sys_t cpu ram_used ram_total < "$sys_cache" || true
else
  sys_t=0
fi
if ! [[ "${sys_t:-0}" =~ ^[0-9]+$ ]] || (( now - sys_t >= SYS_INTERVAL )); then
  cores="$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || printf '1')"
  cpu="$(/bin/ps -A -o %cpu= 2>/dev/null | awk -v n="$cores" '{ s += $1 } END { if (n < 1) n = 1; printf "%.0f", s / n }')"
  cpu="${cpu:-0}"

  # App-ish resident memory: anonymous + wired. This excludes inactive/file cache.
  total_bytes="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || printf '0')"
  vm="$(/usr/bin/vm_stat 2>/dev/null || true)"
  page_size="$(printf '%s\n' "$vm" | awk '/page size of/ { gsub(/\./, "", $8); print $8; exit }')"
  page_size="${page_size:-4096}"
  used_pages="$(printf '%s\n' "$vm" | awk '
    /Anonymous pages/ { gsub(/\./, "", $3); anon=$3 }
    /Pages wired down/ { gsub(/\./, "", $4); wired=$4 }
    END { print anon + wired }
  ')"
  ram_used="$(awk -v p="$page_size" -v u="$used_pages" 'BEGIN { printf "%.0f", (p*u)/1024/1024/1024 }')"
  ram_total="$(awk -v t="$total_bytes" 'BEGIN { printf "%.0f", t/1024/1024/1024 }')"
  printf '%s %s %s %s\n' "$now" "$cpu" "$ram_used" "$ram_total" > "$sys_cache.tmp" && /bin/mv "$sys_cache.tmp" "$sys_cache"
fi

# Network cache. Use only the <Link#...> row for en0 to avoid
# duplicate IPv4/IPv6 rows. Store previous rendered rates so sub-second calls do
# not reset to 0 B/s.
net_cache="$cache_dir/net-${iface}.cache"
read -r in_bytes out_bytes <<EOF_NET
$(/usr/sbin/netstat -ibn 2>/dev/null | awk -v i="$iface" '$1 == i && $3 ~ /^<Link#/ { printf "%s %s", $7+0, $10+0; found=1; exit } END { if (!found) printf "0 0" }')
EOF_NET
down_rate=0
up_rate=0
if [[ -r "$net_cache" ]]; then
  read -r prev_t prev_in prev_out prev_down prev_up < "$net_cache" || true
  if [[ "${prev_t:-0}" =~ ^[0-9]+$ && "${prev_in:-0}" =~ ^[0-9]+$ && "${prev_out:-0}" =~ ^[0-9]+$ ]]; then
    dt=$(( now - prev_t ))
    if (( dt >= NET_INTERVAL && in_bytes >= prev_in && out_bytes >= prev_out )); then
      down_rate=$(( (in_bytes - prev_in) / dt ))
      up_rate=$(( (out_bytes - prev_out) / dt ))
      printf '%s %s %s %s %s\n' "$now" "$in_bytes" "$out_bytes" "$down_rate" "$up_rate" > "$net_cache.tmp" && /bin/mv "$net_cache.tmp" "$net_cache"
    elif (( dt < NET_INTERVAL )); then
      down_rate="${prev_down:-0}"
      up_rate="${prev_up:-0}"
    else
      printf '%s %s %s 0 0\n' "$now" "$in_bytes" "$out_bytes" > "$net_cache.tmp" && /bin/mv "$net_cache.tmp" "$net_cache"
    fi
  else
    printf '%s %s %s 0 0\n' "$now" "$in_bytes" "$out_bytes" > "$net_cache.tmp" && /bin/mv "$net_cache.tmp" "$net_cache"
  fi
else
  printf '%s %s %s 0 0\n' "$now" "$in_bytes" "$out_bytes" > "$net_cache.tmp" && /bin/mv "$net_cache.tmp" "$net_cache"
fi
down="$(rate_fmt "$down_rate")"
up="$(rate_fmt "$up_rate")"

# Disk cache.
disk_cache="$cache_dir/disk.cache"
disk="SSD ?Gi free"
if [[ -r "$disk_cache" ]]; then
  read -r disk_t disk < "$disk_cache" || true
else
  disk_t=0
fi
if ! [[ "${disk_t:-0}" =~ ^[0-9]+$ ]] || (( now - disk_t >= DISK_INTERVAL )); then
  disk_path="/"
  [[ -d /System/Volumes/Data ]] && disk_path="/System/Volumes/Data"
  disk="$(/bin/df -g "$disk_path" 2>/dev/null | awk 'NR == 2 { printf "SSD %sGi free", $4 }')"
  disk="${disk:-SSD ?Gi free}"
  printf '%s %s\n' "$now" "$disk" > "$disk_cache.tmp" && /bin/mv "$disk_cache.tmp" "$disk_cache"
fi

# Battery cache.
batt_cache="$cache_dir/battery.cache"
batt="AC"
if [[ -r "$batt_cache" ]]; then
  read -r batt_t batt < "$batt_cache" || true
else
  batt_t=0
fi
if ! [[ "${batt_t:-0}" =~ ^[0-9]+$ ]] || (( now - batt_t >= BATT_INTERVAL )); then
  batt="$(/usr/bin/pmset -g batt 2>/dev/null | /usr/bin/grep -Eo '[0-9]+%' | /usr/bin/head -1)"
  batt="${batt:-AC}"
  printf '%s %s\n' "$now" "$batt" > "$batt_cache.tmp" && /bin/mv "$batt_cache.tmp" "$batt_cache"
fi

clock="$(/bin/date '+%Y-%m-%d %H:%M:%S')"

bar="$({
  printf '#[bg=%s]' "$BG"
  printf '#[fg=%s,bg=%s,bold] %s%% ' "$ORANGE" "$BLOCK" "$cpu"
  printf '#[fg=%s,bg=%s,bold] RAM #[fg=%s,bg=%s,bold] %sGB/%s GB ' "$ORANGE" "$BG" "$ORANGE" "$BG" "$ram_used" "$ram_total"
  printf '#[fg=%s,bg=%s,bold] [%s] ↓  %s • ↑  %s ' "$DARK" "$CYAN" "$iface" "$down" "$up"
  printf '#[fg=%s,bg=%s,bold] %s ' "$ORANGE" "$BG" "$disk"
  printf '#[fg=%s,bg=%s,bold] %s ' "$ORANGE" "$BG" "$clock"
  printf '#[fg=%s,bg=%s,bold] ♥ %s ' "$ORANGE" "$BG" "$batt"
})"

printf '%s' "$bar" > "$render_cache.tmp" && /bin/mv "$render_cache.tmp" "$render_cache"
printf '%s' "$bar"
