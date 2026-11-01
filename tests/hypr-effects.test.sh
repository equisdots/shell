#!/usr/bin/env bash
# Sandbox tests for core/scripts/hypr-effects.sh.
#
# A fake hyprctl emulates both Hyprland 0.57 (decoration:blur:variant exists)
# and 0.56 (the 0.57 options are unknown). HYPR_CONFIG_DIR points at a temp
# directory, so no real config is touched.
#
# Asserts:
#   · read reports supports_057=1|0 and the 0.57 keys only on 0.57.
#   · generated window-effects.lua carries variant/proportional/wobble on
#     0.57 and omits them entirely on 0.56.
#   · clamping: wobble_intensity 99 -> 2, invalid variant -> kawase,
#     rounding 999 -> 100, shadow_render_power 99 -> 4.
#
# Usage: bash tests/hypr-effects.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/core/scripts/hypr-effects.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/hypr-effects-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

BIN="$TMP/bin"
mkdir -p "$BIN" "$TMP/conf57" "$TMP/conf56"
EVAL_LOG="$TMP/eval.log"

cat > "$BIN/hyprctl" <<'FAKE'
#!/usr/bin/env bash
# Fake hyprctl: answers the getoptions read by hypr-effects.sh and logs evals.
mode="${FAKE_HYPR_MODE:-0.57}"
case "${1:-}" in
    -j)
        opt="${3:-}"
        if [[ "$mode" == "0.56" ]]; then
            case "$opt" in
                decoration:blur:variant|decoration:blur:proportional|\
                decoration:wobble:enabled|decoration:wobble:intensity)
                    echo "error: no such option" >&2
                    exit 1
                    ;;
            esac
        fi
        case "$opt" in
            decoration:active_opacity)     echo '{"option":"decoration:active_opacity","float":0.85}' ;;
            decoration:inactive_opacity)   echo '{"option":"decoration:inactive_opacity","float":0.8}' ;;
            decoration:rounding)           echo '{"option":"decoration:rounding","int":20}' ;;
            decoration:blur:size)          echo '{"option":"decoration:blur:size","int":8}' ;;
            decoration:blur:passes)        echo '{"option":"decoration:blur:passes","int":3}' ;;
            general:gaps_in)               echo '{"option":"general:gaps_in","css":"16 16 16 16"}' ;;
            general:gaps_out)              echo '{"option":"general:gaps_out","css":"25 25 25 25"}' ;;
            general:border_size)           echo '{"option":"general:border_size","int":2}' ;;
            decoration:shadow:range)       echo '{"option":"decoration:shadow:range","int":35}' ;;
            decoration:shadow:render_power) echo '{"option":"decoration:shadow:render_power","int":4}' ;;
            decoration:shadow:offset)      echo '{"option":"decoration:shadow:offset","vec2":[0,10]}' ;;
            decoration:blur:variant)       echo '{"option":"decoration:blur:variant","int":0}' ;;
            decoration:blur:proportional)  echo '{"option":"decoration:blur:proportional","bool":false}' ;;
            decoration:wobble:enabled)     echo '{"option":"decoration:wobble:enabled","bool":false}' ;;
            decoration:wobble:intensity)   echo '{"option":"decoration:wobble:intensity","float":0.2}' ;;
            *)
                echo '{}'
                ;;
        esac
        ;;
    eval)
        printf '%s\n' "${2:-}" >> "${FAKE_HYPR_EVAL_LOG:-/dev/null}"
        ;;
esac
exit 0
FAKE
chmod +x "$BIN/hyprctl"

passed=0
failed=0

ok()   { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $*"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then ok; else fail "$desc: expected '$expected', got '$actual'"; fi
}

assert_contains() {
    local desc="$1" needle="$2" file="$3"
    if grep -qF -- "$needle" "$file"; then ok; else fail "$desc: missing '$needle' in $file"; fi
}

assert_not_contains() {
    local desc="$1" needle="$2" file="$3"
    if grep -qF -- "$needle" "$file"; then fail "$desc: unexpected '$needle' in $file"; else ok; fi
}

run() {
    # run <mode> <config-dir> <script args...>
    local mode="$1" conf="$2"; shift 2
    PATH="$BIN:$PATH" \
    FAKE_HYPR_MODE="$mode" \
    FAKE_HYPR_EVAL_LOG="$EVAL_LOG" \
    HYPR_CONFIG_DIR="$conf" \
    bash "$SCRIPT" "$@"
}

# ── 0.57 ──────────────────────────────────────────────────────────────────
read57="$(run 0.57 "$TMP/conf57" read)"

assert_eq "0.57 supports_057" "1" \
    "$(awk -F= '$1 == "supports_057" { print $2 }' <<<"$read57")"
assert_eq "0.57 reads blur_variant" "kawase" \
    "$(awk -F= '$1 == "blur_variant" { print $2 }' <<<"$read57")"
assert_eq "0.57 reads blur_proportional" "0" \
    "$(awk -F= '$1 == "blur_proportional" { print $2 }' <<<"$read57")"
