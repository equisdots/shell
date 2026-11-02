#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# hypr-effects.sh — shared kernel for the window-effect knobs
# (BarEditor → Hyprland tab and Window Controls, SUPER+SHIFT+B).
#
#   read                prints key=value with the LIVE values (hyprctl -j)
#   preview KEY=VAL ... updates the JSON state (source of truth) and applies
#                       those keys live with `hyprctl eval`. It does NOT touch
#                       the Lua overrides: Hyprland auto-reloads when a loaded
#                       config file changes, which is the visible "all windows
#                       restart" while dragging.
#   persist             regenerates config/window-effects.lua + config/gaps.lua
#                       from the JSON state (one Hyprland auto-reload).
#   apply KEY=VAL ...   preview + persist (CLI/manual use).
#
# State lives in config/window-effects.json and is seeded from the live values
# the first time. A partial change can never clobber the other knobs (the old
# bug: rewriting all 12 with misread gaps = reset).
#
# Environment:
#   HYPR_CONFIG_DIR    output directory (default ~/.config/hypr/config)
#   HYPR_NO_EVAL=1     do not call hyprctl (tests)
#   HYPR_SUPPORTS_057  0/1 to force the 0.57 feature probe (tests)
# ═══════════════════════════════════════════════════════════════════════════
set -u

# awk is used for decimal clamps; keep its output in C locale so a comma
# decimal separator can never leak into the JSON or the generated Lua.
export LC_NUMERIC=C

CONF_DIR="${HYPR_CONFIG_DIR:-$HOME/.config/hypr/config}"
STATE="$CONF_DIR/window-effects.json"
mkdir -p "$CONF_DIR" || exit 1

# key · option · kind (float|int|bool|str|cssgap|vec2x|vec2y)
SPECS=(
    "active_opacity decoration:active_opacity float"
    "inactive_opacity decoration:inactive_opacity float"
    "rounding decoration:rounding int"
    "blur_enabled decoration:blur:enabled bool"
    "blur_size decoration:blur:size int"
    "blur_passes decoration:blur:passes int"
    "gaps_in general:gaps_in cssgap"
    "gaps_out general:gaps_out cssgap"
    "border_size general:border_size int"
    "shadow_enabled decoration:shadow:enabled bool"
    "dim_inactive decoration:dim_inactive bool"
    "shadow_range decoration:shadow:range int"
    "shadow_render_power decoration:shadow:render_power int"
    "shadow_offset_x decoration:shadow:offset vec2x"
    "shadow_offset_y decoration:shadow:offset vec2y"
    # 0.57-only (guarded by supports_057 everywhere below).
    "blur_variant decoration:blur:variant str"
    "blur_proportional decoration:blur:proportional bool"
    "wobble_enabled decoration:wobble:enabled bool"
    "wobble_intensity decoration:wobble:intensity float"
)

# 0.57-only keys. On <= 0.56 they are neither read nor written.
is_057_key() {
    case "$1" in
        blur_variant|blur_proportional|wobble_enabled|wobble_intensity) return 0 ;;
    esac
    return 1
}

# Probes decoration:blur:variant, which only exists from Hyprland 0.57.
# Cached for the life of the process; HYPR_SUPPORTS_057 overrides it.
_SUPPORTS_057=""
supports_057() {
    if [[ -n "$_SUPPORTS_057" ]]; then
        [[ "$_SUPPORTS_057" == "1" ]]
        return
    fi
    case "${HYPR_SUPPORTS_057:-}" in
        1) _SUPPORTS_057=1; return 0 ;;
        0) _SUPPORTS_057=0; return 1 ;;
    esac

    local json
    if json="$(hyprctl -j getoption decoration:blur:variant 2>/dev/null)" \
        && jq -e '.option == "decoration:blur:variant"' >/dev/null 2>&1 <<<"$json"; then
        _SUPPORTS_057=1
        return 0
    fi
    _SUPPORTS_057=0
    return 1
}

