# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

TerrariumVoxel (mod id `TERRARIUM`; repo `poooooby/Terrarium`) is a Lua mod for the [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) engine (LÖVE / LuaJIT, so **Lua 5.1 dialect**). It is a fork of BrenoBertucci's Terrarium (itself a fork of the Dramatic Shape Voxel Mod) that turns the Gen 1 overworld into a 3D diorama, with weather, ambient life and a staged battle camera. The original maintainer handed the project over; his last unpushed build was merged in 1.41.0 (commit `import: Breno's final unpushed build`). There is no build step: the engine loads `main.lua` (declared as `entry` in `manifest.json`) from `mods/TERRARIUM/`. The engine's own sources (`src/...`, e.g. `src/mods/Schemas.lua`, `src/core/Input.lua`) are referenced in comments but are **not** in this repo.

Gen 1 (Red/Blue/Yellow) is the only target: `manifest.json` declares `"games": ["gen1"]`. The Gold first pass (`Gen2Bridge`) was removed in 1.41.0; don't add Gen 2 branches back.

## Architecture

- **`main.lua` declares, `lib/` draws.** `main.lua` registers two render pipelines (`terrarium_voxel` — a `drawWorld` pipeline; `terrarium_tiltshift` — a `worldPresent` post-pass), wires options rows, letter hotkeys, and engine hooks via `mod.hooks:wrap("<hook>", function(next, ...) ... end)` (e.g. `ui.options.rows`, `encounter.roll`, `pokemon.sprite`, `world.tod`, `input.step`). Feature logic lives in `lib/`.
- **Module loading goes through the `V` namespace, not `require`.** The mod dir isn't on `package.path` and may be inside a mounted `.love` archive. Every `lib/*.lua` starts with `local V = ...` and loads siblings with `V.require("Name")` (loads `lib/Name.lua`, cached). Data tables in `data/*.lua` load with `V.data("name")`. Only engine modules use plain `require("src....")`.
- **Exports:** `mod.exports.lib = V` (plus `version`, `pipelines`, `keys`) — probes and other mods (e.g. the Porygonal adapter) reach internals via `game.mods.exports.TERRARIUM.lib`.
- **Settings:** mod-owned toggles use `lib/ModSetting.lua` (`ModSetting.new(key, label, values, labels)`), which persists to `options.modOptions.TERRARIUM` and adds the row to both the mod-manager page and the OPTIONS menu. Every feature should have an OFF row and nothing should be load-bearing for anything else.
- **Coexistence with upstream `DRAMATIC_SHAPE`:** pipeline keys and hotkeys are deliberately distinct (letters `v g t c m b p h k j q e r f`; upstream uses digits 3/5–9, engine uses 2–5 and GB bindings). Check `main.lua`'s key block before claiming a new key.
- **Aesthetics only — this is the project's defining rule.** Nothing in the mod may change how the game PLAYS: no collision, movement, encounters, battle rules, EXP, items, event flags, NPC positions or facings, synthetic input, or engine hooks such as `encounter.*`, `battle.exp_award`, `movement.speed`, `evolution.check`. 1.41.0 removed every mechanic that broke this (WILD/ECOLOGY/TOWN/ROUTINES/SHELTER/EXP/CARRY/QOL/A-FARM/hidden items/walk-on-ice, and Breno's PARRY/CHARGE/CREATURES/StoryFixes). Don't add new ones; if a request needs one, say so.
- **Mobile/GLES2 constraints matter.** `lib/Quality.lua`, `lib/AutoQuality.lua`, `lib/Device.lua` govern resolution/shadow budgets for weak GPUs. The main shader in `lib/Voxel3D.lua` (`local SHADER = [[ ... ]]`) must keep explicit precision qualifiers (`VXHP`) on uniforms and the guarded `precision highp float;` — see `tools/essl1_check.py` for the exact rules.
- UI text this mod draws itself is localized through `lib/Lang.lua` (the UI LANG row): **English is the default**, Portuguese is the `Lang.pick(en, pt)` second half. New user-visible strings must be English (route through `Lang.pick` if a PT half is wanted). `MOBILE.md` and some comments are in Portuguese.

## Testing

There is no unit-test runner; tests are of two kinds:

1. **In-game probes** (`tests/*_probe.lua`): driver scripts that run the real game headless and write logs/screenshots. Each returns `function(game) ... end`. Run via env vars (the `tests/run_*.cmd` files show the pattern, with paths hardcoded to the original author's machine):
   ```
   POKEPORT_VERSION=yellow DS_PROBE_DIR=<out dir> POKEPORT_DRIVER=mods/TERRARIUM/tests/<probe>.lua gen1recomp --console
   ```
   The mod must be installed as `mods/TERRARIUM` for these paths to work.
2. **Offline tests** (no GPU/LÖVE), run in Lua 5.1 or via Python `lupa`:
   ```
   lua tests/grass_wear_offline.lua <mod-root>        # also waterbody_, water_spectrum_, grass_crush_offline
   python tools/run_autoquality_offline.py           # AutoQuality governor; exits non-zero on failure
   python tools/essl1_check.py                       # GLES2 shader rules in lib/Voxel3D.lua
   ```
   `tests/voxel_figure_test.lua` is an upstream leftover (expects a `tests.harness` module not present here).

3. **Profiling drivers** (`tools/profiler/`, see its README): `python tools/profiler/run.py <driver>` runs a driver with ONLY Terrarium enabled (it rewrites the engine's `options.lua` and restores it byte for byte, and refuses while the game is open). Drivers boot through `Game:startNewGame{intro=false}`, so no save is touched.
   - `profile_bench_probe`: frame times plus an AppleCake trace (open in ui.perfetto.dev).
   - `profile_play_driver`: play by hand; F8 starts and stops a trace.
   - `gc_budget_probe`: KB of garbage per frame against `tests/gc_budget.lua`. `DS_GC_DEEP=1` splits `VoxelScene.render` by callee; `DS_GC_RECORD=1` rewrites the budget.
   - `cold_cost_probe`: first-visit cost per map, per stage.
   - `precache_probe`: the `lib/PreCache.lua` plumbing.

   In the mod, a measurement is `local t0 = Perf.now()` ... `Perf.add("label", t0)` (one nil test while Perf is off). Never build the label string per call. `lib/PreCache.lua` stays dark (Perf on AND forced or its dev row ON); read `PRECACHE-PLAN.md` before adding a stage. Matrices in per-frame paths: use `Mat4.mulInto`/`set*` with scratch tables, or the `out` argument on `billboardMatrix`/`casterMatrix`/`ShadowMap.snug` when the result goes straight into a draw (`tests/mat4_offline.lua` pins the arithmetic).

Syntax-check Lua with the engine's LuaJIT: `python compat/porygonal/luacheck.py <file.lua> ...` (DLL path is hardcoded at the top — edit for the local machine).

## Release / packaging

- Releases are cut by `.github/workflows/release.yml` on every push to `main` (ignoring `.github/**` and `*.md`): it takes `manifest.json`'s `version` if that is newer than the latest `v*` tag, otherwise bumps the patch, then `git archive HEAD` → `TERRARIUM-<version>.zip` → GitHub Release. **Every tracked file ships**; there is no file list to maintain.
- So a release commit bumps `manifest.json`, `quiver-catalog-entry.json`, `quiver-local-index.json` (and the `mod.exports.version` fallback in `main.lua`) and moves the CHANGELOG entry from `## Unreleased` to its version heading. Plain semver, no `-beta` suffix since 1.40.5; never encode feature names in the version. Pushing to `main` publishes — don't do it without being asked.
- `tools/pack_release.py`, `tools/publish_release.ps1` and `publish/BrenoBertucci@TERRARIUM/` are the original maintainer's packaging for his own Quiver listing, kept for reference; this fork does not use them.
- Issue drafts: `powershell -File .github/issues-draft/create.ps1` (after `gh auth login`).

## Policies (from ROADMAP/README)

- No Nintendo or third-party art in the repo/zip without an explicit licence — such assets are fetched by install scripts in `tools/` instead.
- Ambient audio must be **CC0 1.0 only** (see `assets/audio/CREDITS.md`).
- Code comments in this repo are long-form and explain *why* (measurements, failure history); match that style when editing.
