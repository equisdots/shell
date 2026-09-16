#!/usr/bin/env bash
# Thin shim: the timex engine lives in its own repo (equisdots/timex) and is
# deployed as ~/.local/bin/timex (wrapper over ~/.local/share/equisdots/timex).
# Kept at this path so the bar/calendar callers do not change.
exec "${TIMEX_CLI:-$HOME/.local/bin/timex}" "$@"
