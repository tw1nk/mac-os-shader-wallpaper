# SCRATCH-0036: Invalidate Shader Library metadata and thumbnails after successful editor saves

Status: closed
Type: AFK

## What to build

Refresh Shader Library metadata and thumbnail cache entries after successful editor saves without exposing invalid in-progress package state.

## Acceptance criteria

- [x] Successful manifest edits update displayed name/description/metadata.
- [x] Invalid saves keep the last valid library metadata.
- [x] Successful source changes invalidate generated thumbnail for that effect.
- [x] Preview image changes invalidate only that effect thumbnail.
- [x] If id changes, library treats it as old effect removed and new effect added.

## Blocked by

- SCRATCH-0030
