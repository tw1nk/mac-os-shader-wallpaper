# SCRATCH-0026: Open one Shader Editor Window per package

Status: closed
Type: AFK

## What to build

Add a Shader Editor Window shell and controller registry keyed by package URL so editable packages can be opened without duplicate windows.

## Acceptance criteria

- [x] Clicking Edit opens a Shader Editor Window for the package.
- [x] Opening the same package again focuses the existing window.
- [x] Different packages can be open in separate windows.
- [x] The controller remains attached to package URL even if the manifest id changes later.
- [x] If the package is deleted externally, the window reports that the package no longer exists and disables editing actions.

## Blocked by

- SCRATCH-0024
