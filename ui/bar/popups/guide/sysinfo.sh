#!/usr/bin/env bash
# System information for the About page (one KEY=VALUE per line).
. /etc/os-release 2>/dev/null

echo "os=${PRETTY_NAME:-unknown}"
echo "host=$(cat /etc/hostname 2>/dev/null || hostname)"
echo "kernel=$(uname -r)"
wm_line="$(hyprctl version 2>/dev/null | head -1 | cut -d" " -f1)"
echo "wm=${wm_line:-unknown}"
echo "shell=$(basename "${SHELL:-sh}")"
echo "user=${USER:-unknown}"
up="$(uptime -p 2>/dev/null)"
echo "uptime=${up#up }"
cpu="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "cpu=${cpu:-unknown}"
gpu="$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -1 | sed 's/.*: //')"
echo "gpu=${gpu:--}"
echo "memory=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
echo "disk=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
mon="$(hyprctl monitors -j 2>/dev/null)"
echo "res=$(echo "$mon" | jq -r '.[0] | "\(.width)x\(.height)"' 2>/dev/null || echo unknown)"
echo "refresh=$(echo "$mon" | jq -r '.[0].refreshRate | round | tostring + " Hz"' 2>/dev/null || echo unknown)"
echo "monitors=$(echo "$mon" | jq -r 'length' 2>/dev/null || echo 0)"
echo "scale=$(echo "$mon" | jq -r '.[0].scale' 2>/dev/null || echo 1)"