# Integer clamp: invalid input falls back to the default.
clamp_int() {
    local min="$1" max="$2" def="$3" v="$4"
    if [[ ! "$v" =~ ^-?[0-9]+$ ]]; then printf '%s' "$def"; return 0; fi
    if (( v < min )); then v=$min; fi
    if (( v > max )); then v=$max; fi
    printf '%s' "$v"
}

# Float clamp (awk keeps the script POSIX-ish for decimal comparisons).
clamp_float() {
    local min="$1" max="$2" def="$3" v="$4"
    awk -v v="$v" -v min="$min" -v max="$max" -v def="$def" 'BEGIN {
        if (v !~ /^-?[0-9]+([.][0-9]+)?$/) { print def; exit }
        n = v + 0
        if (n < min) n = min
        if (n > max) n = max
        print n
    }'
}

# Clamp values that Hyprland validates (0.57 rejects out-of-range options).
# blur_variant also canonicalises the 0.57 enum (index or name -> name).
clamp_value() {
    local key="$1" v="$2"
    case "$key" in
        active_opacity)      v="$(clamp_float 0 1 0.85 "$v")" ;;
        inactive_opacity)    v="$(clamp_float 0 1 0.80 "$v")" ;;
        rounding)            v="$(clamp_int 0 100 20 "$v")" ;;
        blur_size)           v="$(clamp_int 0 100 8 "$v")" ;;
        blur_passes)         v="$(clamp_int 0 10 3 "$v")" ;;
        gaps_in)             v="$(clamp_int 0 100 16 "$v")" ;;
        gaps_out)            v="$(clamp_int 0 100 25 "$v")" ;;
        border_size)         v="$(clamp_int 0 20 2 "$v")" ;;
        shadow_range)        v="$(clamp_int 0 100 35 "$v")" ;;
        shadow_render_power) v="$(clamp_int 1 4 4 "$v")" ;;
        shadow_offset_x)     v="$(clamp_int -100 100 0 "$v")" ;;
        shadow_offset_y)     v="$(clamp_int -100 100 10 "$v")" ;;
        blur_enabled|shadow_enabled|dim_inactive|blur_proportional|wobble_enabled)
            case "$v" in
                1|true|True|TRUE|on|yes) v=1 ;;
                *) v=0 ;;
            esac ;;
        wobble_intensity)    v="$(clamp_float 0 2 0.2 "$v")" ;;
        blur_variant)
            case "$v" in
                0|kawase)        v=kawase ;;
                1|frost)         v=frost ;;
                2|ripple)        v=ripple ;;
                3|drops)         v=drops ;;
                4|water)         v=water ;;
                5|fluid_jar)     v=fluid_jar ;;
                6|prism)         v=prism ;;
                7|heat_shimmer)  v=heat_shimmer ;;
                8|acrylic)       v=acrylic ;;
                9|aurora)        v=aurora ;;
                10|haze)         v=haze ;;
                *)               v=kawase ;;
            esac ;;
    esac
    printf '%s' "$v"
}

# Lua boolean literal from a 0/1 value.
lua_bool() {
    if [[ "$1" == "1" ]]; then printf 'true'; else printf 'false'; fi
}

