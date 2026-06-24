#!/usr/bin/env bash

# Idempotently wires ccradar's hook.sh into Claude Code's settings.json.
#
# Merges a "command" hook for each tracked event into ~/.claude/settings.json
# without disturbing any other settings. Re-running is safe: existing ccradar
# entries (current or legacy "tmux-claude-status" paths) are replaced in place,
# unrelated hooks are preserved, and an unchanged file is left untouched.
#
# Usage: scripts/install-hooks.sh
# Override target with CCRADAR_SETTINGS_FILE (e.g. for testing).

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SETTINGS_FILE="${CCRADAR_SETTINGS_FILE:-$HOME/.claude/settings.json}"
HOOK_COMMAND="$CURRENT_DIR/hook.sh"
LEGACY_PATTERN='(tmux-ccradar|tmux-claude-status)/scripts/hook\.sh'
EVENTS=(UserPromptSubmit PreToolUse Stop Notification)

if ! command -v jq >/dev/null 2>&1; then
    echo "ccradar install-hooks: 'jq' is required to safely edit JSON settings but was not found." >&2
    echo "Install jq (e.g. 'brew install jq') and re-run." >&2
    exit 1
fi

mkdir -p "$(dirname "$SETTINGS_FILE")"

if [ -e "$SETTINGS_FILE" ]; then
    if ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo "ccradar install-hooks: '$SETTINGS_FILE' is not valid JSON; refusing to overwrite." >&2
        echo "Fix or remove the file, then re-run." >&2
        exit 1
    fi
    current="$(cat "$SETTINGS_FILE")"
else
    current='{}'
fi

events_json="$(printf '%s\n' "${EVENTS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"

updated="$(
    jq \
        --arg base "$HOOK_COMMAND" \
        --arg pat "$LEGACY_PATTERN" \
        --argjson events "$events_json" '
        .hooks = (.hooks // {})
        | reduce $events[] as $ev (.;
            .hooks[$ev] = (
                (.hooks[$ev] // [])
                | map(select(any(.hooks[]?; (.command // "") | test($pat)) | not))
                + [{ "hooks": [{ "type": "command", "command": ($base + " " + $ev) }] }]
            )
        )
    ' <<<"$current"
)"

if [ "$(jq -S . <<<"$current")" = "$(jq -S . <<<"$updated")" ]; then
    echo "ccradar install-hooks: hooks already up to date in $SETTINGS_FILE"
    exit 0
fi

cp -p "$SETTINGS_FILE" "$SETTINGS_FILE.bak" 2>/dev/null || true

tmp="$SETTINGS_FILE.tmp.$$"
printf '%s\n' "$updated" >"$tmp"
mv -f "$tmp" "$SETTINGS_FILE"

echo "ccradar install-hooks: wired ${#EVENTS[@]} hooks into $SETTINGS_FILE"
[ -e "$SETTINGS_FILE.bak" ] && echo "ccradar install-hooks: previous settings backed up to $SETTINGS_FILE.bak"
echo "Restart Claude Code sessions for the hooks to take effect."
