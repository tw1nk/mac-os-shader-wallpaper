# SCRATCH-0026: Open one Shader Editor Window per package

Status: open
Type: AFK

## What to build

Add a Shader Editor Window shell and controller registry keyed by package URL so editable packages can be opened without duplicate windows.

## Acceptance criteria

- [ ] Clicking Edit opens a Shader Editor Window for the package.
- [ ] Opening the same package again focuses the existing window.
- [ ] Different packages can be open in separate windows.
- [ ] The controller remains attached to package URL even if the manifest id changes later.
- [ ] If the package is deleted externally, the window reports that the package no longer exists and disables editing actions.

## Blocked by

- SCRATCH-0024
