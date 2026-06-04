# Shader Wallpaper

Shader Wallpaper lets people run live shader-based wallpapers on macOS and extend the available effects without changing the app code.

## Language

**Shader Package**:
A collection that contributes exactly one shader effect to the app, whether bundled with the app or installed by a user. A package has a human-facing identity, declares the resources the effect needs, and may contain shader source or a compiled Metal library.
_Avoid_: External files, plugin, bundle, zip

**Shader Effect**:
A selectable visual wallpaper effect produced by a shader package. A shader effect has a stable identity used to remember it, a display name shown to people, and declared resources; no two discovered effects may share the same stable identity.
_Avoid_: Shader type, preset

**Shader Manifest**:
The author-facing description of a shader package. It names the single shader effect contributed by the package, declares what that effect needs, and distinguishes the manifest format version from the package's own version.
_Avoid_: Config file, metadata file

**Package Version**:
The author-controlled version of a shader package's content. It is separate from the shader manifest format version.
_Avoid_: Manifest version, schema version

**Installable Shader Archive**:
A packaged archive form of a shader package intended for import or Finder open-with installation. It uses the `.wallshader` extension and becomes a folder-based shader package after installation.
_Avoid_: Zip file, shaderpackage

**Package Asset**:
A non-symlinked file contained inside a shader package that the package's shader effect can use, such as an image texture or preview image. Package assets are package-local; they do not grant access to arbitrary files outside the package.
_Avoid_: External asset, arbitrary file

**Package Diagnostic**:
A warning or error produced while discovering, validating, installing, or loading a shader package. Diagnostics explain whether an effect is selectable and what package path or artifact caused the issue.
_Avoid_: Log line, failure, package error

**Error Shader**:
An internal fallback rendering state used when the app cannot render a selected shader effect. It is not a shader package, is not selectable, and is not remembered as the user's selected effect.
_Avoid_: Bundled shader, fallback package

**Shader Library**:
The user-facing collection of available shader effects. It includes built-in and installed effects that the app has discovered.
_Avoid_: Metal library, package folder

**Shader Library Window**:
The user interface for browsing the Shader Library, previewing shader effects, and choosing the active shader effect.
_Avoid_: Shader picker, select shader menu

**Shader Interface**:
The contract a shader effect follows so the app can render it. It defines the fragment function inputs the app knows how to provide.
_Avoid_: ABI, function signature, protocol

## Example dialogue

Developer: "Should adding a new Shader Effect require changing Swift code?"
Domain expert: "No. A person should install a Shader Package, then the effect appears in the selector."
Developer: "Can a Shader Package contain either source code or a compiled Metal library?"
Domain expert: "Yes. Both are Shader Packages as long as they describe one selectable Shader Effect."
Developer: "Are built-in effects different from installed effects?"
Domain expert: "No. Built-in effects are Shader Packages bundled with the app."
Developer: "Can one Shader Package add several menu entries?"
Domain expert: "No. One Shader Package contributes exactly one Shader Effect."
Developer: "If an effect is renamed, should the app forget that it was selected?"
Domain expert: "No. The effect's stable identity is separate from its display name."
Developer: "What if two packages declare the same stable identity?"
Domain expert: "That is an invalid collision. The app should report it rather than silently overriding either package."
Developer: "What if an effect declares a resource the app does not know?"
Domain expert: "The app should warn, but still allow the effect to be selected and used with the recognized resources."
Developer: "Where does a package describe its effect?"
Domain expert: "In its Shader Manifest. The manifest is the package author's description of exactly one effect."
Developer: "Can every effect ask for arbitrary inputs?"
Domain expert: "No. Every Shader Effect follows the app's Shader Interface, and its declared resources determine which optional inputs the app provides."
Developer: "Should users install raw zip files?"
Domain expert: "No. Users install an Installable Shader Archive with the `.wallshader` extension, which the app turns into a folder-based Shader Package."
Developer: "Can shader effects use their own texture files?"
Domain expert: "Yes, but only Package Assets inside their own Shader Package. They must not load arbitrary files from outside the package."
Developer: "Where should package warnings and errors live?"
Domain expert: "They are Package Diagnostics. The app should surface them in a dedicated screen when there is something to report."
Developer: "Is the error fallback one of the selectable effects?"
Domain expert: "No. The Error Shader is internal and only appears when the app cannot render a selected Shader Effect."
Developer: "Where should people browse previews and choose effects?"
Domain expert: "In the Shader Library Window, which presents the Shader Library."
Developer: "Who provides preview images for effects?"
Domain expert: "A Shader Package may provide a package-local preview image, otherwise the app generates one from the shader effect."