read_one() {
    local key="$1" opt="$2" kind="$3" json v
    json="$(hyprctl -j getoption "$opt" 2>/dev/null)" || return 0
    case "$kind" in
        float)  v="$(jq -r '.float // empty' <<<"$json")" ;;
        int)    v="$(jq -r '.int // empty' <<<"$json")" ;;
        # 0.57 enum: .str carries the name, .int the index on some builds.
        str)
            v="$(jq -r '.str // empty' <<<"$json")"
            [[ -n "$v" && "$v" != "null" ]] || v="$(jq -r '.int // empty' <<<"$json")"
            ;;
        # Hyprland exposes booleans as .bool (hyprctl 0.57); older builds may
        # answer with .int 0/1.
        bool)
            v="$(jq -r 'if .bool == null and .int == null then empty
                        elif .bool == true or .int == 1 then "1"
                        else "0" end' <<<"$json")"
            ;;
        # Hyprland 0.55+ returns "css gap data: 48 48 48 48" (.css field);
        # the UI is scalar, so take the first side.
        cssgap) v="$(jq -r '.css // empty' <<<"$json" | awk '{print $1}')" ;;
        vec2x)  v="$(jq -r '.vec2[0] // empty' <<<"$json")" ;;
        vec2y)  v="$(jq -r '.vec2[1] // empty' <<<"$json")" ;;
    esac
    if [[ -n "$v" && "$v" != "null" ]]; then
        v="$(clamp_value "$key" "$v")"
        printf '%s=%s\n' "$key" "$v"
    fi
}

# Heal a legacy state file (and its generated Lua) once: values written before
# the 1..4 clamp (e.g. shadow_render_power = 10) or outside any 0.57 enum are
# fixed on the next read. Each fix is an atomic rewrite; the Lua is regenerated
# once at the end.
sanitize_state() {
    [[ -f "$STATE" ]] || return 0
    local key cur fixed tmp changed=0
    for key in shadow_render_power blur_variant blur_proportional wobble_enabled wobble_intensity; do
        cur="$(jq -r --arg k "$key" 'if has($k) then .[$k] else empty end' "$STATE" 2>/dev/null)" || continue
        [[ -n "$cur" && "$cur" != "null" ]] || continue
        fixed="$(clamp_value "$key" "$cur")"
        [[ "$fixed" == "$cur" ]] && continue
        tmp="$(mktemp "$CONF_DIR/.we-state.XXXXXX")" || return 1
        if [[ "$key" == "blur_variant" ]]; then
            jq -c --arg k "$key" --arg v "$fixed" '.[$k] = $v' "$STATE" > "$tmp" \
                || { rm -f "$tmp"; return 1; }
        else
            jq -c --arg k "$key" --argjson v "$fixed" '.[$k] = $v' "$STATE" > "$tmp" \
                || { rm -f "$tmp"; return 1; }
        fi
        mv "$tmp" "$STATE"
        changed=1
    done
    if [[ "$changed" == "1" ]]; then
        write_lua "$(cat "$STATE")"
    fi
}

cmd_read() {
    sanitize_state
    local spec
    for spec in "${SPECS[@]}"; do
        # Do not ask <= 0.56 for options it does not know.
        if is_057_key "${spec%% *}" && ! supports_057; then
            continue
        fi
        read_one $spec
    done
    if supports_057; then
        printf 'supports_057=1\n'
    else
        printf 'supports_057=0\n'
    fi
}

seed_state() {
    local json='{}' line k v tmp
    while IFS='=' read -r k v; do
        [[ -z "$k" || "$k" == "supports_057" ]] && continue
        if [[ "$k" == "blur_variant" ]]; then
            json="$(jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}' <<<"$json")" || return 1
        else
            json="$(jq -c --arg k "$k" --argjson v "$v" '. + {($k): $v}' <<<"$json")" || return 1
        fi
    done < <(cmd_read)
    tmp="$(mktemp "$CONF_DIR/.we-state.XXXXXX")" || return 1
    printf '%s\n' "$json" > "$tmp" && mv "$tmp" "$STATE"
}

# join with a comma (for the Lua snippets and tables; Lua accepts the tight form)
join() { local IFS=', '; printf '%s' "$*"; }

