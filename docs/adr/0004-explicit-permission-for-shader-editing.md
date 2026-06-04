# Require explicit manifest permission for in-app shader editing

Shader Packages must explicitly declare `editable: true` before Shader Wallpaper offers in-app editing, even when the package is installed, folder-based, and source-backed. This favors package author intent and possible license restrictions over the convenience of treating all visible source as editable; bundled packages and compiled-library packages remain non-editable regardless of the manifest value.