assert_eq "0.57 reads wobble_enabled" "0" \
    "$(awk -F= '$1 == "wobble_enabled" { print $2 }' <<<"$read57")"
assert_eq "0.57 reads wobble_intensity" "0.2" \
    "$(awk -F= '$1 == "wobble_intensity" { print $2 }' <<<"$read57")"
assert_eq "0.57 reads existing keys" "20" \
    "$(awk -F= '$1 == "rounding" { print $2 }' <<<"$read57")"

# Preview clamps 0.57 values and applies them live.
run 0.57 "$TMP/conf57" preview \
    wobble_intensity=99 blur_variant=not-a-variant wobble_enabled=1 blur_proportional=1 \
    >/dev/null

state57="$TMP/conf57/window-effects.json"
assert_eq "state clamps wobble_intensity" "2" "$(jq -r '.wobble_intensity' "$state57")"
assert_eq "state canonicalises variant" "kawase" "$(jq -r '.blur_variant' "$state57")"
assert_eq "state stores wobble_enabled" "1" "$(jq -r '.wobble_enabled' "$state57")"
assert_eq "state stores blur_proportional" "1" "$(jq -r '.blur_proportional' "$state57")"

assert_contains "live eval carries variant" 'variant = "kawase"' "$EVAL_LOG"
assert_contains "live eval carries proportional" 'proportional = true' "$EVAL_LOG"
# join() in the kernel separates with a comma (no space); Lua accepts both.
assert_contains "live eval carries wobble" 'wobble = { enabled = true,intensity = 2 }' "$EVAL_LOG"

# Persist writes the 0.57 keys into the generated Lua.
run 0.57 "$TMP/conf57" persist >/dev/null
lua57="$TMP/conf57/window-effects.lua"

assert_contains "lua has variant" 'variant      = "kawase"' "$lua57"
assert_contains "lua has proportional" 'proportional = true' "$lua57"
assert_contains "lua has wobble table" 'wobble = {' "$lua57"
assert_contains "lua has wobble enabled" 'enabled   = true' "$lua57"
assert_contains "lua has wobble intensity" 'intensity = 2' "$lua57"

# Valid variant round-trip.
run 0.57 "$TMP/conf57" apply blur_variant=aurora wobble_intensity=0.5 >/dev/null
assert_eq "state keeps aurora" "aurora" "$(jq -r '.blur_variant' "$state57")"
assert_contains "lua has aurora" 'variant      = "aurora"' "$lua57"
assert_contains "lua has 0.5 intensity" 'intensity = 0.5' "$lua57"

# Existing 0.57 limits still clamp.
run 0.57 "$TMP/conf57" apply rounding=999 shadow_render_power=99 wobble_intensity=99 >/dev/null
assert_contains "lua clamps rounding" 'rounding         = 100' "$lua57"
assert_contains "lua clamps render_power" 'render_power = 4' "$lua57"
assert_contains "lua clamps wobble intensity" 'intensity = 2' "$lua57"

# ── 0.56 ──────────────────────────────────────────────────────────────────
read56="$(run 0.56 "$TMP/conf56" read)"

assert_eq "0.56 supports_057" "0" \
    "$(awk -F= '$1 == "supports_057" { print $2 }' <<<"$read56")"
assert_eq "0.56 omits blur_variant from read" "" \
    "$(awk -F= '$1 == "blur_variant" { print $2 }' <<<"$read56")"

# Clear the live-eval log so the 0.56 assertions cannot see the 0.57 run.
: > "$EVAL_LOG"
run 0.56 "$TMP/conf56" apply \
    blur_variant=aurora blur_proportional=1 wobble_enabled=1 wobble_intensity=1.5 \
    rounding=30 >/dev/null

state56="$TMP/conf56/window-effects.json"
lua56="$TMP/conf56/window-effects.lua"

assert_eq "0.56 does not store blur_variant" "" "$(jq -r '.blur_variant // empty' "$state56")"
assert_eq "0.56 does not store blur_proportional" "" "$(jq -r '.blur_proportional // empty' "$state56")"
assert_eq "0.56 does not store wobble_enabled" "" "$(jq -r '.wobble_enabled // empty' "$state56")"
assert_eq "0.56 does not store wobble_intensity" "" "$(jq -r '.wobble_intensity // empty' "$state56")"
assert_eq "0.56 still applies normal keys" "30" "$(jq -r '.rounding' "$state56")"

assert_not_contains "0.56 lua has no variant" 'variant' "$lua56"
assert_not_contains "0.56 lua has no proportional" 'proportional' "$lua56"
assert_not_contains "0.56 lua has no wobble" 'wobble' "$lua56"
assert_not_contains "0.56 eval has no variant" 'variant' "$EVAL_LOG"
assert_not_contains "0.56 eval has no wobble" 'wobble' "$EVAL_LOG"
assert_contains "0.56 lua still has blur" 'blur = {' "$lua56"

echo "hypr-effects: $passed passed, $failed failed"
exit $(( failed == 0 ? 0 : 1 ))
