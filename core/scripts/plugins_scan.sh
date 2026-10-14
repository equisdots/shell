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

# Compatibility annotation (see equisdots/plugin-api). The evaluator + the API
# version file are vendored with the shell; a plugin's `compat` ranges are
# resolved to {state, ok, reason, requires, seen}.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPAT="$SCRIPT_DIR/plugins_compat.sh"
API_FILE="${PLUGINS_API_FILE:-$SCRIPT_DIR/../../plugin-api.json}"
HOST_API="$(jq -r '.api // empty' "$API_FILE" 2>/dev/null || true)"
SHELL_VERSION="$(jq -r '.shell // empty' "$API_FILE" 2>/dev/null || true)"

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
    local verdict='{"state":"ok","ok":true,"reason":""}'
    if [ -x "$COMPAT" ]; then
        local c; c=$(jq -c '.compat // empty' "$dir/plugin.json" 2>/dev/null || true)
        if [ -n "$c" ] && [ "$c" != "null" ]; then
            verdict=$(HOST_API="$HOST_API" SHELL_VERSION="$SHELL_VERSION" \
                      HYPRLAND_VERSION="${PLUGINS_HYPRLAND:-}" \
                      QUICKSHELL_VERSION="${PLUGINS_QS:-}" \
                      QT_VERSION="${PLUGINS_QT:-}" \
                      bash "$COMPAT" <<<"$c" 2>/dev/null || echo "$verdict")
        fi
    fi
    jq -c --arg base "$dir" --argjson settings "$settings_obj" --argjson verdict "$verdict" '
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
          }) | .compat = $verdict' "$dir/plugin.json" 2>/dev/null || true
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
