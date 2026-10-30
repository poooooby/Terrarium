# Pre-cache plan

What a first visit to a map costs today, where that cost goes, and what a
pre-cache system should do about it. The plumbing exists (`lib/PreCache.lua`,
dark, one no-work stage); this document decides what goes into it.

All numbers are from `tests/cold_cost_probe.lua` on the maintainer's desktop,
Terrarium the only mod, Yellow, run with `python tools/profiler/run.py
cold_cost_probe`. Re-run it before acting on any of them; a phone will be
several times slower across the board.

## What the probe measures

For each map: drop every map-derived cache (ChunkMesher, which also drops
Structures and the Buildings kits; TerrainAtlas; Trees3D), warp in, and count
frames until the full mesh is cached and nothing is queued. Then leave for one
map and come straight back ("warm"). The stage times are the `cold.*` spans
plus the harness's wraps. `Structures.forMap` runs inside a mesher coroutine,
so its span is wall time across the frames it yields over, not one frame's
cost. The per-frame cost shows in `cold.mesh.body` max and the worst frame.

## Findings

| map | frames to settle | worst frame | frames > 33 ms | Structures (kits) | mesh body |
|---|---|---|---|---|---|
| PALLET_TOWN | 211 | 662 ms | 7 | 1.7 s | 1.4 s |
| ROUTE_1 | 352 | 364 ms | 15 | 3.3 s | 2.7 s |
| VIRIDIAN_CITY | 226 | 665 ms | 19 | 2.2 s | 1.6 s |
| LAVENDER_TOWN | 739 | **2912 ms** | 33 | 8.8 s | 6.7 s |
| ROUTE_8 | 1200 | 330 ms | 36 | **13.5 s** | 10.0 s |
| VERMILION_CITY | 1107 | 757 ms | 34 | 13.0 s | 9.4 s |
| ROUTE_12 | 1182 | **2279 ms** | 40 | 13.7 s | 9.7 s |
| CELADON_CITY | 383 | 274 ms | 31 | 5.5 s | 4.2 s |

1. **The kits are the cost.** `Buildings.build` (Breno's town kits, called from
   `Structures.forMap`) is 80-95% of the Structures time on every map that has
   them. Route 8, Route 12 and Vermilion each take ~13 s of build work and
   about 1,100-1,200 frames (roughly 20 s at 60 fps) before the scene is whole.
2. **Some of it lands in ONE frame.** Lavender's worst frame is 2.9 s and
   Route 12's 2.3 s. Those are synchronous stalls on the render path, not
   slices. That is a hitch a player sees as a freeze, and no amount of
   pre-warming hides it unless the warm-up itself runs where nobody is looking.
3. **"Warm" is not warm.** Coming straight back after one hop still rebuilds:
   Route 8 warm spends 1.4 s in Structures and 1.7 s in mesh slices, and
   Celadon's warm visit has a 610 ms Structures call. The cause is
   `ChunkMesher.setLive`, which evicts every map outside the current and
   previous live sets, and Structures (with the kits) goes with it. A
   player walking Lavender → Route 8 → Lavender pays for Lavender twice.
4. Shader compiles (`cold.shader.voxel`, ~33 ms over 2 variants) and Skyline
   impostors are paid once per session and are not worth a stage.

## What to build, in order

### 1. Keep what was built (retention), before warming anything

Warming a map that will be evicted the next frame is all cost and no win, so
retention has to come first. Change `ChunkMesher.setLive` eviction from "live
now or live last time" to a small LRU of recently visited maps, plus anything
PreCache has pinned:

- Bound it by count, not by map: `Quality` already knows the device rung. For
  example 6 maps on desktop and 2 on the lowest rung, since a phone's memory is
  the reason eviction exists at all.
- Structures and the kits follow ChunkMesher's eviction today
  (`ChunkMesher.invalidate` → `Structures.invalidate`), so they get the same
  retention for free.
- Measure with `cold_cost_probe` again: the warm rows should drop to roughly
  the warm Pallet row (1 frame, nothing built).

### 2. Warm the kits for reachable maps during COVERED frames

The kit build is pure CPU over static map data, which makes it the ideal first
stage:

- **key:** `mapId`, with the TOWER/kit settings that `Buildings.invalidate`
  already listens to folded in.
- **done:** `Structures.peek(map)` is non-nil.
- **warm:** build `Structures.forMap` for the destination as a coroutine
  sliced by `BuildBudget`, the way ChunkMesher already does. That needs a Map
  instance for a map that is not loaded. The world defs and tilesets are
  static, so build one the way `kit_headless.lua` does offline.
- **budget:** `PreCache.COVERED_SLICE` during door fades and menus;
  `IDLE_SLICE` otherwise, and only once the current map's own jobs are done
  (`ChunkMesher.pending() == 0`).
- **pin:** a warmed map joins the retention set until the player is more than
  one move away.

Warps first (a door is the fastest way into a cold map, and the fade is
exactly a COVERED window), then connections.

### 3. Then the body mesh, the same way

Same key and pin, `ChunkMesher.request(map, true, masks, ChunkMesher.IDLE)`.
Only after step 1, or it is evicted on the spot.

### 4. Persist only if the numbers still say so

`mod.cache` (install-scoped, no manifest permission, 64 MiB per file) can
hold derived data across sessions. It is worth it only for work that is still
too slow after 1-3, and only for data that serializes cheaply. The kit models
are prebuilt local quads (`Buildings.lua` `models`), which are plain numbers.
Meshes are GPU objects and would have to be rebuilt from vertex data anyway.
Do not do this first:

- The cache key must include the mod version, the ROM, the map id and a
  signature of every setting that changes geometry, or it serves stale worlds.
- Invalidation must follow the same rules `Assets.register` already handles
  in memory.

## Rules for any stage

- **Aesthetics only.** A stage builds what the renderer would have built
  anyway. It never touches the world, the save, input, or anything the game
  reads back.
- **Bounded steps.** A step does one slice and returns; the pump checks the
  clock between steps, never inside one.
- **Current map first.** Never compete with the map on screen. The
  `ChunkMesher.pump` tiers stay in charge, and PreCache runs after them.
- **No new permissions.** No `compute` or `background` (`mod.job`) unless a
  measurement shows the main-thread slice cannot keep up. `mod.job` refuses
  `love.*` and `require`, so the kit build would need rewriting to run there.
- **Prove it with the probes.** Each stage lands with before and after
  `cold_cost_probe` numbers in the commit message and keeps `precache_probe`
  passing.
