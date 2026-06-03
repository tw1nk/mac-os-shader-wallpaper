# Shader Package Issue Breakdown

These issue bodies are ready to copy into the project tracker. They are ordered by dependency.

## 1. Add Shader Manifest parsing and schema

## What to build

Add the first version of the Shader Manifest model so Shader Packages can describe one Shader Effect in YAML. The app should parse manifest documents into typed Swift values and provide a JSON Schema for authoring support.

## Acceptance criteria

- [ ] The app can decode `shader.yaml`/`shader.yml` manifest content using Yams.
- [ ] The manifest model includes `manifestVersion`, `shaderInterfaceVersion`, `id`, `name`, `version`, `fragmentFunction`, `resources`, exactly one shader artifact field, optional metadata, optional texture assets, and optional bundled-only `menuOrder`.
- [ ] `manifestVersion` and `shaderInterfaceVersion` are positive integers.
- [ ] `version` is represented as a SemVer value suitable for comparison.
- [ ] Unknown manifest fields can be detected and reported as warnings without blocking parsing.
- [ ] `ShaderWallpaper/Schemas/shader-manifest.schema.json` describes manifest v1 and can be used by YAML language servers.
- [ ] `docs/shader-packages.md` remains consistent with the implemented schema.

## Blocked by

None - can start immediately

---

## 2. Validate Shader Package candidates

## What to build

Validate discovered Shader Package folders so the app can distinguish selectable packages from invalid candidates and collect Package Diagnostics.

## Acceptance criteria

- [ ] A package candidate accepts exactly one manifest file: preferred `shader.yaml`, accepted `shader.yml`, invalid if both exist.
- [ ] Required manifest fields are validated and missing/invalid fields produce error diagnostics.
- [ ] Package IDs are reverse-DNS-style lowercase IDs with letters, numbers, dots, and hyphens, at least two dot-separated parts.
- [ ] Package `version` is required and SemVer-valid.
- [ ] Exactly one of `source` or `library` is required.
- [ ] All manifest file paths are relative, package-local, non-symlinked, exist at discovery time, and cannot escape the package.
- [ ] Packages containing symlinks anywhere are invalid.
- [ ] Unknown resource names produce warnings but do not invalidate the package.
- [ ] `resources` is required, including `resources: []` for shaders with no optional app resources.
- [ ] Installed packages with `menuOrder` warn and ignore it.
- [ ] Unknown fields inside known structures warn but do not invalidate the package.

## Blocked by

- Issue 1: Add Shader Manifest parsing and schema

---

## 3. Resolve Shader Package registry and duplicates

## What to build

Build a registry that scans bundled and installed Shader Package roots, validates candidates, resolves duplicate stable IDs deterministically, and exposes selectable Shader Effects plus Package Diagnostics.

## Acceptance criteria

- [ ] Discovery scans only immediate child directories of the bundled and installed Shader Package roots.
- [ ] Discovery order is bundled packages sorted by path, then installed packages sorted by path.
- [ ] The first valid package for a duplicated ID wins and remains selectable.
- [ ] The winning duplicate receives a warning diagnostic.
- [ ] Later duplicate packages are invalid/non-selectable and receive diagnostics.
- [ ] Duplicate installed packages never override bundled packages.
- [ ] Diagnostics are attached to package candidates and include machine-readable codes.
- [ ] Diagnostics identify package ID when known, otherwise package source and folder display name.

## Blocked by

- Issue 2: Validate Shader Package candidates

---

## 4. Add package validation unit tests

## What to build

Add focused unit tests for Shader Manifest parsing, package validation, and registry duplicate behavior.

## Acceptance criteria

- [ ] The Xcode project has a unit test target for pure Swift package/manifest logic.
- [ ] Tests cover valid source manifests and valid library manifests.
- [ ] Tests cover missing required fields, invalid IDs, invalid SemVer, and source/library conflicts.
- [ ] Tests cover unsafe paths, path traversal, absolute paths, and symlinks.
- [ ] Tests cover unknown resources and unknown fields as warnings.
- [ ] Tests cover installed `menuOrder` warning behavior.
- [ ] Tests cover duplicate ID winner/loser diagnostics and deterministic ordering.
- [ ] Tests do not require a Metal device.

## Blocked by

- Issue 1: Add Shader Manifest parsing and schema
- Issue 2: Validate Shader Package candidates
- Issue 3: Resolve Shader Package registry and duplicates

---

## 5. Migrate built-in shaders to package-shaped manifests

## What to build

Move existing built-in Shader Effects into package-shaped source directories and bundle them as Shader Packages using the final manifest shape.

## Acceptance criteria

