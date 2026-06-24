#!/usr/bin/env bash

export CCRADAR_DEFAULT_WORKING_TTL=1800

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

get_claude_panes() {
    local pane_info claude_ttys
    pane_info=$(tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null) || pane_info=""
    claude_ttys=$(ps -eo tty,comm,args 2>/dev/null | awk '
        $1 == "?" || $1 == "??" { next }
        $2 == "claude" { print $1; next }
        $2 == "node" && /claude-code/ { print $1 }
    ' | sort -u) || claude_ttys=""

    [ -z "$claude_ttys" ] && return

    while read -r pane_id pane_tty; do
        grep -qFx "${pane_tty#/dev/}" <<< "$claude_ttys" && echo "$pane_id"
    done <<< "$pane_info" || true
}

file_mtime() {
    if stat --version >/dev/null 2>&1; then
        stat -c %Y "$1" 2>/dev/null
    else
        stat -f %m "$1" 2>/dev/null
    fi
}

# Effective state for a pane, downgrading a stale "working" to "idle".
# A "working" status whose file has not been touched within ttl seconds is
# treated as idle: hooks that die (broken config, killed session) never fire
# the Stop event that would otherwise reset it. ttl of 0 disables the check.
# "waiting" is never downgraded — it is the persistent needs-attention signal.
effective_state() {
    local status_file="$1" ttl="$2" now="$3"
    local state mtime

    [ -f "$status_file" ] || { echo "idle"; return; }
    state=$(<"$status_file") || { echo "idle"; return; }
    [ -n "$state" ] || { echo "idle"; return; }

    if [ "$state" = "working" ] && [ "$ttl" -gt 0 ]; then
        mtime=$(file_mtime "$status_file")
        if [ -n "$mtime" ] && [ "$((now - mtime))" -gt "$ttl" ]; then
            echo "idle"
            return
        fi
    fi

    echo "$state"
}
