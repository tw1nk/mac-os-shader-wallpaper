# SCRATCH-0022: Surface diagnostics and Error Shader state in Shader Library

Status: closed
Type: AFK

## What to build

Surface package warnings/errors and active Error Shader state in the Shader Library Window without making invalid packages selectable.

## Acceptance criteria

- [x] Main grid still shows selectable Shader Effects only.
- [x] Window shows a banner/link when invalid packages or diagnostics exist.
- [x] Cards with warnings show warning badges and remain previewable/selectable.
- [x] Detail pane shows warning/error details for the selected effect.
- [x] If the active renderer is showing Error Shader, the window shows an explanatory banner.
- [x] Error Shader never appears as a Shader Effect card.
- [x] Diagnostics link opens the diagnostics screen.

## Blocked by

- SCRATCH-0016
- SCRATCH-0019
- SCRATCH-0020
