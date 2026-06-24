#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CURRENT_DIR/scripts/helpers.sh"

status_command="#($CURRENT_DIR/scripts/status.sh)"

validate_color() {
    local value="$1" default="$2"
    if printf '%s' "$value" | grep -q '#('; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Cache user options in tmux environment so status.sh avoids per-poll lookups
tmux set-environment -g TMUX_CLAUDE_STATUS_COLOR_WORKING "$(validate_color "$(get_tmux_option "@claude-status-color-working" "#a6da95")" "#a6da95")"
tmux set-environment -g TMUX_CLAUDE_STATUS_COLOR_WAITING "$(validate_color "$(get_tmux_option "@claude-status-color-waiting" "#f5a97f")" "#f5a97f")"
tmux set-environment -g TMUX_CLAUDE_STATUS_COLOR_IDLE "$(validate_color "$(get_tmux_option "@claude-status-color-idle" "#eed49f")" "#eed49f")"
tmux set-environment -g TMUX_CLAUDE_STATUS_COLOR_TEXT "$(validate_color "$(get_tmux_option "@claude-status-color-text" "#cad3f5")" "#cad3f5")"
tmux set-environment -g TMUX_CLAUDE_STATUS_ICON "$(get_tmux_option "@claude-status-icon" "✳ ")"

interpolate() {
    local option="$1"
    local value
    value=$(tmux show-option -gqv "$option")
    if printf '%s' "$value" | grep -qF '#{claude_status}'; then
        local new_value="${value//\#\{claude_status\}/$status_command}"
        tmux set-option -gq "$option" "$new_value"
        return 0
    fi
    return 1
}

# Try placeholder interpolation in status-right and status-left
interpolated=0
interpolate "status-right" && interpolated=1
interpolate "status-left" && interpolated=1

# Fallback: append to status-right if no placeholder was found
if [ "$interpolated" -eq 0 ]; then
    current_status_right=$(tmux show-option -gqv status-right)
    if ! printf '%s' "$current_status_right" | grep -qF "tmux-claude-status/scripts/status.sh"; then
        tmux set-option -ag status-right " $status_command"
    fi
fi

# Clean up stale status files when sessions close
tmux set-hook -g session-closed "run-shell '$CURRENT_DIR/scripts/cleanup.sh'"

# Detect whether hooks are configured in ~/.claude/settings.json
hooks_configured=0
if [ -f "$HOME/.claude/settings.json" ]; then
    grep -qF "tmux-claude-status" "$HOME/.claude/settings.json" && hooks_configured=1
fi
tmux set-environment -g TMUX_CLAUDE_STATUS_HOOKS_OK "$hooks_configured"

# Cache popup border for popup-open.sh to read
tmux set-environment -g TMUX_CLAUDE_STATUS_POPUP_BORDER "$(get_tmux_option "@claude-status-popup-border" "")"

# Bind key to open sessions overview popup
popup_key=$(get_tmux_option "@claude-status-popup-key" "C")
tmux bind-key "$popup_key" run-shell "$CURRENT_DIR/scripts/popup-open.sh"
