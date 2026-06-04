# Shader Packages

Shader Packages let Shader Wallpaper discover built-in and installed shader effects without hardcoded menu entries.

## Package shapes

A Shader Package contributes exactly one selectable Shader Effect.

Canonical installed/bundled shape:

```text
<package-folder>/
  shader.yaml
  shaders/effect.metal        # source package
  # or
  effect.metallib             # compiled package
  textures/noise.png          # optional package asset
```

`shader.yml` is accepted, but `shader.yaml` is preferred. A package with both names is invalid.

Built-in packages live under:

```text
ShaderWallpaper.app/Contents/Resources/Shaders/
```

Installed packages live under:

```text
~/Library/Application Support/Shader Wallpaper/Shaders/
```

Discovery scans only immediate child directories of those roots.

## Installable archives

A `.wallshader` file is a ZIP archive with a custom extension. It is an install/import artifact, not the canonical runtime shape.

Archives may contain either files at the archive root:

```text
shader.yaml
shaders/effect.metal
```

or exactly one top-level folder:

```text
Aurora/
  shader.yaml
  shaders/effect.metal
```

Importer rules:

- find exactly one `shader.yaml`/`shader.yml`, either at root or one level below root
- reject archives with multiple manifests
- reject zip-slip traversal, absolute paths, `..` traversal, and symlinks
- normalize permissions on install
- install atomically through a staging directory
- copy into Application Support using the manifest `id` as the folder name
- preserve unknown extra files that are ordinary package-local files

Size limits for import v1:

- archive max: 25 MB
- extracted package max: 75 MB
- individual file max: 25 MB

## Manifest v1

Example:

```yaml
# yaml-language-server: $schema=https://example.com/shader-manifest.schema.json
manifestVersion: 1
shaderInterfaceVersion: 1
id: com.example.wallshader.aurora-ripple
name: Aurora Ripple
version: 1.0.0
description: Swirling aurora effect with subtle noise texture.
author: Jane Doe
homepage: https://example.com/aurora
license: MIT
fragmentFunction: auroraShader
source: shaders/aurora.metal
# or: library: aurora.metallib
resources:
  - mouse
  - desktopTexture
assets:
  textures:
    - name: noiseTexture
      path: textures/noise.png
preview:
  image: preview.png
menuOrder: 10 # bundled packages only; ignored with warning for installed packages
```

Required fields:

- `manifestVersion`: positive integer manifest format version
- `shaderInterfaceVersion`: positive integer Shader Interface version
- `id`: stable reverse-DNS-style lowercase ID; letters, numbers, dots, hyphens; at least two dot-separated parts
- `name`: display name
- `version`: required SemVer package content version
- `fragmentFunction`: Metal fragment function name
- exactly one of `source` or `library`
- `resources`: required list, empty when no optional app resources are needed

Optional fields:

- `description`
- `author`
- `homepage`
- `license`
- `assets.textures`
- `preview.image`
- `menuOrder` for bundled packages only

Unknown fields warn but do not invalidate the package.

## Versions and compatibility

`manifestVersion` describes the manifest format. `shaderInterfaceVersion` describes the public shader contract. `version` is the author-controlled package content version.

Compatibility rules:

- newer `manifestVersion`: invalid; requires newer app
- older `manifestVersion`: convert in memory if supported, otherwise invalid
- newer `shaderInterfaceVersion`: invalid; requires newer shader interface
- older `shaderInterfaceVersion`: valid only if the app still ships that interface header
- manifest conversion does not rewrite package files automatically

## Resources

`resources` declares app-provided dynamic inputs. Known v1 resources:

- `mouse`
- `desktopTexture`

Unknown resources produce warnings but do not block discovery or selection. Unknown resource names do not create bindings; if shader reflection finds required unbound arguments, selection fails.

`time` and `resolution` are always available through uniforms and are not declared as resources. `mouse` is declared even though it is part of the uniform buffer; if not declared, mouse data is zero.

## Package assets

`assets.textures` declares package-local image textures:

```yaml
assets:
  textures:
    - name: noiseTexture
      path: textures/noise.png
```

Rules:

- v1 supports 2D image textures only
- `name` is case-sensitive and must match the shader texture argument name
- names must be unique and identifier-like: start with a letter or `_`, then letters, numbers, or `_`
- names must not use reserved app-provided resource names such as `desktopTexture`
- paths must be relative, package-local, non-symlinked, and must exist
- texture decoding happens on shader selection
- if a declared texture fails to load, selection fails
- unused declared textures warn, but do not block selection
- package textures are loaded while the shader is active and released when switching away

Texture files are loaded with `MTKTextureLoader` using standard macOS-supported image formats. See Apple's `MTKTextureLoader` documentation for supported behavior: https://developer.apple.com/documentation/metalkit/mtktextureloader

Texture options in v1:

- sRGB loading is not configurable; use the app default
- mipmaps are not generated by default
- shader code controls samplers, not the manifest

## Preview images

A package may provide a package-local preview image:

```yaml
preview:
  image: preview.png
```

Rules:

- `preview.image` is optional in manifest v1
- the path must be relative, package-local, non-symlinked, and must exist
- if the preview image is absent or invalid, the app may generate a thumbnail from the shader effect

## Shader Interface v1

Source packages include the public compatibility header:

```metal
#include <metal_stdlib>
#include "ShaderWallpaper.h"
using namespace metal;

fragment float4 auroraShader(
    ShaderWallpaperVertexOut in [[stage_in]],
    constant ShaderWallpaperUniforms& u [[buffer(0)]],
    texture2d<float> noiseTexture [[texture(1)]],
    texture2d<float> desktopTexture [[texture(2)]]
) {
    return float4(1.0);
}
```

