# SCRATCH-0017: Load package-provided preview images

Status: open
Type: AFK

## What to build

Use optional `preview.image` manifest assets as card thumbnails when present and valid. Invalid preview images should not make an otherwise selectable Shader Effect disappear; they should fall back to generated thumbnails later and produce diagnostics.

## Acceptance criteria

- [ ] `preview.image` is loaded from a package-local, non-symlinked path validated by existing package validation.
- [ ] Valid preview images appear on Shader Effect cards.
- [ ] Invalid/unloadable preview images produce a warning diagnostic and show placeholder/fallback state.
- [ ] Package-provided preview images can still display when shader load fails, with an error overlay and Set Active disabled later.
- [ ] Built-in and installed package preview handling uses the same code path.

## Blocked by

- SCRATCH-0016
