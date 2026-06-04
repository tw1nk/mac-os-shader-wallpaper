# Shader Library Window

The Shader Library Window is the user interface for browsing the Shader Library, previewing shader effects, and choosing the active shader effect.

## Entry points

The menu should include:

```text
Open Shader Library…
Select Shader              # existing quick submenu remains
Open Shader Packages Folder
Import .wallshader or Folder…
Reload Shader Packages
Shader Package Diagnostics… # only when warnings/errors exist
```

`Open Shader Library…` opens a single modeless Shader Library Window. If the window already exists, choosing the menu item focuses it.

## Layout

The window uses a grid of Shader Effect cards with a detail pane for the selected effect.

Grid behavior:

- main grid shows selectable Shader Effects only
- invalid packages do not appear as cards
- cards show thumbnail, name, source, active badge, and warning badge when applicable
- clicking a card selects it for preview only
- clicking a card does not change the active wallpaper shader
- double-click may become a shortcut for Set Active later, but is not required in v1

Detail pane behavior:

- shows selected effect metadata
- shows a live preview of the selected effect
- includes a Set Active button
- Set Active changes the wallpaper shader but keeps the window open
- active state updates if the active shader changes from the menu while the window is open
- if preview/load fails, Set Active is disabled and the diagnostic is shown

Metadata shown in the detail pane:

- name
- author
- description
- version
- source: Built-in or Installed
- resources
- package ID
- warning/error details when applicable
- homepage/license when present

## Filtering and search

The window supports filters/tabs:

- All
- Built-in
- Installed
- Warnings

Search matches:

- display name
- package ID
- author
- description

The window should remember size/position and the last selected filter. It should not remember search text.

## Preview architecture

The grid uses static thumbnails. The detail pane uses one live preview renderer for the currently selected shader.

Preview renderer rules:

- use a separate preview renderer instance from the active wallpaper renderer
- share shader loading/rendering core with the wallpaper renderer
- do not mutate or evict active wallpaper renderer resources
- start rendering when an effect is selected and the window is visible
- pause when the window is hidden/minimized or selection changes
- use package assets and app resources like wallpaper rendering
- `mouse` uses mouse position relative to the preview view
- `desktopTexture` uses the actual current desktop texture when available

The live preview aspect ratio follows the current display aspect ratio. For multiple displays, use the display where the wallpaper window is active/main target, falling back to the screen containing the Shader Library Window. Use 16:9 only as a last-resort fallback.

## Thumbnails

Thumbnails are static in the grid. Live animation only happens in the detail pane.

Thumbnail sources:

- package-provided preview image when `preview.image` is present and valid
- app-generated thumbnail from the actual shader effect otherwise

`preview.image` rules:

- optional in manifest v1
- relative, package-local, non-symlinked path
- if invalid or missing, app-generated thumbnail is used
- if shader load fails, package-provided preview may still be shown with an error overlay and Set Active disabled

Thumbnail generation:

- lazy as cards appear
- show placeholder while loading/generating
- generated thumbnail size follows current display aspect ratio; 320px wide is the default baseline
- cache as PNG

Thumbnail cache location:

```text
~/Library/Caches/Shader Wallpaper/Shader Thumbnails/
```

Thumbnail cache keys include:

- package ID
- package version
- shader interface version
- display aspect ratio or pixel size
- package-provided preview image path and mtime, when used
- source/library file mtime or content hash, when app-generated

Diagnostics changing alone should not invalidate thumbnails unless package content relevant to rendering changed.

## Management actions

The Shader Library Window toolbar should include:

- Import…
- Reload
- Open Packages Folder
- Diagnostics, when warnings/errors exist

Menu actions remain available too.

Installed package removal is out of the first Shader Library Window slice. Users can remove packages manually via Open Packages Folder and Reload.

## Error Shader

The internal Error Shader is not part of the Shader Library and does not appear as a card. If the active renderer is showing the Error Shader, the Shader Library Window should show a banner explaining that the selected shader failed and point to diagnostics.
