# SCRATCH-0029: Introduce shared Shader Effect loading core

Status: open
Type: AFK

## What to build

Extract shader compile/load/pipeline/resource-binding behavior into a shared core used by wallpaper rendering and previews.

## Acceptance criteria

- [ ] Shared loader handles source compilation and metallib loading.
- [ ] Shared loader finds the fragment function and creates the render pipeline.
- [ ] Shared loader performs reflection/resource binding validation and returns structured failures.
- [ ] Active wallpaper and Shader Library live preview still render correctly through the shared path.
- [ ] Existing package diagnostics behavior is preserved.

## Blocked by

- None - can start immediately
