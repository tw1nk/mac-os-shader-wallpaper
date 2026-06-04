# Use cached thumbnails with a single live Shader Library preview

The Shader Library Window uses static cached thumbnails in its grid and a single live preview in the detail pane for the selected shader effect. This avoids running many Metal views at once while still giving users an accurate preview before they choose Set Active; the live preview should use a separate renderer instance that shares the wallpaper shader loading core so preview behavior and active wallpaper behavior do not drift.
