# SCRATCH-0024: Show Edit entry point only for editable Shader Effects

Status: closed
Type: AFK

## What to build

Expose the Shader Editor Window entry point from the Shader Library Window detail pane only when the selected Shader Effect is editable.

## Acceptance criteria

- [x] Editable installed source-backed effects show an Edit action in the detail pane.
- [x] Non-editable effects show no Edit affordance or disabled placeholder.
- [x] Changing the selected effect updates Edit visibility correctly.
- [x] The UI uses Shader Editor Window terminology.

## Blocked by

- SCRATCH-0023
