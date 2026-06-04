# SCRATCH-0024: Show Edit entry point only for editable Shader Effects

Status: open
Type: AFK

## What to build

Expose the Shader Editor Window entry point from the Shader Library Window detail pane only when the selected Shader Effect is editable.

## Acceptance criteria

- [ ] Editable installed source-backed effects show an Edit action in the detail pane.
- [ ] Non-editable effects show no Edit affordance or disabled placeholder.
- [ ] Changing the selected effect updates Edit visibility correctly.
- [ ] The UI uses Shader Editor Window terminology.

## Blocked by

- SCRATCH-0023
