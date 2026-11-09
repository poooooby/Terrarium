# Lifecycle catalogue

Written for anyone changing this mod, human or agent. It lists every lifecycle the code encodes without a named state: combinations of flags, `nil`/`false`/value tri-states, timers acting as states, one-shot latches.

The mod does not use a state-machine framework, on purpose. These lifecycles run on hot paths, Gen 1 has to stay pixel-identical, and most are simple. Instead:

- **Lifecycles worth naming report themselves** to `lib/StateReport.lua`. Each derives its state from its existing fields, so reporting changes no behaviour and costs nothing per frame.
- **A bug gets fixed in its own transition**, with the smallest change that holds.
- **The rest are listed here** with the reason they stay as they are.

## How to read a state

| From | Call |
|---|---|
| In game | Turn on the DEBUG INFO row. The panel lists every reported state. |
| A probe or an agent | `game.mods.exports.TERRARIUM.lib.require("StateReport").all()` |
| Another mod | `mod.exports.states`, the same module |

`StateReport.state(name)` reads one. A state shown as `?something` means the derivation returned a value its declaration doesn't list, so the two have drifted apart. `error` means the derivation threw, and its detail says why.

## Adding a lifecycle

Use a `{ phase = "...", t = ... }` record rather than a new combination of flags. `LoadVeil` is the model. Give it a way out that doesn't depend on an event that might never fire. Then declare it to `StateReport` beside its fields and add a row below; `python tools/check_states.py` fails until the two agree.

If the lifecycle owns anything that a screen on the stack is using, check the owner is still there. A soft reset (`Game:returnToTitle`) pops every screen and emits nothing: no `battle.ended`, no close call. `Screen.onStack(game, state)` answers it.

## Reported

| Name | States | Where | Notes |
|---|---|---|---|
| `world.freeroam` | freeroam, covered, warping, no-world | `main.lua` | The player can see and walk the world. Modules ask `Screen.onTop`. |
| `pipeline.voxel` | off, eligible, retired | `main.lua` | `retired` is the engine's `broken[id]`, one throw from a pipeline callback, for the session. |
| `scene.gate` | off, waiting, easing-in, on, easing-out | `lib/VoxelState.lua` | `waiting` holds the camera flat until the map has a mesh. Only `VoxelScene.prefetch` can release it, so a throw there is printed once. |
| `scene.mesh` | absent, queued, running, ready, empty, failed, stale | `lib/ChunkMesher.lua` | The live map's full mesh. `failed` and `empty` were both a bare `false` once. |
| `scene.settled` | no-mesh, neighbours, trees, settled | `main.lua` | What a probe waits for. Own mesh first, then the neighbour queue, then forests. |
| `scene.trees` | ready, building, cold, hulls | `lib/Trees3D.lua` | `hulls` is terminal: this map decided against the model. |
| `veil.load` | none, hold, fade | `lib/LoadVeil.lua` | |
| `veil.build` | none, ask, build | `lib/BuildVeil.lua` | |
| `battle.session` | none, opening, staged, in-frame, shotless, broken | `lib/OverworldBattle.lua` | `in-frame`: staged, HUDs inside the GB frame. `shotless`: the render returned nothing this frame. `broken`: retired for this battle. |
| `battle.nav` | retired, idle, menu, move, party | `lib/BattleNav.lua` | Who owns the D-pad. Anything but `retired` and `idle` swallows directions. |
| `battle.exit` | idle, out, in | `lib/BattleExit.lua` | The fade out of a battle. |
| `battle.shot` | idle, attack, hold, recover | `lib/BattleShot.lua` | Already explicit. |
| `preset.full` | unseen, off, on | `main.lua` | The FULL arrival latch. Which rows FULL holds is in `settingRows` and `forceSync`. |
| `weather.spell` | off, clear, wet, pinned, fading, after, failed | `lib/Weather.lua` | `kind` outlives `target` through `fading`. |
| `time.mode` | pinned, sync-wall, cycle | `lib/DayNight.lua` | |
| `camera.mode` | off, orbit, radial, close, eight, behind, fixed | `lib/MarioCam.lua` | |
| `quality.governor` | unseeded, inert, filling, settling, trial, idle | `lib/AutoQuality.lua` | Tested offline by `tools/run_autoquality_offline.py`. |
| `worldmap.build` | unbuilt, building, built, failed | `lib/WorldMap3D.lua` | `failed` falls back to the classic map for the session. |

## Fixed transitions

The bugs these lifecycles were hiding, kept here so the reasoning survives.

