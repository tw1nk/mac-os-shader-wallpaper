# SCRATCH-0033: Add Set Active from Shader Editor Window

Status: closed
Type: AFK

## What to build

Allow users to activate the edited Shader Effect from the Shader Editor Window without bypassing dirty-state or validation safeguards.

## Acceptance criteria

- [x] Set Active is disabled when there is no successful valid compiled version.
- [x] With no dirty changes, Set Active activates the last successful version.
- [x] With dirty changes, user can Save and Set Active, Set Active Last Saved Version, or Cancel.
- [x] If save fails, activation does not proceed unless the user explicitly chose last saved version.

## Blocked by

- SCRATCH-0030
- SCRATCH-0032
