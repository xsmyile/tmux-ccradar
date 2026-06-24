#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

hooks_ok=""
raw=$(tmux show-environment -g TMUX_CCRADAR_HOOKS_OK 2>/dev/null) && hooks_ok="${raw#*=}"

# Count active Claude panes for exact popup height
claude_panes=$(get_claude_panes)
count=0
if [ -n "$claude_panes" ]; then
    count=$(wc -l <<< "$claude_panes" | tr -d ' ')
fi

# Content: gap(1) + sessions(N) + gap(1) + summary(1) + gap(1) + footer(1) = N + 5
# Empty: gap(1) + message(1) + gap(1) + footer(1) = 4
# +3 for popup borders
if [ "$count" -gt 0 ]; then
    height=$((count + 8))
    # Add space for hooks warning
    if [ "$hooks_ok" != "1" ]; then
        height=$((height + 3))
    fi
else
    height=7
fi

# Border style
border=""
raw=$(tmux show-environment -g TMUX_CCRADAR_POPUP_BORDER 2>/dev/null) && border="${raw#*=}"

if [ -n "$border" ]; then
    exec tmux display-popup -E -w 60 -h "$height" -b "$border" \
        -T " Claude Status " "$SCRIPT_DIR/popup.sh"
else
    exec tmux display-popup -E -w 60 -h "$height" \
        -T " Claude Status " "$SCRIPT_DIR/popup.sh"
fi