| Lifecycle | What was wrong | The transition now | Proof |
|---|---|---|---|
| Battle session | A soft reset emits no `battle.ended`, so the arena rendered behind the title, the D-pad stayed captured, and the old cast was later written over the new map's. | Once the battle has been seen on the stack and is gone, `update` calls `finish`. The "seen" latch protects the wipe, before the battle is pushed. | `tests/state_report_probe.lua` |
| Colors prompt | Popped by a soft reset, it stayed set, with a panel drawn forever and no input. | `update` and `active` drop it when it's off the stack. | same |
| Landing splat | The once-per-arena latch keyed on a token bumped every frame, so two full splats fired per frame and evicted the typed hit dents. | Keyed on the arena table. | same |
| FULL and the manager page | `forceSync()` had no game, so live said SYNC and the file kept the player's value. | `forceSync` falls back to the game, as `forceOG` does. | same |
| FULL arrival | The latch was consumed before the guard that could refuse it. | Latched only once the preset can apply. | reading |
| Weather fade | `rollClear` cleared `kind` at once, so streaks vanished while the sky took 14 s. | `kind` stays until the fade ends; AUTO's timer tests `target`. | same, plus `after_rain_probe` |
| Free-roam gate | `stack:top() == ow` was written out by hand in about 18 modules. | One function, `Screen.onTop`, with the same answer. | `kanto_shots_probe` |
| Mesh failure | `false` meant failed or empty, and the build badge crept to 95% forever. | The failure is recorded; `BuildBadge` drops. | `state_report_probe` |
| Silent prefetch | A throw was swallowed and the camera waited forever. | Printed once, shown in DEBUG INFO. | reading |
| "Scene never finished" | `LAVENDER_TOWN` failed every probe run on neighbour builds while its own mesh was done in under 2 s. | A NOTE when the own mesh exists; only no mesh at all fails. | `kanto_shots_probe` |

## Known and left alone

Real, but not worth the risk or the code today. Each could become work if it starts to matter.

| Lifecycle | Where | Why it stays |
|---|---|---|
| Clocks on the voxel update hook | `main.lua` update | `DayNight`, `Weather` and `MarioCam` stop if the pipeline is retired. Moving them reorders every update in the mod, for a state only reached after a render error. |
| Bake abandonment | `lib/PreCache.lua`, `ChunkMesher.bake` | A cancelled bake skips cleanup. Dev-only and dark. |
| `pushBattle` throwing after `begin` | `lib/OverworldBattle.lua` | The cast stays culled until the next `begin`. It takes an engine error to reach. |
| Battle exit with evolution | `lib/BattleExit.lua` | `wanted()` mirrors only the pay-day deferral, so an evolution fades twice. Cosmetic. |
| World map `failed` latch | `lib/WorldMap3D.lua` | One throw means the classic map until restart, which works. |
| WEATHER set to OFF mid-shower still arms the rainbow | `lib/Weather.lua` | Looks like a bug and isn't: `after_rain_probe` asserts that clearing rain this way arms it. |
| Weather failure leaves `DayNight.storm` | `lib/Weather.lua` | Only on the one-way failure path. |
| `MeshBytes.recording` after a cancelled bake | `lib/ChunkMesher.lua` | Clears on the next pump with jobs. |
| `clearArmed` survives moving the cursor | `main.lua` | The row's label warns. |
| Atlas animation retry | `lib/TerrainAtlas.lua` | `animate` writes `(entry == false) and false or attemptFailed(key)`, which always takes the last arm, so a `false` from `newEntry` also spends the retry budget instead of latching. It reads like a bug and behaves correctly: a throw is retried, and "nothing animates here" costs three cheap tries. `state_report_probe` pins it. |
| `ModSetting.setIndex` with no game | `lib/ModSetting.lua` | Probes use `sync` for non-persisting overrides; `forceSync` was the one real caller that needed the file. |

## Simple on purpose

No named state would help these.

- **Caches and tri-states** (`nil` unread, `false` failed, a value): `Buildings` scoped caches, `BuildCache.index`, `WaterMap.allowed`, `Grass3D.tpl`, `Skyline.builtThisFrame`, `WorldAtlas`, `Device.isMobile`, `Sky`, `Vfx`, `StreetLamps`, `BattleBillboard`, `BattlePanelsXY` lazy loads, `Structures` nil/full/trimmed.
- **Install-once flags:** every `install()`.
- **One-way failure latches:** `Weather.failed`, `GroundFX`, `AmbientSound`, `WaterBody.failed`, the `Voxel3D` shader ladder (`rung`).
- **Edge detectors and last-value trackers:** `voidFill.last`, `lastLiveKey`, `lastViewH`, `gpuReported`, `DayNight.lastMode`, `SnowFallFX.wasBumping`, `GroundFX.boundKey`, `BattleHudXY` theme, `BattleBoxXY` selection pop, `BattleScreenXY` entrance clocks.
- **Plain timers and clocks:** `BattleCam`, `WindFX.frontCool`, `Wind.gustNow`, `Ripples`, `MarioCam.trans`, `FishFX` (already has a named phase).
- **Derived every frame:** `BattleNav.wants`, `WorldMapQuest`, `BattleDynamic` flags, `StartMenuXY`, `StartMenuMap`, `Light`, `Lang`, `CloudShade`.
- **Pure and tested:** `BattlePanelsXY._msgIdentity` (`tests/battlepanel_pop_offline.lua`).
- **Arm and disarm in one frame:** `WorldPostDraw`, `DayTint.painted`.
