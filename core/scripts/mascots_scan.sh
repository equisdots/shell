#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# mascots_scan.sh — discovery for the Nyx notch.
#
# Emits a single JSON object: { "mascots": [ ... ], "things": [ ... ] }.
#
#   mascots  one *.json manifest per species, under the shipped (nyx) and user
#            species dirs. A manifest may carry "entry" (a QML file resolved
#            relative to the manifest dir) for a custom species; without it the
#            species is one of the built-in kinds (id == kind).
#   things   one *.json descriptor per notch card, under the shipped (repo) and
#            user notch dirs: { id, label, icon, thumb?, exec?, enabled? }.
#
# The user dirs are scanned first and win on id collisions, so a user file
# overrides or extends the shipped defaults. Every entry gets "_base" (its
# directory) so the caller can resolve relative QML entries.
#
# Env (all optional): MASCOTS_SHIPPED, MASCOTS_USER, THINGS_SHIPPED, THINGS_USER
# ═══════════════════════════════════════════════════════════════════════════

set -u

if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' '{"mascots":[],"things":[]}'
    exit 0
fi

scan_dir() {
    local dir="$1"
    [ -n "$dir" ] && [ -d "$dir" ] || return 0
    local f
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        # A file may hold one object or an array of them (repo defaults ship an
        # array; a user drops a single object).
        jq -c --arg base "$dir" '
            if type == "array" then
                .[] | (if type == "object" then . + { _base: $base } else empty end)
            elif type == "object" then . + { _base: $base }
            else empty end' "$f" 2>/dev/null || true
    done
}

dedupe() {
    jq -s 'reduce .[] as $x ([]; if any(.[]; .id == $x.id) then . else . + [$x] end) // []'
}

mascots=$(
    { scan_dir "${MASCOTS_USER:-}"; scan_dir "${MASCOTS_SHIPPED:-}"; } | dedupe
)
things=$(
    { scan_dir "${THINGS_USER:-}"; scan_dir "${THINGS_SHIPPED:-}"; } | dedupe
)

jq -nc --argjson m "${mascots:-[]}" --argjson t "${things:-[]}" \
    '{ mascots: $m, things: $t }'
