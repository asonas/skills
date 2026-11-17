---
name: herdr-agent-launch
description: Launch an already-authorized agent in the current Herdr workspace, using the current tab's pane count. Works under the legacy herdr TUI and under Herdr.app (herdr-core).
---

# Herdr Agent Launch

Use this skill only to place and launch an agent whose startup is already authorized by the user or an explicitly invoked skill. This skill grants no authorization to start additional agents.

## Choose the host

- If `HERDR_ENV` is `1`, follow "Legacy herdr".
- Otherwise, if `HC_TERMINAL_ID` is set and `command -v herdr-app` succeeds, follow "Herdr.app".
- If `HC_TERMINAL_ID` is set but `herdr-app` is unavailable (for example on a remote machine reached through herdr-core), stop and report that the window cannot be arranged from this machine.
- Otherwise, use the ordinary current terminal.

## Legacy herdr

- Identify the current workspace and tab, and count that tab's panes before creating anything. Use the current workspace; never create a new workspace.
- With exactly one pane, run `herdr pane split --current --direction right --no-focus` and use the returned new pane ID.
- With two or more panes, run `herdr tab create --workspace <current-workspace-id>` and use the returned root pane ID in the new tab.
- After obtaining the pane ID from the operation result, run `herdr pane run <pane-id> "<authorized-agent-command>"`.

## Herdr.app

Read `herdr-app --skill` and `hc --skill` before acting; they are the current manuals for this host.

- Run `herdr-app ls` and find the entry whose `terminal` equals `$HC_TERMINAL_ID`. Its space and tab are the current ones, and its `pane` is this pane. Never act on the focused pane instead.
- Count the terminals in that tab before creating anything. Use the current space; never create a new space.
- With exactly one terminal, run `herdr-app do pane.split --direction right --pane <this-pane> --argv '<json-argv>'`.
- With two or more terminals, run `herdr-app do tab.new --space <current-space-id> --folder <working-folder> --argv '<json-argv>'`. Add `--name` when the task has a clear name.
- `pane.split` has no folder argument. When the folder matters, make the argv change into it, for example `["sh","-c","cd \"$1\" && exec claude","sh","/path/to/repo"]`.
- Start Codex with `--no-daemon`. herdr-core requires it so that Codex's commands stay inside hc.
- A reply containing a `terminal` ID means only that the terminal was created, not that the agent started. Confirm with `hc get <terminal>` or `hc read <terminal>` before reporting success. Use `herdr-app commands` to confirm argument shapes.

## Stop conditions

Confirm the target pane and startup result before reporting success. Do not repeat startup when its result is uncertain.

Stop if authorization, the current workspace or tab, pane count, or returned pane ID is missing or uncertain, or if creation or startup fails. Zero panes is undefined: stop. Do not compensate by creating a workspace or space, switching to another one, or launching a duplicate agent.
