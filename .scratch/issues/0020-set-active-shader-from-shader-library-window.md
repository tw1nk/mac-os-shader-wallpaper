# SCRATCH-0020: Set active shader from Shader Library Window

Status: closed
Type: AFK

## What to build

Let users activate the selected Shader Effect from the Shader Library detail pane without closing the window, and keep active state synchronized with menu-based shader changes.

## Acceptance criteria

- [x] Detail pane has a `Set Active` button for the selected Shader Effect.
- [x] Clicking cards does not activate; only `Set Active` activates.
- [x] After Set Active succeeds, the window remains open.
- [x] Active card/detail pane show an Active badge/state.
- [x] Active state can be refreshed through shared renderer state while the Shader Library Window is open.
- [x] Set Active is disabled for the current active shader.
- [x] Failed activation records diagnostics and keeps previous active wallpaper shader.

## Blocked by

- SCRATCH-0019
