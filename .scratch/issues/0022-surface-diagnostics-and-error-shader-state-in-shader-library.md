# SCRATCH-0022: Surface diagnostics and Error Shader state in Shader Library

Status: open
Type: AFK

## What to build

Surface package warnings/errors and active Error Shader state in the Shader Library Window without making invalid packages selectable.

## Acceptance criteria

- [ ] Main grid still shows selectable Shader Effects only.
- [ ] Window shows a banner/link when invalid packages or diagnostics exist.
- [ ] Cards with warnings show warning badges and remain previewable/selectable.
- [ ] Detail pane shows warning/error details for the selected effect.
- [ ] If the active renderer is showing Error Shader, the window shows an explanatory banner.
- [ ] Error Shader never appears as a Shader Effect card.
- [ ] Diagnostics link opens/focuses the existing diagnostics screen.

## Blocked by

- SCRATCH-0016
- SCRATCH-0019
- SCRATCH-0020
