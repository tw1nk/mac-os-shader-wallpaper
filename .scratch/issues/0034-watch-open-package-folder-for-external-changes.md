# SCRATCH-0034: Watch open package folder for external changes

Status: open
Type: AFK

## What to build

While an editor is open, watch its package folder and reconcile external changes with editor buffers and preview reloads.

## Acceptance criteria

- [ ] Package folder is watched only while the editor window is open.
- [ ] Events are debounced before reload work.
- [ ] Clean buffers reload from disk and run validation/hot reload.
- [ ] Dirty buffers prompt with Reload from Disk or Keep My Changes behavior.
- [ ] External declared asset changes refresh preview/cache without in-app asset editing.

## Blocked by

- SCRATCH-0030
