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
# AUTONOMY: each plugin owns its settings in ITS OWN file
# (<dir>/settings.json), never mixed into the core settings.json. This scan
# resolves `enabled` from the plugin's OWN file (the manifest's toggle path, or
# <scope>.enabled, falling back to the manifest's defaultEnabled). The
# shell-side metadata `plugins.<id>.config` (the settings-menu switch) stays in
# the core settings.json (the shell owns it). Every entry gets "_base".
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

# Core settings.json: only the shell metadata (plugins.<id>.config) is read here.
settings_obj='{}'
if [ -f "$SETTINGS" ] && jq -e . "$SETTINGS" >/dev/null 2>&1; then
    settings_obj=$(jq -c . "$SETTINGS")
fi

# Compatibility annotation (see equisdots/plugin-api).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPAT="$SCRIPT_DIR/plugins_compat.sh"
API_FILE="${PLUGINS_API_FILE:-$SCRIPT_DIR/../../plugin-api.json}"
HOST_API="$(jq -r '.api // empty' "$API_FILE" 2>/dev/null || true)"
SHELL_VERSION="$(jq -r '.shell // empty' "$API_FILE" 2>/dev/null || true)"

# One manifest -> one normalized object. `enabled` resolves from the plugin's
# OWN settings file; `config` (settings-menu switch) from settings.json.
one() {
    local dir="$1" pset='{}'
    [ -f "$dir/plugin.json" ] || return 0
    if [ -f "$dir/settings.json" ] && jq -e . "$dir/settings.json" >/dev/null 2>&1; then
        pset="$(jq -c . "$dir/settings.json")"
    fi
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
    jq -c --arg base "$dir" --argjson pset "$pset" --argjson settings "$settings_obj" --argjson verdict "$verdict" '
        . as $m
        | select(($m.id // "") != "")
        | ($m.scope // ("plugins." + $m.id)) as $scope
        | ($m.toggle // ($scope + ".enabled")) as $toggle
        | ($toggle | split(".")) as $path
        | (try ($pset | getpath($path)) catch null) as $val
        | (try ($settings | getpath(["plugins", $m.id, "config"])) catch null) as $cfg
        | ($m + {
            _base: $base,
            toggle: $toggle,
            enabled: (if $val == null then ($m.defaultEnabled // false) else ($val == true) end),
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
