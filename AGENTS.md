# AI Coding Agents Integration in Boring Notch

Boring Notch includes full real-time Dynamic Island integration for AI coding agents (**Claude Code**, **Codex**, **Gemini CLI**, **Cursor**, **OpenCode**, and others), inspired by Vibe Island.

## Features

- **Live Session Tracking**: Monitor running AI agents right from the MacBook notch. See project names, git branches, status (Working, Needs Approval, Question, Idle, Done), and current active tool calls (e.g. `Bash: npm test` or `Editing ContentView.swift`).
- **Interactive Question Answering (`AskUserQuestion`)**: When Claude Code asks an interactive question, question cards appear directly in the Notch with selectable option buttons. Clicking an option immediately submits the answer back to Claude Code without switching to the terminal! Custom answers can also be typed and sent directly.
- **One-Click Tool Approvals (`PermissionRequest`)**: Approve (`Allow`) or reject (`Deny`) terminal commands (Bash) and file edits (Write/Edit) with a single click.
- **Closed Notch Live Activity**: While the notch is closed, the notch wings show a pulsing agent status and active tool call. If an approval or question is needed, the notch chin expands into a prominent notification banner.
- **Terminal Jump-Back**: Click the "Focus Terminal" button on any session card to instantly bring the corresponding terminal window (Ghostty, iTerm2, Terminal.app, Warp, VS Code, Cursor, Zed) to the front.
- **Zero-Config Setup**: One-click installation and verification of hooks in `~/.claude/settings.json`.

---

## Architecture

### 1. IPC Bridge (`~/.boring-notch/bin/boring-notch-bridge`)
The bridge is a lightweight Unix domain socket client (`~/.boring-notch/run/boring-notch.sock` and `/tmp/boring-notch.sock`). When a CLI agent fires a lifecycle hook:
1. The hook command runs `boring-notch-bridge [source]`.
2. The payload is read from `stdin` and forwarded over the Unix domain socket.
3. For non-blocking events (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `SessionEnd`), the bridge exits immediately (exit code 0).
4. For blocking events (`PermissionRequest` / `AskUserQuestion`), the bridge keeps the socket connection open and awaits the decision JSON from Boring Notch, then prints it to `stdout` and exits 0.

### 2. Socket Server (`AgentServer.swift`)
Runs inside Boring Notch on a background queue using non-blocking POSIX sockets (`AF_UNIX`). Listens on `~/.boring-notch/run/boring-notch.sock`.

### 3. Session Manager (`AgentManager.swift`)
Maintains session state, tracks active tools and prompts, handles approval and question workflows, and plays sounds/triggers notch expansions.

### 4. Claude Code Protocol Compatibility
- **Tool Approvals**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}
```
- **Tool Denials**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "deny",
      "reason": "Declined from Boring Notch"
    }
  }
}
```
- **Interactive Question Answers (`AskUserQuestion`)**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": {
        "answers": {
          "<question_header>": "<selected_option_label>"
        }
      }
    }
  }
}
```

---

## Setup & Testing

1. In Boring Notch, open **Settings** (`Cmd + ,`) → **AI Agents**.
2. Click **Install Claude Code Hooks** (or hooks install automatically if Claude Code is detected).
3. Click **Test Question** in Settings to test the interactive question card in the notch.
4. Run `claude` in your terminal — all sessions and permissions will seamlessly stream to Boring Notch!
