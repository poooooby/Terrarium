# Vendored dev tools

Third-party code used only by the profiling drivers. It is not loaded by the
mod and is left out of the release zip (`.gitattributes` `export-ignore`, and
`.modkitignore`).

| Library | Version | Source | Licence | Used by |
|---|---|---|---|---|
| AppleCake | tag 2.1 (`2d2e2b235ac3a490f0c74f32c536f6e012bfa7af`) | https://github.com/EngineerSmith/AppleCake | MIT (`AppleCake/LICENSE`) | `tools/profiler/applecake_loader.lua` |

The files are copied unedited. `applecake_loader.lua` adapts to them from the
outside (preloading its modules, and handing its writer thread source text
instead of a `love.filesystem` path), so updating means replacing the folder
and the row above.

To update:

```
for f in AppleCake.lua init.lua thread.lua threadConfig.lua outputStream.lua LICENSE README.md; do
  gh api "repos/EngineerSmith/AppleCake/contents/$f?ref=<tag>" --jq .content | base64 -d > tools/vendor/AppleCake/$f
done
```
