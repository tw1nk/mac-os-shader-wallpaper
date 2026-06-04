# SCRATCH-0028: Add basic syntax coloring editor

Status: closed
Type: AFK

## What to build

Replace plain text editing with a wrapped AppKit text view that provides basic debounced syntax coloring for manifest and source editing.

## Acceptance criteria

- [x] Editor uses monospaced NSTextView-based editing.
- [x] Metal highlighting covers comments, strings, numbers, keywords/types, and attributes.
- [x] YAML highlighting covers keys, strings, numbers, booleans, and comments.
- [x] Highlighting is debounced and does not pollute undo or disturb selection.
- [x] Undo/redo and indentation behavior remain usable.

## Blocked by

- SCRATCH-0027
