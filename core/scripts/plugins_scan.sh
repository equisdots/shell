#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# plugins_scan.sh — discovery for the equisdots plugin standard (shell side).
#
# Emits a single JSON array: one object per installed plugin, sorted by name.
# A plugin is any directory containing a plugin.json manifest, scanned in:
#
#   user    $PLUGINS_USER     (default ~/.config/hypr/plugins-user)   — wins
#   managed $PLUGINS_MANAGED  (default ~/.config/hypr/plugins)        — dots
#
# The user dir is scanned first and wins on id collisions. `enabled` resolves
# the plugin's effective switch from settings.json: plugin.json "toggle" (a
# settings path) or the default plugins.<id>.enabled, falling back to the
# manifest's "defaultEnabled". Every entry gets "_base" (its directory) so
# callers can resolve relative payloads (hypr.lua, scripts/).
#
# Env (all optional): PLUGINS_USER, PLUGINS_MANAGED, PLUGINS_SETTINGS
# ═══════════════════════════════════════════════════════════════════════════

set -u

if ! command -v jq >/dev/null 2>&1; then
    printf '[]\n'
    exit 0
fi

USER_DIR="${PLUGINS_USER:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/plugins-user}"
MANAGED_DIR="${PLUGINS_MANAGED:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/plugins}"
SETTINGS="${PLUGINS_SETTINGS:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/settings.json}"

settings_obj='{}'
if [ -f "$SETTINGS" ] && jq -e . "$SETTINGS" >/dev/null 2>&1; then
    settings_obj=$(jq -c . "$SETTINGS")
fi

# One manifest -> one normalized object with _base + resolved enabled state
# (`enabled` from the toggle path / defaultEnabled; `config`, the settings-menu
# switch, from plugins.<id>.config, default true).
one() {
    local dir="$1"
    [ -f "$dir/plugin.json" ] || return 0
    jq -c --arg base "$dir" --argjson settings "$settings_obj" '
        . as $m
        | select(($m.id // "") != "")
        | ($m.toggle // ("plugins." + $m.id + ".enabled")) as $toggle
        | ($toggle | split(".")) as $path
        | (try ($settings | getpath($path)) catch null) as $val
        | (try ($settings | getpath(["plugins", $m.id, "config"])) catch null) as $cfg
        | ($m + {
            _base: $base,
            toggle: $toggle,
            enabled: (if $val == null
                      then ($m.defaultEnabled // false)
                      else ($val == true) end),
            config: (if $cfg == null then true else ($cfg == true) end)
          })' "$dir/plugin.json" 2>/dev/null || true
}

scan_dir() {
    local dir="$1" e
    [ -n "$dir" ] && [ -d "$dir" ] || return 0
    for e in "$dir"/*/; do
        [ -d "$e" ] || continue
        one "${e%/}"
    done
}

{ scan_dir "$USER_DIR"; scan_dir "$MANAGED_DIR"; } \
    | jq -s 'reduce .[] as $x ([]; if any(.[]; .id == $x.id) then . else . + [$x] end)
             | sort_by((.name // .id) | ascii_downcase)' \
    || printf '[]\n'
