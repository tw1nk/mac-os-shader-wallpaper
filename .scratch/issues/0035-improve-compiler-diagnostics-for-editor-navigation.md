# SCRATCH-0035: Improve compiler diagnostics for editor navigation

Status: closed
Type: AFK

## What to build

Return and display structured Metal compiler diagnostics so authors can jump from editor diagnostics to source lines when possible.

## Acceptance criteria

- [x] Compiler output is parsed into file, line, column, severity, and message when possible.
- [x] Raw compiler output is shown when parsing fails.
- [x] Diagnostics display line/column information in the editor panel.
- [x] Selecting a matching diagnostic navigates to the source location.
- [x] Header prepending/#line behavior preserves package source locations where possible.

## Blocked by

- SCRATCH-0029
- SCRATCH-0030
