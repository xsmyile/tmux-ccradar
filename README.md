# tmux-claude-status

A minimal, zero-dependency shell plugin that shows live [Claude Code](https://docs.anthropic.com/en/docs/claude-code) activity in your tmux status bar. See at a glance how many instances are working, waiting for input, or idle across all panes.

**Default**

![Default status bar](assets/default.png)

**Customized**

![Customized status bar](assets/custom.png)

## Install

Requires [TPM](https://github.com/tmux-plugins/tpm).

Add to `~/.config/tmux/tmux.conf` (or `~/.tmux.conf`):

```tmux
set -g @plugin 'xsmyile/tmux-claude-status'
```

Then press `prefix + I` to install.

## Setup

The plugin tracks Claude Code activity via [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks). Add this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/tmux/plugins/tmux-claude-status/scripts/hook.sh UserPromptSubmit"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/tmux/plugins/tmux-claude-status/scripts/hook.sh PreToolUse"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/tmux/plugins/tmux-claude-status/scripts/hook.sh Stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/tmux/plugins/tmux-claude-status/scripts/hook.sh Notification"
          }
        ]
      }
    ]
  }
}
```

## How it works

```
Claude Code hooks          Status files              tmux status bar
┌──────────────┐   write   ┌────────────────────┐   read   ┌──────────┐
│ UserPrompt   ├──────────>│ ~/.cache/           ├────────>│ 2 working│
│ PreToolUse   │           │ tmux-claude-status/ │         │ 1 waiting│
│ Stop         │           │ %42.status          │         │ 0 idle   │
│ Notification │           └────────────────────┘         └──────────┘
└──────────────┘
```

1. Claude Code fires hook events as it works
2. `hook.sh` writes `working`, `waiting`, or `idle` to a per-pane status file
3. `status.sh` counts Claude panes and their states (working/waiting/idle), renders to the status bar
4. Stale status files are cleaned up automatically when sessions close

## Status bar placement

By default the plugin appends to `status-right`. If you build your status bar manually (e.g. with catppuccin or a custom theme), use the `#{claude_status}` placeholder to control where it appears:

```tmux
set -g status-right "#{claude_status} other-stuff"
```

The plugin replaces the placeholder with the status output at load time.

## Options

All options are optional. Set them in `tmux.conf` **before** the TPM `run` line.

```tmux
# Colors (any tmux-compatible color: hex, name, or terminal color number)
set -g @claude-status-color-working "#a6da95"   # green (default)
set -g @claude-status-color-waiting "#f5a97f"   # orange (default)
set -g @claude-status-color-idle    "#eed49f"   # yellow (default)
set -g @claude-status-color-text    "#cad3f5"   # foreground (default)

# Icon shown before the status (any Unicode glyph, Nerd Font icon, emoji, or text)
set -g @claude-status-icon "✳ "   # default (plain Unicode, no Nerd Font needed)

# Key binding for the sessions overview popup (default: C)
set -g @claude-status-popup-key "C"
```

The default colors (green, orange, yellow, light grey) work with most themes and can be overridden to match yours.

### Refresh rate

The status updates every `status-interval` seconds. For responsive updates:

```tmux
set -g status-interval 2
```

## Sessions overview popup

Press `prefix + C` (configurable via `@claude-status-popup-key`) to open a popup window showing all active Claude Code sessions with their status and working directory.

```
  Claude Code Sessions
  ────────────────────────────────────────

  ● main:1       ~/dev/myapp           working
  ◉ api:0        ~/dev/api-server      waiting
  ○ work:2       ~/dev/tmux-plugin     idle

  3 sessions: 1 working · 1 waiting · 1 idle
```

## Requirements

- tmux 3.0+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- A terminal with true color support (for hex colors)

## License

MIT