write_lua() {
    local state="$1" tmp
    local ao io ro be bs bp se gr go bw sr sp ox oy di
    # Clamp on the way out too: a hand-edited state file must never produce an
    # invalid Lua override (0.57 rejects out-of-range options).
    ao="$(clamp_value active_opacity   "$(jq -r '.active_opacity // 0.85'    <<<"$state")")"
    io="$(clamp_value inactive_opacity "$(jq -r '.inactive_opacity // 0.80'  <<<"$state")")"
    ro="$(clamp_value rounding         "$(jq -r '.rounding // 20'            <<<"$state")")"
    be="$(clamp_value blur_enabled     "$(jq -r 'if has("blur_enabled") then .blur_enabled else 1 end' <<<"$state")")"
    bs="$(clamp_value blur_size        "$(jq -r '.blur_size // 8'            <<<"$state")")"
    bp="$(clamp_value blur_passes      "$(jq -r '.blur_passes // 3'          <<<"$state")")"
    gr="$(clamp_value gaps_in          "$(jq -r '.gaps_in // 16'             <<<"$state")")"
    go="$(clamp_value gaps_out         "$(jq -r '.gaps_out // 25'            <<<"$state")")"
    bw="$(clamp_value border_size      "$(jq -r '.border_size // 2'          <<<"$state")")"
    se="$(clamp_value shadow_enabled   "$(jq -r 'if has("shadow_enabled") then .shadow_enabled else 1 end' <<<"$state")")"
    sr="$(clamp_value shadow_range     "$(jq -r '.shadow_range // 35'        <<<"$state")")"
    sp="$(clamp_value shadow_render_power "$(jq -r '.shadow_render_power // 4' <<<"$state")")"
    ox="$(clamp_value shadow_offset_x  "$(jq -r '.shadow_offset_x // 0'      <<<"$state")")"
    oy="$(clamp_value shadow_offset_y  "$(jq -r '.shadow_offset_y // 10'     <<<"$state")")"
    di="$(clamp_value dim_inactive     "$(jq -r 'if has("dim_inactive") then .dim_inactive else 1 end' <<<"$state")")"

    # 0.57-only blocks (empty on <= 0.56, so the Lua never carries unknown
    # keys there).
    local blur_block wobble_block=""
    if supports_057; then
        local bv bprop we wi
        bv="$(clamp_value blur_variant "$(jq -r '.blur_variant // "kawase"' <<<"$state")")"
        bprop="$(clamp_value blur_proportional "$(jq -r 'if has("blur_proportional") then .blur_proportional else 0 end' <<<"$state")")"
        we="$(clamp_value wobble_enabled "$(jq -r 'if has("wobble_enabled") then .wobble_enabled else 0 end' <<<"$state")")"
        wi="$(clamp_value wobble_intensity "$(jq -r '.wobble_intensity // 0.2' <<<"$state")")"
        blur_block="$(printf '            enabled      = %s,\n            size         = %s,\n            passes       = %s,\n            variant      = "%s",\n            proportional = %s,' \
            "$(lua_bool "$be")" "$bs" "$bp" "$bv" "$(lua_bool "$bprop")")"
        wobble_block="$(printf '\n        wobble = {\n            enabled   = %s,\n            intensity = %s,\n        },' \
            "$(lua_bool "$we")" "$wi")"
    else
        blur_block="$(printf '            enabled = %s,\n            size   = %s,\n            passes = %s,' "$(lua_bool "$be")" "$bs" "$bp")"
    fi

    tmp="$(mktemp "$CONF_DIR/.we-lua.XXXXXX")" || return 1
    cat > "$tmp" <<LUA
-- Auto-generated by core/scripts/hypr-effects.sh — do not edit manually
hl.config({
    decoration = {
        active_opacity   = $ao,
        inactive_opacity = $io,
        rounding         = $ro,

        blur = {
$blur_block
        },

        shadow = {
            enabled      = $(lua_bool "$se"),
            range        = $sr,
            render_power = $sp,
            offset       = { $ox, $oy },
        },

        dim_inactive = $(lua_bool "$di"),$wobble_block
    },
})
LUA
    if command -v luac >/dev/null 2>&1 && ! luac -p "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        echo "error: window-effects.lua does not compile" >&2
        return 1
    fi
    mv "$tmp" "$CONF_DIR/window-effects.lua"

    tmp="$(mktemp "$CONF_DIR/.we-lua.XXXXXX")" || return 1
    cat > "$tmp" <<LUA
-- Auto-generated by core/scripts/hypr-effects.sh — do not edit manually
hl.config({
    general = {
        gaps_in     = $gr,
        gaps_out    = $go,
        border_size = $bw,
    },
})
LUA
    if command -v luac >/dev/null 2>&1 && ! luac -p "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        echo "error: gaps.lua does not compile" >&2
        return 1
    fi
    mv "$tmp" "$CONF_DIR/gaps.lua"
}

