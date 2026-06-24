#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

STATUS_DIR="$HOME/.cache/tmux-claude-status"

GREEN='\033[32m'
YELLOW='\033[33m'
ORANGE='\033[38;5;208m'
DIM='\033[2m'
RESET='\033[0m'

hooks_ok=""
raw=$(tmux show-environment -g TMUX_CLAUDE_STATUS_HOOKS_OK 2>/dev/null) && hooks_ok="${raw#*=}"

working_out=""
waiting_out=""
idle_out=""
working_count=0
waiting_count=0
idle_count=0

claude_panes=$(get_claude_panes)

while read -r pane_id; do
    [ -n "$pane_id" ] || continue
    status_file="$STATUS_DIR/${pane_id}.status"

    if [ -f "$status_file" ]; then
        status=$(<"$status_file") || status="idle"
    else
        status="idle"
    fi
    [ -n "$status" ] || status="idle"

    label=$(tmux display-message -t "$pane_id" -p '#{session_name}:#{window_index}' 2>/dev/null) || label="$pane_id"
    [ -n "$label" ] || label="$pane_id"

    label_width=13
    if [ "${#label}" -gt "$label_width" ]; then
        label="${label:0:$((label_width - 1))}~"
    fi

    pane_path=$(tmux display-message -t "$pane_id" -p '#{pane_current_path}' 2>/dev/null) || pane_path="?"
    path="${pane_path/#$HOME/\~}"

    max_path=25
    if [ "${#path}" -gt "$max_path" ]; then
        trim=$((${#path} - max_path + 2))
        path="..${path:$trim}"
    fi

    line=$(printf "%-${label_width}s %-${max_path}s %7s" "$label" "$path" "$status")

    case "$status" in
        working)
            working_out="${working_out}  ${GREEN}●${RESET} ${line}\n"
            working_count=$((working_count + 1))
            ;;
        waiting)
            waiting_out="${waiting_out}  ${ORANGE}◉${RESET} ${line}\n"
            waiting_count=$((waiting_count + 1))
            ;;
        *)
            idle_out="${idle_out}  ${YELLOW}○${RESET} ${line}\n"
            idle_count=$((idle_count + 1))
            ;;
    esac
done <<< "$claude_panes"

total=$((working_count + waiting_count + idle_count))

echo ""
if [ "$total" -eq 0 ]; then
    printf "  No active Claude sessions\n"
else
    [ -n "$working_out" ] && printf '%b' "$working_out"
    [ -n "$waiting_out" ] && printf '%b' "$waiting_out"
    [ -n "$idle_out" ] && printf '%b' "$idle_out"
    echo ""
    summary="  $total sessions:"
    sep=""
    [ "$working_count" -gt 0 ] && summary="$summary $working_count working" && sep=" · "
    [ "$waiting_count" -gt 0 ] && summary="${summary}${sep}$waiting_count waiting" && sep=" · "
    [ "$idle_count" -gt 0 ] && summary="${summary}${sep}$idle_count idle"
    printf '  %b%s%b\n' "$DIM" "$summary" "$RESET"
fi

if [ "$hooks_ok" != "1" ] && [ "$total" -gt 0 ]; then
    echo ""
    printf '  %b⚠ Hooks not configured — status may be inaccurate%b\n' "$ORANGE" "$RESET"
    printf '  %bSee: github.com/xsmyile/tmux-claude-status#setup%b\n' "$DIM" "$RESET"
fi

echo ""
printf '  %bPress q or Esc to close%b\n' "$DIM" "$RESET"
read -rsn1
