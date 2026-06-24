#!/usr/bin/env bash

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
