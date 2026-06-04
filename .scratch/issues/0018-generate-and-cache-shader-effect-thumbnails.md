# SCRATCH-0018: Generate and cache Shader Effect thumbnails

Status: closed
Type: AFK

## What to build

Generate static thumbnails lazily for Shader Effects that do not provide a valid preview image, and cache them under the Shader Wallpaper caches directory.

## Acceptance criteria

- [x] Thumbnails are generated lazily as cards appear.
- [x] Cards show a placeholder when generation fails.
- [x] Generated thumbnails use PNG.
- [x] Thumbnail size uses a 320px-wide baseline and the current display aspect ratio.
- [x] Multi-display aspect ratio uses the current main screen, with 16:9 fallback.
- [x] Cache location is `~/Library/Caches/Shader Wallpaper/Shader Thumbnails/`.
- [x] Cache keys include package ID, package version, shader interface version, display aspect ratio/pixel size, and relevant package content identity.
- [x] Diagnostics changes alone do not invalidate thumbnails.

## Blocked by

- SCRATCH-0017
