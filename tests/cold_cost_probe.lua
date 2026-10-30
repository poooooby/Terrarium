-- Probe: what a FIRST visit to a map costs, stage by stage -- the data the
-- pre-cache design (PRECACHE-PLAN.md) is decided from.
--
-- For each map in MAPS:
--   cold:<id>  every map-derived cache dropped (ChunkMesher -- which also
--              drops Structures and Buildings -- TerrainAtlas, Trees3D),
--              then setMap, then frames counted until the full mesh is in
--              and nothing is left queued or stamping
--   warm:<id>  leave, come straight back with the caches kept: the same
--              walk with nothing to build, so cold minus warm is what a
--              pre-cache could take off that first visit
--
-- The stages are the cold.* spans in the mod (ChunkMesher pump slices,
-- Trees3D stamping, Structures.forMap, TerrainAtlas bakes, Voxel3D shader
-- compiles, Skyline impostors) plus the harness's wraps (Buildings.build,
-- WaterBody.refresh, ...). Shader compiles and Skyline impostors are never
-- invalidated, so they only show on the boot segment and the first visit.
--
--   <DS_PROBE_DIR>/cold_cost.log         ranked per-map summary
--   <DS_PROBE_DIR>/cold_cost_perf.json   every segment, every label
--
--   POKEPORT_VERSION=yellow DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/<id>/tests/cold_cost_probe.lua love .
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "cold_cost" }))
  local log, Perf, V = H.log, H.Perf, H.V

  Perf.setSegment("boot")
  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)
  -- the first voxel frames (shader compiles, first atlas) land in "boot"
  Scenes.wait(120)   -- drawWorld stamps Perf.frame itself
  Perf.setSegment(nil)

  local ChunkMesher = V.require("ChunkMesher")
  local TerrainAtlas = V.require("TerrainAtlas")
  local Trees3D = V.require("Trees3D")

  local MAPS = {
    { id = "PALLET_TOWN", x = 10, y = 11 },
    { id = "ROUTE_1", x = 10, y = 20 },
    { id = "VIRIDIAN_CITY", x = 18, y = 18 },
    { id = "LAVENDER_TOWN", x = 10, y = 10 },
    { id = "ROUTE_8", x = 20, y = 10 },
    { id = "VERMILION_CITY", x = 10, y = 10 },
    { id = "ROUTE_12", x = 10, y = 15 },
    { id = "CELADON_CITY", x = 10, y = 10 },
  }
  local AWAY = { id = "PALLET_TOWN", x = 10, y = 11 }

  local function dropCaches()
    pcall(ChunkMesher.invalidate)
    pcall(TerrainAtlas.invalidate)
    pcall(Trees3D.invalidate)
  end

  local function settle(id, guard)
    return Scenes.ready(game, V, id, guard)
  end

  local results = {}
  local function measure(c, kind)
    local seg = kind .. ":" .. c.id
    Perf.setSegment(seg)
    Perf.resync()
    if not Scenes.visit(game, V, c, log, true) then
      Perf.setSegment(nil); return
    end
    local frames = settle(c.id, 1800)
    -- a few more frames so the last stage's tail lands in the segment
    for _ = 1, 30 do coroutine.yield() end
    Perf.setSegment(nil)
    results[#results + 1] = { seg = seg, id = c.id, kind = kind, frames = frames }
  end

  for _, c in ipairs(MAPS) do
    Scenes.visit(game, V, AWAY, log, true); Scenes.wait(30)
    dropCaches()
    measure(c, "cold")
    Scenes.visit(game, V, AWAY, log, true); Scenes.wait(30)
    measure(c, "warm")
  end

  -- the ranked summary: per cold segment, frames to settle, worst frame,
  -- and the stages by total time, cold against warm
  log("")
  log("map              kind  settle  worst-ms  >33ms   stage totals (ms; n slices; max)")
  for _, r in ipairs(results) do
    local seg = Perf.segments[r.seg]
    if seg then
      local fs = Perf.frameStats(seg.frames)
      local stages = {}
      for _, lbl in ipairs(seg.order) do
        local s = seg.labels[lbl]
        stages[#stages + 1] = { lbl = lbl, total = s.total * 1000, n = s.n,
                                max = s.max * 1000 }
      end
      table.sort(stages, function(a, b) return a.total > b.total end)
      local parts = {}
      for i = 1, math.min(6, #stages) do
        local s = stages[i]
        parts[#parts + 1] = ("%s %.1f;%d;%.1f"):format(s.lbl, s.total, s.n, s.max)
      end
      log(("%-16s %-5s %6s %9.1f %6d   %s"):format(
        r.id, r.kind, r.frames and tostring(r.frames) or "never",
        fs.worst, fs.over33, table.concat(parts, "  ")))
    end
  end

  Scenes.unpin()
  H:finish({ probe = "cold_cost" })
  love.event.quit()
end
