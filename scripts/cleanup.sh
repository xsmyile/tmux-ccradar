#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

STATUS_DIR="$HOME/.cache/tmux-claude-status"
[ -d "$STATUS_DIR" ] || exit 0

claude_panes=$(get_claude_panes)
[ -z "$claude_panes" ] && exit 0

for f in "$STATUS_DIR"/*.status; do
    [ -f "$f" ] || continue
    pane_id=$(basename "$f" .status)
    grep -qFx "$pane_id" <<< "$claude_panes" || rm -f "$f"
done
