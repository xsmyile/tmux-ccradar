#!/usr/bin/env bash

# Claude Code hook — writes working/idle/waiting status per tmux pane.
#
# Wire this into ~/.claude/settings.json (see README).
# Called as: hook.sh <event_name>
#   Events: UserPromptSubmit, PreToolUse, Stop, Notification

set -euo pipefail

STATUS_DIR="$HOME/.cache/tmux-claude-status"
if [ ! -d "$STATUS_DIR" ]; then
    mkdir -p "$STATUS_DIR"
    chmod 700 "$STATUS_DIR"
fi

write_status() {
    local file="$STATUS_DIR/${PANE_ID}.status"
    local tmp="${file}.$$"
    printf '%s\n' "$1" > "$tmp" 2>/dev/null && mv -f "$tmp" "$file" 2>/dev/null
    return 0
}

# Skip if not inside tmux
[ -z "${TMUX:-}" ] && { cat > /dev/null; exit 0; }

PANE_ID=$(tmux display-message -p '#{pane_id}' 2>/dev/null) || { cat > /dev/null; exit 0; }
[ -z "$PANE_ID" ] && { cat > /dev/null; exit 0; }

case "${1:-}" in
    PreToolUse)
        cat > /dev/null
        write_status "working"
        exit 0
        ;;
    UserPromptSubmit)
        cat > /dev/null
        write_status "working"
        ;;
    Stop)
        cat > /dev/null
        write_status "idle"
        ;;
    Notification)
        input=$(cat)
        ntype=$(jq -r '.notification_type // empty' <<< "$input" 2>/dev/null) ||
            ntype=$(grep -o '"notification_type" *: *"[^"]*"' <<< "$input" | head -1 | cut -d'"' -f4)
        case "$ntype" in
            permission_prompt)
                write_status "waiting"
                ;;
            idle_prompt)
                write_status "idle"
                ;;
        esac
        ;;
    *)
        cat > /dev/null
        ;;
esac

tmux refresh-client -S 2>/dev/null || true

exit 0
