# Claude Usage

A tiny macOS menu bar app that shows your Claude plan usage (5-hour session and weekly limits) without having to open the Claude app.

The menu bar shows two mini bars (5-hour session on top, weekly below), optionally with percentages, or plain text `✳︎ <session>% · <weekly>%` — switch in the panel. Click for per-limit bars and reset times. Refreshes every 2 minutes.

## Setup

1. Install Claude Code and log in with your Claude subscription account:
   ```bash
   npm install -g @anthropic-ai/claude-code
   claude   # then /login
   ```
2. Build and install:
   ```bash
   ./build.sh install
   ```
   Requires macOS 13+ and the Xcode Command Line Tools.

## How it works

- Reads the Claude Code OAuth token from the `Claude Code-credentials` keychain item (via `/usr/bin/security`, so no keychain prompts).
- Calls the undocumented `https://api.anthropic.com/api/oauth/usage` endpoint — this may change without notice.
- If the token has expired it refreshes it and writes the rotated token back to the keychain so Claude Code stays logged in.
