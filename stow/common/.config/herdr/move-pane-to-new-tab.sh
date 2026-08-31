#!/bin/sh
# Move the active Herdr pane out into a new tab, leaving focus where it is.
# Bound to prefix+shift+m via [[keys.command]] in config.toml.
#
# Herdr hands type="shell" commands HERDR_BIN_PATH and HERDR_ACTIVE_PANE_ID,
# so we use those rather than the globally focused pane, which belongs to
# whichever client last took focus.
#
# Herdr refuses to move a pane out of a zoomed tab: the move returns
# changed=false with reason "zoomed_tab" and exit status 0. Unzoom first,
# and check `changed` rather than trusting the exit status.
set -eu

log=/tmp/herdr-move-pane.log
jq=/usr/bin/jq

printf '%s invoked pane=%s\n' "$(date +%FT%T)" "${HERDR_ACTIVE_PANE_ID:-unset}" >>"$log"

herdr_bin="${HERDR_BIN_PATH:-}"
if [ -z "$herdr_bin" ] || [ ! -x "$herdr_bin" ]; then
  PATH="$HOME/.local/share/mise/installs/github-ogulcancelik-herdr/latest:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
  export PATH
  herdr_bin=$(command -v herdr || true)
fi
[ -n "$herdr_bin" ] || { echo "  no herdr binary found" >>"$log"; exit 1; }

pane="${HERDR_ACTIVE_PANE_ID:-}"
if [ -z "$pane" ]; then
  pane=$("$herdr_bin" api snapshot | "$jq" -r '.result.snapshot.focused_pane_id // empty')
  echo "  HERDR_ACTIVE_PANE_ID unset, fell back to focused pane $pane" >>"$log"
fi
[ -n "$pane" ] || { echo "  no pane id" >>"$log"; exit 1; }

"$herdr_bin" pane zoom --pane "$pane" --off >/dev/null 2>&1 || true

out=$("$herdr_bin" pane move "$pane" --new-tab --no-focus 2>&1) || true
changed=$(printf '%s' "$out" | "$jq" -r '.result.move_result.changed // false' 2>/dev/null || echo false)

if [ "$changed" = "true" ]; then
  new_tab=$(printf '%s' "$out" | "$jq" -r '.result.move_result.pane.tab_id // "?"')
  printf '  ok pane=%s -> tab=%s\n' "$pane" "$new_tab" >>"$log"
else
  reason=$(printf '%s' "$out" | "$jq" -r '.result.move_result.reason // .error.message // "unknown"' 2>/dev/null || echo unknown)
  printf '  NO-OP pane=%s reason=%s\n' "$pane" "$reason" >>"$log"
fi