- [ ] Existing built-in effects each have a Shader Package manifest with one stable package ID.
- [ ] Built-in package IDs are:
  - `com.github.xxidbr9.wallshader.balatro`
  - `com.github.xxidbr9.wallshader.multi-box`
  - `com.github.xxidbr9.wallshader.tiles`
  - `com.github.xxidbr9.wallshader.pillars`
  - `com.github.xxidbr9.wallshader.marbles`
  - `com.github.xxidbr9.wallshader.black-hole`
  - `com.github.xxidbr9.wallshader.shiny-color`
  - `com.github.xxidbr9.wallshader.heavenly`
  - `com.github.tw1nk.wallshader.apple-logo`
  - `com.github.tw1nk.wallshader.mouse-ripple`
  - `com.github.tw1nk.wallshader.desktop-warp`
- [ ] Built-in manifests use final v1 fields and no temporary manifest-only fields.
- [ ] Bundled package resources are generated/copied into `Resources/Shaders/<id>/` at build time.
- [ ] Built-in packages ship with compiled `.metallib` artifacts.
- [ ] The source tree mirrors the package-shaped built-in model.

## Blocked by

- Issue 3: Resolve Shader Package registry and duplicates

---

## 6. Replace hardcoded shader menu with registry-backed selection

## What to build

Replace the hardcoded Shader Type menu with menu entries generated from the Shader Package registry while preserving current built-in shader selection behavior.

## Acceptance criteria

- [ ] The shader picker is populated from valid registry Shader Effects, not hardcoded enum cases.
- [ ] Menu entries are grouped into Built-in and Installed sections.
- [ ] Bundled packages sort by `menuOrder` when present, then `name`, then `id`.
- [ ] Installed packages ignore `menuOrder` with a warning and sort by `name`, then `id`.
- [ ] Selectable effects with warnings show a subtle warning indicator.
- [ ] Persisted selection stores package ID, not display name.
- [ ] First launch with no persisted selection chooses the first valid Shader Effect.
- [ ] Reload action can refresh the registry, even if detailed reload behavior is completed later.

## Blocked by

- Issue 5: Migrate built-in shaders to package-shaped manifests

---

## 7. Load compiled package libraries and add Error Shader fallback

## What to build

Load compiled `.metallib` Shader Packages through the renderer and add the internal Error Shader fallback for cases where a selected effect cannot render.

## Acceptance criteria

- [ ] A compiled package can load its declared `.metallib` on selection.
- [ ] The app always uses its own built-in vertex function.
- [ ] The app finds the manifest `fragmentFunction` in the package library.
- [ ] The app builds the render pipeline only after all required load steps succeed.
- [ ] Failed selection keeps the previous shader active and checked.
- [ ] Failed selection records diagnostics and does not persist the failed shader as current.
- [ ] If a persisted selection exists but cannot render at launch, the app shows Error Shader and records diagnostics.
- [ ] If the selected shader disappears on reload, the app shows Error Shader instead of silently switching to another effect.
- [ ] Error Shader is internal, non-selectable, and not persisted.

## Blocked by

- Issue 5: Migrate built-in shaders to package-shaped manifests
- Issue 6: Replace hardcoded shader menu with registry-backed selection

---

## 8. Introduce Shader Interface v1 header

## What to build

Define and use the public Shader Interface v1 header for Shader Packages, including stable public type names and top-left coordinate semantics.

## Acceptance criteria

- [ ] The app provides a public `ShaderWallpaper.h` compatibility header for source packages.
- [ ] `ShaderWallpaper.h` includes `<metal_stdlib>` but does not use `using namespace metal;`.
- [ ] Public types are named `ShaderWallpaperUniforms` and `ShaderWallpaperVertexOut`.
- [ ] The v1 uniform layout remains `time`, `resolution`, `mouse`.
- [ ] `texCoord` uses normalized top-left origin coordinates.
- [ ] `mouse.xy` uses drawable pixel coordinates with top-left origin.
- [ ] `mouse.zw` are reserved and zero.
- [ ] Existing built-in shader signatures are migrated to the prefixed public types.
- [ ] Packages are not allowed to contain a file named `ShaderWallpaper.h`.

## Blocked by

- Issue 7: Load compiled package libraries and add Error Shader fallback

---

## 9. Support source Shader Packages

## What to build

Allow installed source Shader Packages to compile lazily at selection time using runtime Metal compilation and validated includes.

## Acceptance criteria

- [ ] Source packages compile lazily on selection with runtime Metal compilation.
- [ ] Metal compile options enable fast math.
- [ ] Source include preflight allows only `<metal_stdlib>`, `"ShaderWallpaper.h"`, and quoted relative package-local `.metal`, `.h`, or `.metalh` includes.
- [ ] Include preflight rejects other angle includes, absolute includes, `..`, symlinked include files, and includes resolving outside the package.
- [ ] Include validation recurses through package-local support files.
- [ ] Raw Metal compiler errors are captured as diagnostics for source packages.
- [ ] Failed source compile keeps previous shader active or shows Error Shader according to launch/reload context.
- [ ] Runtime-compiled source caching does not promise persistent `.metallib` artifacts.

## Blocked by

- Issue 8: Introduce Shader Interface v1 header

---

## 10. Support package texture assets

## What to build

Load package-local image texture assets and bind them to shader texture arguments by name using reflection.

