# SCRATCH-0025: Create new editable Shader Packages from the status menu

Status: open
Type: AFK

## What to build

Add a New Shader Package flow that creates an installed source-backed package with explicit edit permission and opens it for authoring.

## Acceptance criteria

- [ ] Status menu includes New Shader Package….
- [ ] The flow prompts for non-empty name and valid stable id before creating files.
- [ ] Existing destination folders and discovered duplicate ids are refused.
- [ ] Generated package includes shader.yaml with schema comment, `editable: true`, version `0.1.0`, resources `[]`, and a source file.
- [ ] Generated Metal source renders a minimal animated gradient using only time and resolution.
- [ ] The Shader Library refreshes after creation.

## Blocked by

- SCRATCH-0023
