# Profiling drivers

Dev tooling for measuring frame time, garbage and first-visit costs. All of
it runs from a probe driver (`POKEPORT_DRIVER`), which the engine loads
unsandboxed. The mod itself only carries `lib/Perf.lua`'s hooks, and those
stay dark unless a driver turns them on.

## Running

```
tests\run_profile.cmd profile_bench_probe     scripted bench, writes an AppleCake trace
tests\run_profile.cmd profile_play_driver     play by hand, F8 starts/stops a trace
tests\run_profile.cmd gc_budget_probe         KB of garbage per frame vs tests/gc_budget.lua
tests\run_profile.cmd cold_cost_probe         first-visit cost per map, per stage
```

Output goes to `probe_out\<driver>\` (gitignored) unless `DS_PROBE_DIR` is
set. `GEN1RECOMP`, `LOVE_EXE`, `POKEPORT_VERSION` and `TERRARIUM_ID` override
the defaults at the top of `run_profile.cmd`.

The game must be closed first: a probe is a full game session and writes
the same `options.lua` and save directory.

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

## Pieces

| File | Role |
|---|---|
| `Harness.lua` | finds the mod's export, turns Perf on, wraps entry points (`Harness.WRAPS`), streams spans to AppleCake |
| `applecake_loader.lua` | loads `tools/vendor/AppleCake` without it being on the require path |
| `GcMeter.lua` | stopped-collector windows: KB/frame and per-function attribution |
| `Scenes.lua` | boot, config pin, map visits, pacing, screenshots (shared by every probe) |
| `imgdiff.py` | before/after screenshot check, judged against run-to-run noise |

## Garbage numbers

`collectgarbage("count")` also counts LuaJIT trace objects, so a frame that
compiles a trace reads heavier than its garbage. `DS_GC_JITOFF=1` measures
with the JIT off. Budgets are kept per mode in `tests/gc_budget.lua`; compare
like with like. Per-function KB is inclusive (a wrapped function that calls
another wrapped one carries its KB too).

## Adding a measurement

- In the mod, at a site that runs a few times per frame or less:
  `local t0 = Perf.now()` ... `Perf.add("label", t0)`. That costs one nil
  test while Perf is off. Build label strings once, not per call.
- From a driver, for a module function: add it to `Harness.WRAPS`.
