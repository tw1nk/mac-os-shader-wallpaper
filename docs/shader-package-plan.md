# Shader Package Implementation Plan

This plan implements Shader Packages in vertical slices while keeping the package specification in `docs/shader-packages.md` author-facing.

## Slice 1: package discovery and validation

Goal: establish the package model without renderer/UI changes.

Scope:

- add Yams for YAML parsing
- add an Xcode unit test target
- define manifest/package/diagnostic types
- scan bundled and installed package roots
- parse `shader.yaml` / `shader.yml`
- validate required fields, IDs, SemVer package versions, versions, resources, artifact choice, path safety, symlink rules, size warnings, and manifest warnings
- implement deterministic duplicate-ID handling
- add `ShaderWallpaper/Schemas/shader-manifest.schema.json`
- test validation behavior using fixtures

Out of scope:

- renderer integration
- source compilation
- package import UI
- diagnostics window

## Slice 2: package-backed built-in shader selection

Goal: remove hardcoded shader menu entries while preserving existing built-in rendering behavior.

Scope:

- reorganize built-in shader sources into package-shaped source directories
- add manifests for existing built-in effects
- use final manifest shape; no temporary manifest-only fields
- generate/copy bundled package resources into `Resources/Shaders/<id>/`
- ship built-in packages with compiled `.metallib` artifacts
- replace `ShaderType` menu population with registry effects
- persist selected shader by package `id`
- keep current resources behavior for `mouse` and `desktopTexture`
- add internal, non-selectable Error Shader fallback

Built-in package IDs:

```text
com.github.xxidbr9.wallshader.balatro
com.github.xxidbr9.wallshader.multi-box
com.github.xxidbr9.wallshader.tiles
com.github.xxidbr9.wallshader.pillars
com.github.xxidbr9.wallshader.marbles
com.github.xxidbr9.wallshader.black-hole
com.github.xxidbr9.wallshader.shiny-color
com.github.xxidbr9.wallshader.heavenly
com.github.tw1nk.wallshader.apple-logo
com.github.tw1nk.wallshader.mouse-ripple
com.github.tw1nk.wallshader.desktop-warp
```

## Slice 3: external source packages and assets

Goal: allow installed folder packages with Metal source and package-local textures to render.

Scope:

- add public `ShaderWallpaper.h` compatibility header
- migrate built-in shader signatures to `ShaderWallpaperUniforms` and `ShaderWallpaperVertexOut`
- static preflight validation for source includes
- runtime Metal source compilation with fast math
- source compiler diagnostics in package diagnostics
- reflection/name binding for `desktopTexture` and package textures
- reject unsupported buffers, writable textures, sampler arguments, and unbound required texture args
- load package-local image textures with `MTKTextureLoader`
- keep package textures resident only while effect is active

## Slice 4: import and diagnostics UI

Goal: make package management usable without manual filesystem work.

Scope:

- SwiftUI diagnostics screen hosted in AppKit
- show menu entry only when warnings/errors exist
- group diagnostics by built-in vs installed package source
- reveal installed package in Finder from diagnostics
- add `Open Shader Packages Folder`
- add `Reload Shader Packages`
- add `Import .wallshader or Folder…`
- add ZIPFoundation
- extract `.wallshader` archives safely into staging
- validate and install atomically into Application Support
- copy imported folders rather than using them in-place
- prompt for installed-package replacement using SemVer comparison
- reject imports whose ID matches a bundled package

## Slice 5: Finder open-with support

Goal: allow double-click installation of `.wallshader` archives.

Scope:

- register `.wallshader` document type
- handle app open-file events
- reuse slice 4 importer and replacement flow

## Out of v1 scope

- automatic package folder file watching
- uninstall UI
- localized manifest fields
- package-owned non-image assets
- texture arrays/cube maps
- package-controlled FPS/performance hints
- external security-scoped asset references
- persistent runtime-compiled `.metallib` cache guarantees
