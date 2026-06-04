# SCRATCH-0016: Show Shader Effect grid with filters and search

Status: closed
Type: AFK

## What to build

Populate the Shader Library Window with a grid of selectable Shader Effect cards backed by the Shader Package registry. The grid should support source filters and search without changing the active wallpaper shader when a card is clicked.

## Acceptance criteria

- [x] Main grid shows selectable Shader Effects only.
- [x] Invalid packages do not appear as cards.
- [x] Cards show effect name, source, active badge, warning badge, and thumbnail placeholder.
- [x] Clicking a card selects it for preview/detail only and does not activate it.
- [x] Filters are available for All, Built-in, Installed, and Warnings.
- [x] Search matches display name, package ID, author, and description.
- [x] Grid ordering matches existing Shader Package menu ordering rules.

## Blocked by

- SCRATCH-0015
