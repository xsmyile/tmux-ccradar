#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

STATUS_DIR="$HOME/.cache/tmux-ccradar"

hooks_ok=""
raw=$(tmux show-environment -g TMUX_CCRADAR_HOOKS_OK 2>/dev/null) && hooks_ok="${raw#*=}"

color_working="" color_waiting="" color_idle="" color_text="" icon=""
raw=$(tmux show-environment -g TMUX_CCRADAR_COLOR_WORKING 2>/dev/null) && color_working="${raw#*=}"
raw=$(tmux show-environment -g TMUX_CCRADAR_COLOR_WAITING 2>/dev/null) && color_waiting="${raw#*=}"
raw=$(tmux show-environment -g TMUX_CCRADAR_COLOR_IDLE 2>/dev/null) && color_idle="${raw#*=}"
raw=$(tmux show-environment -g TMUX_CCRADAR_COLOR_TEXT 2>/dev/null) && color_text="${raw#*=}"
raw=$(tmux show-environment -g TMUX_CCRADAR_ICON 2>/dev/null) && icon="${raw#*=}"

[ -z "$color_working" ] && color_working="#a6da95"
[ -z "$color_waiting" ] && color_waiting="#f5a97f"
[ -z "$color_idle" ] && color_idle="#eed49f"
[ -z "$color_text" ] && color_text="#cad3f5"
[ -z "$icon" ] && icon="✳ "

total=0
working=0
waiting=0

claude_panes=$(get_claude_panes)

while read -r pane_id; do
    [ -n "$pane_id" ] || continue
    status_file="$STATUS_DIR/${pane_id}.status"
    [ -f "$status_file" ] || continue

    pane_status=$(<"$status_file") || continue
    total=$((total + 1))
    case "$pane_status" in
        working) working=$((working + 1)) ;;
        waiting) waiting=$((waiting + 1)) ;;
    esac
done <<< "$claude_panes"

if [ "$hooks_ok" != "1" ] && [ -n "$claude_panes" ]; then
    echo "${icon}#[fg=${color_waiting}]⚠ hooks not configured"
    exit 0
fi

idle=$((total - working - waiting))

echo "${icon}#[fg=${color_working}]●#[fg=${color_text}]${working} #[fg=${color_waiting}]◉#[fg=${color_text}]${waiting} #[fg=${color_idle}]○#[fg=${color_text}]${idle}"
