# SCRATCH-0020: Set active shader from Shader Library Window

Status: open
Type: AFK

## What to build

Let users activate the selected Shader Effect from the Shader Library detail pane without closing the window, and keep active state synchronized with menu-based shader changes.

## Acceptance criteria

- [ ] Detail pane has a `Set Active` button for the selected Shader Effect.
- [ ] Clicking cards does not activate; only `Set Active` activates.
- [ ] After Set Active succeeds, the window remains open.
- [ ] Active card/detail pane show an Active badge/state.
- [ ] Active state updates when the user changes shader from the existing menu while the Shader Library Window is open.
- [ ] Set Active is disabled when preview/load fails.
- [ ] Failed activation records diagnostics and keeps previous active wallpaper shader.

## Blocked by

- SCRATCH-0019
