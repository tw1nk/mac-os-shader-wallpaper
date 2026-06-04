# SCRATCH-0017: Load package-provided preview images

Status: closed
Type: AFK

## What to build

Use optional `preview.image` manifest assets as card thumbnails when present and valid. Invalid preview images should not make an otherwise selectable Shader Effect disappear; they should fall back to generated thumbnails later and produce diagnostics.

## Acceptance criteria

- [x] `preview.image` is loaded from a package-local, non-symlinked path validated by existing package validation.
- [x] Valid preview images appear on Shader Effect cards.
- [x] Invalid/unloadable preview images show placeholder/fallback state.
- [x] Package-provided preview images can still display independently of live shader preview state.
- [x] Built-in and installed package preview handling uses the same code path.

## Blocked by

- SCRATCH-0016
