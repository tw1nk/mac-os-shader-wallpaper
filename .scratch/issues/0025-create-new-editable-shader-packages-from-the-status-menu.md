# SCRATCH-0025: Create new editable Shader Packages from the status menu

Status: closed
Type: AFK

## What to build

Add a New Shader Package flow that creates an installed source-backed package with explicit edit permission and opens it for authoring.

## Acceptance criteria

- [x] Status menu includes New Shader Package….
- [x] The flow prompts for non-empty name and valid stable id before creating files.
- [x] Existing destination folders and discovered duplicate ids are refused.
- [x] Generated package includes shader.yaml with schema comment, `editable: true`, version `0.1.0`, resources `[]`, and a source file.
- [x] Generated Metal source renders a minimal animated gradient using only time and resolution.
- [x] The Shader Library refreshes after creation.

## Blocked by

- SCRATCH-0023
