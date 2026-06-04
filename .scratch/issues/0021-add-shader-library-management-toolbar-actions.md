# SCRATCH-0021: Add Shader Library management toolbar actions

Status: closed
Type: AFK

## What to build

Add library management actions to the Shader Library Window toolbar while keeping existing menu actions available.

## Acceptance criteria

- [x] Toolbar includes Import… using existing `.wallshader`/folder importer.
- [x] Toolbar includes Reload using existing package reload behavior.
- [x] Toolbar includes Open Packages Folder.
- [x] Toolbar includes Diagnostics only when warnings/errors exist.
- [x] Successful import/reload updates grid, detail pane, active state, and diagnostics visibility.
- [x] Installed package removal is not added in this slice.

## Blocked by

- SCRATCH-0016
- SCRATCH-0020
