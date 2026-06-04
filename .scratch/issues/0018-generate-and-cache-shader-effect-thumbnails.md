# SCRATCH-0018: Generate and cache Shader Effect thumbnails

Status: open
Type: AFK

## What to build

Generate static thumbnails lazily for Shader Effects that do not provide a valid preview image, and cache them under the Shader Wallpaper caches directory.

## Acceptance criteria

- [ ] Thumbnails are generated lazily as cards appear.
- [ ] Cards show a placeholder while thumbnail work is pending.
- [ ] Generated thumbnails use PNG.
- [ ] Thumbnail size uses a 320px-wide baseline and the current display aspect ratio.
- [ ] Multi-display aspect ratio uses the active wallpaper display, falling back to the Shader Library Window screen, then 16:9.
- [ ] Cache location is `~/Library/Caches/Shader Wallpaper/Shader Thumbnails/`.
- [ ] Cache keys include package ID, package version, shader interface version, display aspect ratio/pixel size, and relevant package content identity.
- [ ] Diagnostics changes alone do not invalidate thumbnails.

## Blocked by

- SCRATCH-0017
