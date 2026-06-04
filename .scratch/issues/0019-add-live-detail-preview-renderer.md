# SCRATCH-0019: Add live detail preview renderer

Status: open
Type: AFK

## What to build

Add a single live Metal preview in the Shader Library detail pane for the currently selected Shader Effect. It should use a separate preview renderer instance while sharing shader loading behavior with the wallpaper renderer.

## Acceptance criteria

- [ ] Detail pane shows one live preview for the selected Shader Effect.
- [ ] Preview renderer is separate from the active wallpaper renderer.
- [ ] Preview renderer shares shader loading/rendering core with wallpaper rendering where practical.
- [ ] Preview uses package texture assets and app resources like wallpaper rendering.
- [ ] `mouse` resource uses mouse position relative to the preview view.
- [ ] `desktopTexture` uses the actual current desktop texture when available.
- [ ] Preview starts when a shader is selected and the window is visible.
- [ ] Preview pauses/stops when the window is hidden/minimized or selection changes.
- [ ] Preview aspect ratio follows the current display aspect ratio.

## Blocked by

- SCRATCH-0016
