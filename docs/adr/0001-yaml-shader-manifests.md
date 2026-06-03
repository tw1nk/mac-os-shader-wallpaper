# Use YAML shader manifests

Shader packages use YAML as the canonical shader manifest format, even though Swift has built-in support for JSON and property lists. YAML is easier for package authors to write by hand, and the manifest format will include a `manifestVersion` field plus a published schema so editors can help authors and the app can detect older formats for possible conversion. A package may also expose its author-controlled content version as `version`, separate from the manifest format version.
