# SCRATCH-0029: Introduce shared Shader Effect loading core

Status: closed
Type: AFK

## What to build

Extract shader compile/load/pipeline/resource-binding behavior into a shared core used by wallpaper rendering and previews.

## Acceptance criteria

- [x] Shared loader handles source compilation and metallib loading.
- [x] Shared loader finds the fragment function and creates the render pipeline.
- [x] Shared loader performs reflection/resource binding validation and returns structured failures.
- [x] Active wallpaper and Shader Library live preview still render correctly through the shared path.
- [x] Existing package diagnostics behavior is preserved.

## Blocked by

- None - can start immediately
