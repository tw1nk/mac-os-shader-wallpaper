# SCRATCH-0019: Add live detail preview renderer

Status: closed
Type: AFK

## What to build

Add a single live Metal preview in the Shader Library detail pane for the currently selected Shader Effect. It should use a separate preview renderer instance while sharing shader loading behavior with the wallpaper renderer.

## Acceptance criteria

- [x] Detail pane shows one live preview for the selected Shader Effect.
- [x] Preview renderer is separate from the active wallpaper renderer.
- [x] Preview renderer shares shader loading/rendering core with wallpaper rendering where practical.
- [x] Preview uses package texture assets and app resources like wallpaper rendering.
- [x] `mouse` resource uses mouse position relative to the preview view.
- [x] `desktopTexture` uses the actual current desktop texture when available.
- [x] Preview starts when a shader is selected and the window is visible.
- [x] Preview pauses/stops when selection is cleared or changed.
- [x] Preview aspect ratio follows the current display aspect ratio.

## Blocked by

- SCRATCH-0016
