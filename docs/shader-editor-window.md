# Shader Editor Window

## Goal

Add a Shader Editor Window for authoring installed source-backed Shader Packages with explicit author permission, with save-triggered Shader Hot Reload into an editor preview and, when safe, the active wallpaper.

## Domain decisions

- A Shader Editor Window edits one folder-based Shader Package.
- Only installed, source-backed packages with `editable: true` are editable.
- Bundled packages are not editable.
- Compiled-library packages are not editable.
- Packages without explicit `editable: true` are not editable.
- The edit affordance is not shown for non-editable Shader Effects.
- `editable` is an author permission/intent field, not a capability override.
- Removing `editable: true` while editing is allowed; after save the editor becomes read-only or asks the user to close.

See ADR 0004 for the explicit permission decision.

## Manifest

Add optional manifest field:

```yaml
editable: true
```

Rules:

- Boolean only.
- Omitted means editing is not permitted.
- `editable: true` permits in-app editing only when the package is also installed, folder-based, and source-backed.
- Bundled packages and compiled-library packages remain non-editable regardless of this field.
- No warnings are emitted for `editable` being ineffective on bundled or compiled-library packages.
- `.wallshader` archives preserve the field exactly; importing an archive does not add it.
- New packages created by the app include `editable: true`.

## Entry points

- Shader Library Window detail pane shows Edit only for editable Shader Effects.
- Status menu includes `New Shader Package…`.
- Opening the same package twice focuses the existing Shader Editor Window.
- Multiple different packages may be open in separate editor windows.

## New Shader Package flow

`New Shader Package…` prompts for name and stable reverse-DNS id.

Before creating files:

- name must be non-empty
- id must pass manifest id validation
- destination folder derived from id must not exist
- no discovered package may already use the id

Creation behavior:

- create through a staging folder, then move into the installed packages root
- generate `shader.yaml` with schema comment, `editable: true`, SemVer `0.1.0`, no optional resources, and a source path under `shaders/`
- generate a minimal animated gradient Metal source using only `time` and `resolution`
- refresh the Shader Library
- open the new package in the Shader Editor Window
- do not automatically set it as the active wallpaper

## Editable files in v1

The editor edits:

- the Shader Manifest (`shader.yaml` or `shader.yml`)
- the declared Metal source file

The editor may view/open package assets externally but does not edit asset contents in v1:

- declared texture assets
- preview image

The editor is not a general package file-tree IDE in v1. Source file moves/renames happen by editing the manifest `source` field. Missing safe package-local `.metal` source paths may offer `Create Source File`.

## Save and hot reload

Shader Hot Reload happens on explicit save only.

- `⌘S` and a Save button save both dirty manifest and source buffers as one authoring transaction.
- No autosave in v1.
- Dirty state is shown in the window title.
- Closing with unsaved changes prompts the user.
- Writes should be atomic where possible.
- If any write fails, hot reload does not run.
- Malformed manifest blocks package hot reload, even if source was saved.

Successful save flow:

1. Save dirty files.
2. Validate package.
3. Compile/reload editor preview.
4. Refresh Shader Library metadata and invalidate relevant thumbnail cache entries.
5. If the active wallpaper is using the same unchanged Shader Effect id, reload active wallpaper only after editor preview succeeds.

Failure behavior:

- Editor preview keeps rendering its last good version.
- Active wallpaper keeps rendering its last good version.
- Diagnostics appear in the editor diagnostics panel.
- The Error Shader or empty preview is used only when there is no last good editor preview.
- Active wallpaper should not switch to Error Shader due to transient authoring mistakes.

If the manifest `id` changes:

- treat it as a new Shader Effect identity
- keep the editor attached to the same package folder
- do not automatically follow the old active selection to the new id
- show a message that the id changed and the user must Set Active again

If `source` changes:

- validation checks that the new path is safe, package-local, and exists
- editor loads the new file after save when valid
- if the old source buffer has unsaved changes, prompt before continuing
- if the new source path is missing but safe/package-local `.metal`, offer `Create Source File`

## External changes

File watching is active only while the Shader Editor Window is open.