# Applies LIVE only the patched keys (hl.config merges partial tables:
# it does not touch the rest of general/decoration).
apply_live() {
    local state pair k v
    state="$(cat "$STATE")"
    local -A patch=()
    for pair in "$@"; do
        patch["${pair%%=*}"]="${pair#*=}"
    done

    local general=() dec=() blur=() shadow=() wobble=()
    [[ -n "${patch[gaps_in]:-}"     ]] && general+=("gaps_in = $(clamp_value gaps_in "${patch[gaps_in]}")")
    [[ -n "${patch[gaps_out]:-}"    ]] && general+=("gaps_out = $(clamp_value gaps_out "${patch[gaps_out]}")")
    [[ -n "${patch[border_size]:-}" ]] && general+=("border_size = $(clamp_value border_size "${patch[border_size]}")")

    [[ -n "${patch[active_opacity]:-}"   ]] && dec+=("active_opacity = $(clamp_value active_opacity "${patch[active_opacity]}")")
    [[ -n "${patch[inactive_opacity]:-}" ]] && dec+=("inactive_opacity = $(clamp_value inactive_opacity "${patch[inactive_opacity]}")")
    [[ -n "${patch[rounding]:-}"         ]] && dec+=("rounding = $(clamp_value rounding "${patch[rounding]}")")
    [[ -n "${patch[blur_enabled]:-}" ]] && blur+=("enabled = $(lua_bool "$(clamp_value blur_enabled "${patch[blur_enabled]}")")")
    [[ -n "${patch[blur_size]:-}"   ]] && blur+=("size = $(clamp_value blur_size "${patch[blur_size]}")")
    [[ -n "${patch[blur_passes]:-}" ]] && blur+=("passes = $(clamp_value blur_passes "${patch[blur_passes]}")")
    [[ -n "${patch[shadow_enabled]:-}" ]] && shadow+=("enabled = $(lua_bool "$(clamp_value shadow_enabled "${patch[shadow_enabled]}")")")
    [[ -n "${patch[shadow_range]:-}"        ]] && shadow+=("range = $(clamp_value shadow_range "${patch[shadow_range]}")")
    [[ -n "${patch[shadow_render_power]:-}" ]] && shadow+=("render_power = $(clamp_value shadow_render_power "${patch[shadow_render_power]}")")
    if [[ -n "${patch[shadow_offset_x]:-}" || -n "${patch[shadow_offset_y]:-}" ]]; then
        shadow+=("offset = { $(jq -r '.shadow_offset_x' <<<"$state"), $(jq -r '.shadow_offset_y' <<<"$state") }")
    fi

    # 0.57-only keys are ignored on older compositors (no unknown options).
    if supports_057; then
        if [[ -n "${patch[blur_variant]:-}" ]]; then
            blur+=("variant = \"$(clamp_value blur_variant "${patch[blur_variant]}")\"")
        fi
        if [[ -n "${patch[blur_proportional]:-}" ]]; then
            blur+=("proportional = $(lua_bool "$(clamp_value blur_proportional "${patch[blur_proportional]}")")")
        fi
        if [[ -n "${patch[wobble_enabled]:-}" ]]; then
            wobble+=("enabled = $(lua_bool "$(clamp_value wobble_enabled "${patch[wobble_enabled]}")")")
        fi
        if [[ -n "${patch[wobble_intensity]:-}" ]]; then
            wobble+=("intensity = $(clamp_value wobble_intensity "${patch[wobble_intensity]}")")
        fi
    fi

    local top=()
    [[ ${#general[@]} -gt 0 ]] && top+=("general = { $(join "${general[@]}") }")
    [[ ${#blur[@]}    -gt 0 ]] && dec+=("blur = { $(join "${blur[@]}") }")
    [[ ${#shadow[@]}  -gt 0 ]] && dec+=("shadow = { $(join "${shadow[@]}") }")
    # Same `decoration` table: a second top-level decoration key would win in
    # Lua and drop the blur/shadow members.
    [[ ${#wobble[@]}  -gt 0 ]] && dec+=("wobble = { $(join "${wobble[@]}") }")
    [[ ${#dec[@]}     -gt 0 ]] && top+=("decoration = { $(join "${dec[@]}") }")
    [[ ${#top[@]} -eq 0 ]] && return 0

    hyprctl eval "hl.config({ $(join "${top[@]}") })" >/dev/null 2>&1
}

# Merge the given key=values into the JSON state and print the new state.
# 0.57-only keys are dropped on <= 0.56 so the state (and the generated Lua)
# never carries options the running compositor does not know.
update_state() {
    [[ $# -eq 0 ]] && { cat "$STATE" 2>/dev/null || echo '{}'; return 0; }
    [[ -f "$STATE" ]] || seed_state
    local state pair k v
    state="$(cat "$STATE")"
    for pair in "$@"; do
        [[ "$pair" == *=* ]] || continue
        k="${pair%%=*}"
        if is_057_key "$k" && ! supports_057; then
            continue
        fi
        v="$(clamp_value "$k" "${pair#*=}")"
        if [[ "$k" == "blur_variant" ]]; then
            state="$(jq -c --arg k "$k" --arg v "$v" '.[$k] = $v' <<<"$state")" || return 1
        else
            state="$(jq -c --arg k "$k" --argjson v "$v" '.[$k] = $v' <<<"$state")" || return 1
        fi
    done
    printf '%s\n' "$state"
}

save_state() {
    local tmp
    tmp="$(mktemp "$CONF_DIR/.we-state.XXXXXX")" || return 1
    printf '%s\n' "$1" > "$tmp" && mv "$tmp" "$STATE"
}

cmd_preview() {
    [[ $# -eq 0 ]] && return 0
    local state
    state="$(update_state "$@")" || return 1
    save_state "$state" || return 1
    [[ "${HYPR_NO_EVAL:-0}" == "1" ]] || apply_live "$@"
    printf 'hypr-effects: previewed %s\n' "$*"
}

cmd_persist() {
    [[ -f "$STATE" ]] || seed_state
    write_lua "$(cat "$STATE")" || return 1
    # The two Lua writes can race Hyprland's auto-reload (it may read one file
    # before the other lands): re-apply the full state after writing so the
    # live values always match the JSON, whatever the reload read.
    if [[ "${HYPR_NO_EVAL:-0}" != "1" ]]; then
        local args=()
        while IFS= read -r kv; do args+=("$kv"); done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$STATE")
        apply_live "${args[@]}"
    fi
    printf 'hypr-effects: persisted\n'
}

cmd_apply() {
    cmd_preview "$@" || return 1
    cmd_persist
}

case "${1:-}" in
    read)    cmd_read ;;
    preview) shift; cmd_preview "$@" ;;
    persist) cmd_persist ;;
    apply)   shift; cmd_apply "$@" ;;
    *)       echo "usage: hypr-effects.sh read | preview KEY=VAL ... | persist | apply KEY=VAL ..." >&2; exit 1 ;;
esac