## Acceptance criteria

- [ ] `assets.textures` declares v1 2D image texture assets.
- [ ] Texture asset names are unique, case-sensitive, identifier-like, and must not collide with reserved app resource names.
- [ ] Texture paths are package-local, relative, non-symlinked, and validated at discovery.
- [ ] Texture image decoding happens on selection with `MTKTextureLoader`.
- [ ] Texture assets are bound by shader argument name using reflection.
- [ ] `desktopTexture` is also name-bound by reflection and may use any texture index.
- [ ] Reflected texture args must be known app resources or declared package assets.
- [ ] Declared but unused texture assets produce warnings, not errors.
- [ ] Failed texture load causes selection failure.
- [ ] Package textures are retained only while the effect is active.
- [ ] Unsupported v1 arguments such as extra buffers, writable textures, external sampler arguments, texture arrays, and cube maps fail selection.

## Blocked by

- Issue 9: Support source Shader Packages

---

## 11. Add Shader Package diagnostics screen

## What to build

Create a dedicated diagnostics screen for package validation and shader loading/compilation warnings and errors.

## Acceptance criteria

- [ ] Diagnostics screen is implemented as SwiftUI hosted from the AppKit menu app.
- [ ] Diagnostics menu item appears only when active warnings/errors exist.
- [ ] Screen groups diagnostics by Built-in and Installed package source.
- [ ] User-facing screen shows only warnings/errors, not successful operations.
- [ ] Installed package diagnostics can reveal the package in Finder.
- [ ] Bundled package diagnostics do not expose path actions.
- [ ] Full installed paths are not shown inline by default.
- [ ] Raw Metal compiler errors are available in expandable details for source packages.
- [ ] Diagnostics are recalculated each launch; load/compile diagnostics are session-local.

## Blocked by

- Issue 6: Replace hardcoded shader menu with registry-backed selection
- Issue 7: Load compiled package libraries and add Error Shader fallback
- Issue 9: Support source Shader Packages
- Issue 10: Support package texture assets

---

## 12. Add manual package management menu actions

## What to build

Add user-facing menu actions for opening the installed Shader Packages folder, reloading packages, and preserving active shader behavior during reload.

## Acceptance criteria

- [ ] Menu includes `Open Shader Packages Folder`.
- [ ] Menu includes `Reload Shader Packages`.
- [ ] Opening the folder creates the installed package root if needed.
- [ ] Reload rescans packages and updates menu contents.
- [ ] If the active package changed on disk, the app tries to reload it by stable ID.
- [ ] If active reload fails, the existing compiled pipeline remains alive when possible and diagnostics are recorded.
- [ ] If the selected package no longer exists, the app shows Error Shader.
- [ ] No automatic file watching is added in v1.

## Blocked by

- Issue 6: Replace hardcoded shader menu with registry-backed selection
- Issue 11: Add Shader Package diagnostics screen

---

## 13. Import `.wallshader` archives and package folders

## What to build

Allow users to import `.wallshader` archives and package folders into Application Support using safe extraction/copying, validation, and replacement confirmation.

## Acceptance criteria

- [ ] The app adds ZIPFoundation for `.wallshader` archive extraction.
- [ ] `.wallshader` is treated as a ZIP archive with a custom extension.
- [ ] Import accepts both `.wallshader` archives and folders.
- [ ] Archives may contain package files at root or exactly one top-level folder.
- [ ] Archives with multiple manifests are rejected.
- [ ] Zip-slip, absolute paths, `..` traversal, symlinks, and unsafe permissions are rejected/normalized before install.
- [ ] Import enforces v1 size limits: 25 MB archive, 75 MB extracted package, 25 MB individual file.
- [ ] Imported packages are staged, validated, and installed atomically.
- [ ] Installed folder name is normalized to manifest `id`.
- [ ] Imported folders are copied into Application Support, not used in-place.
- [ ] Unknown extra ordinary files are preserved.
- [ ] Import rejects package IDs that match bundled packages.
- [ ] Import confirms replacement for existing installed package IDs and compares SemVer versions.
- [ ] Same/older incoming versions are called out; higher incoming versions do not need a warning.
- [ ] Successful import reloads Shader Packages automatically.

## Blocked by

- Issue 11: Add Shader Package diagnostics screen
- Issue 12: Add manual package management menu actions

---

## 14. Register Finder open-with for `.wallshader`

## What to build

Register `.wallshader` as a document type for Shader Wallpaper and route Finder double-click/open-with events through the package importer.

## Acceptance criteria

- [ ] The app declares `.wallshader` as an openable document/archive type.
- [ ] Finder double-click or Open With sends the archive to Shader Wallpaper.
- [ ] Open-file handling reuses the same importer and replacement behavior as menu import.
- [ ] Import success/failure is surfaced through existing diagnostics/confirmation UI.
- [ ] Existing menu import behavior remains unchanged.

## Blocked by

- Issue 13: Import `.wallshader` archives and package folders
