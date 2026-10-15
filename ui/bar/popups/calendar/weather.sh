#!/usr/bin/env bash
# Thin shim for the bar/calendar weather consumers: the timex engine ships
# with the timex plugin now; resolve its copy across deploy layouts (managed
# shell tree, user plugin, classic ~/.local/bin wrapper from earlier
# installs). Kept at this path so the bar callers do not change.
if [ -n "${TIMEX_CLI:-}" ]; then
    exec "$TIMEX_CLI" "$@"
fi
T=""
for c in \
    "$HOME/.config/hypr/scripts/quickshell/ui/plugins/timex/core/timex.sh" \
    "$HOME/.config/hypr/plugins-user/timex/core/timex.sh" \
    "$HOME/.local/bin/timex" \
    "$HOME/.local/share/equisdots/timex/core/timex.sh"; do
    [ -f "$c" ] && { T="$c"; break; }
done
[ -n "$T" ] || exit 0
exec bash "$T" "$@"
