# SCRATCH-0031: Safely hot reload active wallpaper after editor preview succeeds

Status: closed
Type: AFK

## What to build

When the edited Shader Effect is active, reload the active wallpaper only after the editor preview has successfully validated and compiled the saved package.

## Acceptance criteria

- [x] Active wallpaper reloads after successful editor preview when the effect id is unchanged and active.
- [x] Active wallpaper is not reloaded after failed validation or compile.
- [x] Active wallpaper keeps its last-good state if its own reload fails.
- [x] Changing manifest id does not automatically move active selection to the new id.

## Blocked by

- SCRATCH-0030