`ShaderWallpaper.h` is the only app-provided include in interface v1. Packages may not contain a file named `ShaderWallpaper.h`.

Public types:

```metal
struct ShaderWallpaperUniforms {
    float time;
    float2 resolution;
    float4 mouse;
};

struct ShaderWallpaperVertexOut {
    float4 position [[position]];
    float2 texCoord;
};
```

Coordinate rules:

- `resolution`: drawable size in pixels
- `texCoord`: normalized UV with `(0,0)` at top-left
- `mouse.xy`: drawable pixel coordinates with `(0,0)` at top-left
- `mouse.zw`: reserved and zero in interface v1
- `time`: app uptime in seconds; it does not reset when switching shaders

Shader package limits in v1:

- packages provide one fragment function only
- the app always provides the vertex function
- uniforms are fixed at `[[buffer(0)]]`; uniform argument name is irrelevant
- additional buffer arguments are unsupported
- writable textures and external sampler arguments are unsupported
- package texture arguments should be `texture2d<float>`
- `desktopTexture` is name-bound by reflection and may use any texture index
- package texture assets are name-bound by reflection and may use any texture index

## Source packages

Source packages are compiled lazily when selected using runtime Metal compilation. The app uses fast math for consistency with built-in shaders. Successful source compilation is not promised to produce persistent `.metallib` cache files; cache behavior is app-private.

Allowed includes:

- `#include <metal_stdlib>`
- `#include "ShaderWallpaper.h"`
- quoted relative package-local includes ending in `.metal`, `.h`, or `.metalh`

Rejected includes:

- other angle-bracket includes
- absolute quoted includes
- quoted includes with `..`
- includes resolving outside the package
- symlinked include files

Include validation is a static preflight step before Metal compilation and recurses through package-local support files.

## Compiled packages

Compiled packages declare a `.metallib` file:

```yaml
library: aurora.metallib
```

The library may contain helpers and extra functions, but the app only uses `fragmentFunction`. The app always loads `vertexShader` from its own built-in library.

`.metallib` loadability and device compatibility are checked on selection, not discovery.

## Discovery, sorting, and duplicates

Discovery collects all package candidates, validates them, and produces diagnostics. Valid packages appear in the menu; invalid packages do not.

Discovery order:

1. bundled package directory, sorted by path
2. installed package directory, sorted by path

Duplicate IDs:

- the first package in deterministic discovery order wins and remains selectable
- the winner receives a warning that duplicates were ignored
- later duplicates are invalid/non-selectable and receive diagnostics including their source
- duplicates never override bundled packages

Menu layout:

```text
Select Shader
  Built-in
    Balatro
    Desktop Warp
  Installed
    Aurora Ripple
```

Sorting:

- bundled packages may use `menuOrder`
- installed packages with `menuOrder` warn and ignore it
- otherwise sort by `name`, then `id`

Selectable packages with warnings may show a subtle warning indicator in the menu.

## Selection and reload behavior

On first launch with no persisted selection, the app selects the first valid shader effect. Persisted selection uses package `id`, not display name.

On selection:

1. load or compile the package library
2. load the app vertex function
3. find `fragmentFunction`
4. reflect and validate resources/assets
5. load package textures
6. build the pipeline
7. switch current shader only after success

If selection fails, the previous shader stays active and checked, and diagnostics are recorded.

If a persisted selection exists but cannot render at launch, the app shows the internal Error Shader and records diagnostics rather than silently switching effects. If the selected shader disappears during reload, the app also shows Error Shader.

Error Shader rules:

- internal only
- not a Shader Package
- not selectable
- not persisted
- visually obvious error state

Reload behavior:

- scan packages at app launch
- provide `Reload Shader Packages`
- automatically reload after successful import
- if the active package changed on disk, try to reload by stable ID
- if reload fails, keep the existing compiled pipeline alive when possible and record diagnostics
- if the selected package no longer exists, show Error Shader

No automatic file watching in v1.

## Diagnostics

Diagnostics are warnings or errors:

- warning: package/effect may still be selectable
- error: package/effect is not selectable or selection failed

Diagnostics should have machine-readable codes for tests and docs, such as:

- `unknownResource`
- `duplicateIdWinner`
- `duplicateIdIgnored`
- `invalidManifestYaml`
- `missingRequiredField`
- `unsafePath`
- `sourceLibraryConflict`
- `compileFailed`

User-facing diagnostics:

- only warnings/errors, not successful operations
- recalculated each launch; load/compile diagnostics are session-local
- shown in one dedicated diagnostics screen, accessible from the menu only when diagnostics exist
- grouped by built-in vs installed package source
- installed package diagnostics include `Reveal in Finder`
- bundled diagnostics do not expose path actions
- raw Metal compiler errors appear in expandable details for source packages

## Menu actions

Recommended menu actions:

```text
Open Shader Packages Folder
Reload Shader Packages
Import .wallshader or Folder…
Shader Package Diagnostics…   # only visible when warnings/errors exist
```

Import accepts both `.wallshader` archives and folders. Folder imports are copied into Application Support and normalized to the manifest `id`; packages are not used in-place.

Replacement rules:

- importing an ID that matches a bundled package is rejected up front
- importing an ID that matches an installed package asks for confirmation
- compare existing vs incoming SemVer
- no warning is needed when incoming version is higher
- same/older versions should be called out in the confirmation

Uninstall UI is out of v1 scope; users can manually delete installed package folders and reload.

## Authoring docs and schema

The manifest schema should live at:

```text
ShaderWallpaper/Schemas/shader-manifest.schema.json
```

The schema is JSON Schema and can be associated with YAML editors via an optional comment:

```yaml
# yaml-language-server: $schema=https://example.com/shader-manifest.schema.json
```

The comment is recommended for authoring but not required.
