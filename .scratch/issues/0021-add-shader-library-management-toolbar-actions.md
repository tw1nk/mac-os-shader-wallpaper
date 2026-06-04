# SCRATCH-0021: Add Shader Library management toolbar actions

Status: open
Type: AFK

## What to build

Add library management actions to the Shader Library Window toolbar while keeping existing menu actions available.

## Acceptance criteria

- [ ] Toolbar includes Import… using existing `.wallshader`/folder importer.
- [ ] Toolbar includes Reload using existing package reload behavior.
- [ ] Toolbar includes Open Packages Folder.
- [ ] Toolbar includes Diagnostics only when warnings/errors exist.
- [ ] Successful import/reload updates grid, detail pane, active state, and diagnostics visibility.
- [ ] Installed package removal is not added in this slice.

## Blocked by

- SCRATCH-0016
- SCRATCH-0020
