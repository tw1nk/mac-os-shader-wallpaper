# SCRATCH-0027: Edit manifest and source buffers with explicit save

Status: closed
Type: AFK

## What to build

Let the Shader Editor Window load the manifest and declared source file, track dirty state, and save both buffers explicitly as one authoring transaction.

## Acceptance criteria

- [x] The editor loads shader.yaml/shader.yml and the declared Metal source.
- [x] Editing either buffer marks the window dirty.
- [x] Save button and ⌘S save all dirty buffers together.
- [x] Writes are atomic where possible.
- [x] Closing with unsaved changes prompts the user.
- [x] If any write fails, no reload is attempted and an editor diagnostic is shown.

## Blocked by

- SCRATCH-0026
