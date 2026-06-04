# SCRATCH-0032: Handle manifest identity and source-path changes in the editor

Status: closed
Type: AFK

## What to build

Implement the agreed editor behavior for manifest id changes, source path changes, missing source files, and revoking edit permission.

## Acceptance criteria

- [x] Changing id is treated as a new Shader Effect identity and shows a Set Active again message.
- [x] Changing source path loads the new source after valid save.
- [x] Dirty old source changes prompt before continuing with a source-path switch.
- [x] Safe missing package-local `.metal` paths offer Create Source File.
- [x] Removing `editable: true` can be saved, then the editor becomes read-only or asks the user to close.

## Blocked by

- SCRATCH-0030
