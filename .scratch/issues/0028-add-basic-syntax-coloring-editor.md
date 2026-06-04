# SCRATCH-0028: Add basic syntax coloring editor

Status: open
Type: AFK

## What to build

Replace plain text editing with a wrapped AppKit text view that provides basic debounced syntax coloring for manifest and source editing.

## Acceptance criteria

- [ ] Editor uses monospaced NSTextView-based editing.
- [ ] Metal highlighting covers comments, strings, numbers, keywords/types, and attributes.
- [ ] YAML highlighting covers keys, strings, numbers, booleans, and comments.
- [ ] Highlighting is debounced and does not pollute undo or disturb selection.
- [ ] Undo/redo and indentation behavior remain usable.

## Blocked by

- SCRATCH-0027
