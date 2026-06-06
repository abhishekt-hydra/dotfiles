#!/usr/bin/env bash
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

BG="#111111"
BLOCK="#3d4056"
ORANGE="#ffb86c"
CYAN="#8be9fd"
DARK="#111111"

rate_fmt() {
  awk -v b="${1:-0}" 'BEGIN {
    if (b >= 1048576) printf "%.2f MB/s", b / 1048576;
    else if (b >= 1024) printf "%.2f kB/s", b / 1024;
    else printf "%d B/s", b;
  }'
}

# CPU as percent of all cores.
cores="$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || printf '1')"
cpu="$(/bin/ps -A -o %cpu= 2>/dev/null | awk -v n="$cores" '{ s += $1 } END { if (n < 1) n = 1; printf "%.0f", s / n }')"
cpu="${cpu:-0}"

# RAM used/total in GiB.
# Use app-ish resident memory: anonymous + wired. This excludes inactive/file cache,
# so it looks closer to common status bars than macOS `top`'s "PhysMem used".
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

# Network throughput for en0 using byte deltas.
iface="en0"
now="$(/bin/date +%s)"
read -r in_bytes out_bytes <<EOF_NET
$(/usr/sbin/netstat -ibn 2>/dev/null | awk -v i="$iface" '$1 == i && $7 > 0 { inb=$7; outb=$10 } END { printf "%s %s", inb+0, outb+0 }')
EOF_NET
cache="${TMPDIR:-/tmp}/zellij-zjstatus-${iface}.cache"
down_rate=0
up_rate=0
if [[ -r "$cache" ]]; then
  read -r prev_t prev_in prev_out < "$cache" || true
  if [[ "${prev_t:-0}" =~ ^[0-9]+$ && "${prev_in:-0}" =~ ^[0-9]+$ && "${prev_out:-0}" =~ ^[0-9]+$ ]]; then
    dt=$(( now - prev_t ))
    if (( dt > 0 && in_bytes >= prev_in && out_bytes >= prev_out )); then
      down_rate=$(( (in_bytes - prev_in) / dt ))
      up_rate=$(( (out_bytes - prev_out) / dt ))
    fi
  fi
fi
printf '%s %s %s\n' "$now" "$in_bytes" "$out_bytes" > "$cache"
down="$(rate_fmt "$down_rate")"
up="$(rate_fmt "$up_rate")"

# Disk: available/total and used percentage for root volume.
disk="$(/bin/df -g / 2>/dev/null | awk 'NR == 2 { printf "%sGi/%sGi (%s)", $4, $2, $5 }')"
disk="${disk:-?Gi/?Gi}"

# Battery percentage.
batt="$(/usr/bin/pmset -g batt 2>/dev/null | /usr/bin/grep -Eo '[0-9]+%' | /usr/bin/head -1)"
batt="${batt:-AC}"
clock="$(/bin/date '+%H:%M:%S')"

printf '#[bg=%s]' "$BG"
printf '#[fg=%s,bg=%s,bold] CPU #[fg=%s,bg=%s,bold] %s%% ' "$ORANGE" "$BLOCK" "$ORANGE" "$BG" "$cpu"
printf '#[fg=%s,bg=%s,bold] RAM #[fg=%s,bg=%s,bold] %sGB/%s GB ' "$ORANGE" "$BG" "$ORANGE" "$BG" "$ram_used" "$ram_total"
printf '#[fg=%s,bg=%s,bold] [%s] ↓  %s • ↑  %s ' "$DARK" "$CYAN" "$iface" "$down" "$up"
printf '#[fg=%s,bg=%s,bold] 💾  %s ' "$ORANGE" "$BG" "$disk"
printf '#[fg=%s,bg=%s,bold] %s ' "$ORANGE" "$BG" "$clock"
printf '#[fg=%s,bg=%s,bold] ♥%s ' "$ORANGE" "$BG" "$batt"