- Watch the open package folder using FSEvents/directory watching.
- Debounce events by roughly 300–500ms.
- Compare known manifest/source/assets mtimes or hashes to decide what changed.
- If there are no unsaved editor changes, reload buffers from disk and run validation/hot reload.
- If there are unsaved editor changes, prompt with `Reload from Disk`, `Keep My Changes`, or cancel-equivalent behavior.
- External asset changes refresh preview/cache but asset contents are not edited in-app.
- No background hot reload when no editor window is open; users can still use Reload Shader Packages.

## Preview and activation

The editor has a live preview that shares the same shader loading/rendering core as the active wallpaper and Shader Library preview.

Allowed preview differences:

- viewport size/aspect ratio
- editor-only diagnostics or overlays
- selection is not persisted unless Set Active is clicked

Resource behavior:

- `time` and `resolution` are provided normally
- `mouse` tracks pointer position inside the preview when declared
- `desktopTexture` uses the same behavior as existing wallpaper/preview rendering
- no advanced resource simulation controls in v1

The editor includes `Set Active`:

- disabled when package has no successful valid compiled version
- if dirty changes exist, prompt: `Save and Set Active`, `Set Active Last Saved Version`, or `Cancel`
- if save fails, do not activate unless the user explicitly chooses last saved version

## Diagnostics

The Shader Editor Window has its own authoring diagnostics panel.

Editor diagnostics include:

- manifest parse/validation errors
- source compile errors
- package asset reload failures
- save/write failures
- external-change conflicts

Global Package Diagnostics remain for app-wide discovery/loading state. Transient authoring failures should not noisily accumulate in global diagnostics unless they reflect the current discovered package state after save.

Metal compiler diagnostics should be parsed into file/line/column/severity/message when possible. Raw compiler output should be shown if parsing fails. Diagnostics should navigate to source lines when file references match the open manifest/source.

## Text editing

Use AppKit `NSTextView` wrapped for SwiftUI, not SwiftUI `TextEditor` and no external editor dependency in v1.

Required v1 editor features:

- monospaced text
- explicit save
- undo/redo
- dirty tracking
- preserve indentation
- syntax coloring for Metal and YAML
- basic line/column diagnostic navigation where feasible

Syntax highlighting:

- regex-based, not parser/LSP-based
- Metal: comments, strings, numbers, keywords/types, attributes such as `[[buffer(0)]]`
- YAML: keys, strings, numbers, booleans, comments
- debounce highlighting by roughly 100–200ms
- scan on a string copy off-main where useful
- apply attributes on main without polluting undo or changing selection

Out of scope for v1:

- autocomplete
- symbol navigation
- rename/refactor
- semantic highlighting
- LSP integration
- automatic package version bumping

## Rendering implementation direction

Introduce a small shared shader loading core rather than continuing to duplicate loading behavior.

Suggested responsibility:

- compile source or load `.metallib`
- find fragment function
- create render pipeline
- perform reflection/resource binding validation
- return structured diagnostics/errors

Callers:

- active wallpaper renderer
- Shader Library live preview
- Shader Editor preview
- thumbnail generation where practical

Last-good compiled/render state should live per render surface/session, not globally.

- Active wallpaper has its own last-good state.
- Each editor preview has its own last-good state.
- Shader Library preview has its own last-good state.
- Thumbnail generation does not need last-good state.

## Window ownership

- Add `ShaderEditorWindowController`.
- Keep an app/window-controller registry keyed by package URL, not Shader Effect id.
- Key by package URL because `id` can change while editing.
- If package is deleted externally, the editor shows that the package no longer exists and disables save/hot reload.
- No editor window restoration across app launches in v1; frame autosave is acceptable.

## Tests to add

- `ShaderManifest` decodes optional boolean `editable`.
- Omitted `editable` means not editable.
- Effective editability requires installed + source + `editable == true`.
- Bundled packages are non-editable even with `editable: true`.
- Library packages are non-editable even with `editable: true`.
- Invalid/non-boolean `editable` behavior is locked down.
- New package creation validates id/name and refuses collisions.
- New package creation generates expected manifest/source.
- Save with malformed manifest keeps last-good preview and does not reload active wallpaper.
- Source compile failure keeps last-good preview and active wallpaper.
- Manifest id change is treated as new effect identity.
- Thumbnail cache invalidates after successful source/preview change.
- External change conflict behavior for dirty and clean buffers.
