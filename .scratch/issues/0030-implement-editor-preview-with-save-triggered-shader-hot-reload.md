# SCRATCH-0030: Implement editor preview with save-triggered Shader Hot Reload

Status: closed
Type: AFK

## What to build

Add a live editor preview that validates and recompiles the package after explicit save while preserving last-good rendering on failures.

## Acceptance criteria

- [x] Successful save validates the package and updates the editor preview.
- [x] Malformed manifest or compile failure shows editor diagnostics and keeps last-good preview.
- [x] Initial failure with no last-good preview shows Error Shader or empty preview.
- [x] Transient authoring failures do not accumulate noisily in global diagnostics.
- [x] Mouse/resource behavior matches existing preview behavior.

## Blocked by

- SCRATCH-0027
- SCRATCH-0029
