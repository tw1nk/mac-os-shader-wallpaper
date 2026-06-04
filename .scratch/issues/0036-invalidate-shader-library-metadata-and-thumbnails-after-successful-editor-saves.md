# SCRATCH-0036: Invalidate Shader Library metadata and thumbnails after successful editor saves

Status: open
Type: AFK

## What to build

Refresh Shader Library metadata and thumbnail cache entries after successful editor saves without exposing invalid in-progress package state.

## Acceptance criteria

- [ ] Successful manifest edits update displayed name/description/metadata.
- [ ] Invalid saves keep the last valid library metadata.
- [ ] Successful source changes invalidate generated thumbnail for that effect.
- [ ] Preview image changes invalidate only that effect thumbnail.
- [ ] If id changes, library treats it as old effect removed and new effect added.

## Blocked by

- SCRATCH-0030
