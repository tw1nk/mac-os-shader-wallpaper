# SCRATCH-0015: Add Shader Library Window shell

Status: closed
Type: AFK

## What to build

Add a single-instance modeless Shader Library Window that can be opened from the menu and focused if already open. The window should establish shared state for selected filter, selected Shader Effect, active Shader Effect ID, and window size/position persistence.

## Acceptance criteria

- [x] Menu includes `Open Shader Library…`.
- [x] Opening the menu item creates a modeless Shader Library Window.
- [x] Opening it again focuses the existing window instead of creating another one.
- [x] Window remembers size and position across launches.
- [x] Window remembers the selected filter but does not persist search text.
- [x] Window has an empty-state/skeleton layout ready for grid and detail pane slices.

## Blocked by

None - can start immediately
