# Profiling drivers

Dev tooling for measuring frame time, garbage and first-visit costs. All of
it runs from a probe driver (`POKEPORT_DRIVER`), which the engine loads
unsandboxed. The mod itself only carries `lib/Perf.lua`'s hooks, and those
stay dark unless a driver turns them on.

## Running

```
python tools/profiler/run.py profile_bench_probe   scripted bench, writes an AppleCake trace
python tools/profiler/run.py profile_play_driver   play by hand, F8 starts/stops a trace
python tools/profiler/run.py gc_budget_probe       KB of garbage per frame vs tests/gc_budget.lua
python tools/profiler/run.py cold_cost_probe       first-visit cost per map, per stage
python tools/profiler/run.py precache_probe        lib/PreCache.lua plumbing
```

`run.py` enables ONLY Terrarium for the run: it rewrites the engine's
`options.lua` through the engine's own serializer, then restores the original
byte for byte, even if the run crashes. `--all-mods` keeps your mod set. It
refuses to start while the game is open, since a probe is a full game session
writing the same `options.lua`. Drivers boot with
`Game:startNewGame{intro=false}`, which skips the title and never saves, and
the runner warns if a save file's timestamp moved anyway.

Output goes to `probe_out/<driver>/` (gitignored) unless `--out` is given.
`--env NAME=VALUE` passes settings to the driver (`DS_TRACE=0`,
`DS_GC_RECORD=1`, `DS_GC_DEEP=1`, `DS_GC_JITOFF=1`, `DS_GC_TOP=<n>`).
`GEN1RECOMP`, `LOVE_EXE`, `LUAJIT` and `POKEPORT_VERSION` override the
defaults at the top of `run.py`.

## Reading a trace

Drop the `.json` from the output directory onto https://ui.perfetto.dev (or
`about://tracing` in Chrome/Edge). You get:

- a `frame` span per driver frame,
- every wrapped entry point (`VoxelScene.render`, `Weather.update`, ...) and
  every `cold.*` stage, nested where they ran,
- `Memory usage` and `lua KB delta` counters (a negative delta is a GC cycle),
- a marker at each scene change (`<MAP>:stand`, `<MAP>:walk`).

`<name>_perf.json` holds Perf's tables (per segment: frame percentiles and
per-label n/total/max/kb), in a stable key order so two runs diff cleanly.
`<name>.log` has the same as text.

## Pieces

| File | Role |
|---|---|
| `run.py` / `bench_options.lua` | the Terrarium-only runner and its options rewrite |
| `Harness.lua` | finds the mod's export, turns Perf on, wraps entry points (`Harness.WRAPS`; `DEEP_WRAPS` for GC attribution), streams spans to AppleCake |
| `applecake_loader.lua` | loads `tools/vendor/AppleCake` without it being on the require path |
| `GcMeter.lua` | stopped-collector windows: KB/frame and per-function attribution |
| `Scenes.lua` | boot, config pin, map visits (snapped to a walkable cell, waiting for the full mesh), pacing, screenshots |
| `imgdiff.py` | before/after screenshot check, judged against run-to-run noise |

## Garbage numbers

`collectgarbage("count")` also counts LuaJIT trace objects, so a frame that
compiles a trace reads heavier than its garbage. `DS_GC_JITOFF=1` measures
with the JIT off. Budgets are kept per mode in `tests/gc_budget.lua`; compare
like with like. Per-function KB is inclusive (a wrapped function that calls
another wrapped one carries its KB too).

`DS_GC_DEEP=1` also wraps what `VoxelScene.render` calls through module
tables (`Mat4.*`, `Voxel3D.*`, `ShadowMap.*`, ...). That is how the matrix
garbage was found. It is too hot for a timing run, and a deep run never
records a budget.

## Screenshots

A frame is never bit-identical across runs, because water, grass, clouds and
ambient life move with the clock. So `imgdiff.py base_a base_b fixed`
measures the noise between two baseline runs first and flags only a change
well beyond it.

## Adding a measurement

- In the mod, at a site that runs a few times per frame or less:
  `local t0 = Perf.now()` ... `Perf.add("label", t0)`. That costs one nil
  test while Perf is off. Build label strings once, not per call.
- From a driver, for a module function: add it to `Harness.WRAPS`.
