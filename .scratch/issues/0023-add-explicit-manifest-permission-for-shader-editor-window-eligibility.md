# SCRATCH-0023: Add explicit manifest permission for Shader Editor Window eligibility

Status: closed
Type: AFK

## What to build

Add `editable` as an optional Shader Manifest permission field and expose effective Shader Editor Window eligibility for discovered Shader Effects.

## Acceptance criteria

- [x] ShaderManifest decodes optional boolean `editable` and the schema/docs describe it.
- [x] Omitted `editable` means editing is not permitted.
- [x] Effective editability requires installed source-backed package with `editable == true`.
- [x] Bundled packages and compiled-library packages are non-editable regardless of `editable`.
- [x] No warnings are emitted when `editable` is ineffective on bundled or compiled-library packages.
- [x] Tests cover omitted, true, false, ineffective, and invalid/non-boolean cases.

## Blocked by

- None - can start immediately
