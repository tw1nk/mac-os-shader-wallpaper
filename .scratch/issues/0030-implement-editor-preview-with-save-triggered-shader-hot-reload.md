# SCRATCH-0030: Implement editor preview with save-triggered Shader Hot Reload

Status: open
Type: AFK

## What to build

Add a live editor preview that validates and recompiles the package after explicit save while preserving last-good rendering on failures.

## Acceptance criteria

- [ ] Successful save validates the package and updates the editor preview.
- [ ] Malformed manifest or compile failure shows editor diagnostics and keeps last-good preview.
- [ ] Initial failure with no last-good preview shows Error Shader or empty preview.
- [ ] Transient authoring failures do not accumulate noisily in global diagnostics.
- [ ] Mouse/resource behavior matches existing preview behavior.

## Blocked by

- SCRATCH-0027
- SCRATCH-0029
