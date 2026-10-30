-- Probe: what a FIRST visit to a map costs, stage by stage -- the data the
-- pre-cache design (PRECACHE-PLAN.md) is decided from.
--
-- For each map in MAPS:
--   cold:<id>  every map-derived cache dropped (ChunkMesher -- which also
--              drops Structures and Buildings -- TerrainAtlas, Trees3D),
--              then setMap, then frames counted until the full mesh is in
--              and nothing is left queued or stamping
--   warm:<id>  go TWO maps away (each fully settled, so their own builds
--              are not charged to the return), then come back. With the
--              caches doing their job this is a visit with nothing to
--              build; whatever it does build is what retention lost.
--              (An earlier version left for ONE map and only 30 frames,
--              and charged the away map's neighbourhood builds to the
--              return -- every "warm" row looked like a rebuild.)
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
  local AWAY = { { id = "CERULEAN_CITY", x = 18, y = 18 },
                 { id = "FUCHSIA_CITY", x = 18, y = 18 } }

  local function dropCaches()
    pcall(ChunkMesher.invalidate)
    pcall(TerrainAtlas.invalidate)
    pcall(Trees3D.invalidate)
  end

  -- Three moments after arrival, in frames:
  --   shown  this map has SOME terrain mesh (body or full) -- the first
  --          frame the player is not looking at the flat 2D fallback
  --   full   this map's full mesh is in
  --   settle that, plus every neighbour built and nothing queued
  -- "settle" alone overstated what the player waits for: it includes the
  -- neighbours, which are only seen at the edges.
  local function settle(id, guard)
    local shown, full
    for f = 1, guard do
      coroutine.yield()
      local map = game.overworld.map
      if map and map.id == id then
        if not shown and (ChunkMesher.peek(map, true) or ChunkMesher.peek(map, false)) then
          shown = f
        end
        if not full and ChunkMesher.peek(map, false) then full = f end
        if full and ChunkMesher.pending() == 0
            and (Trees3D.buildsInFlight == nil or Trees3D.buildsInFlight() == 0) then
          return f, shown, full
        end
      end
    end
    return nil, shown, full
  end

  local results = {}
  local function measure(c, kind)
    local seg = kind .. ":" .. c.id
    Perf.setSegment(seg)
    Perf.resync()
    if not Scenes.visit(game, V, c, log, true) then
      Perf.setSegment(nil); return
    end
    local frames, shown, full = settle(c.id, 3600)
    -- a few more frames so the last stage's tail lands in the segment
    for _ = 1, 30 do coroutine.yield() end
    Perf.setSegment(nil)
    -- memory after the visit settles: Lua heap after a full collect, and
    -- which maps the mesher is holding (retention is a memory trade)
    collectgarbage("collect"); collectgarbage("collect")
    local held = ChunkMesher.cachedIds and ChunkMesher.cachedIds() or {}
    local luaMB = collectgarbage("count") / 1024
    results[#results + 1] = { seg = seg, id = c.id, kind = kind, frames = frames,
                              shown = shown, full = full,
                              luaMB = luaMB, held = #held }
  end

  for _, c in ipairs(MAPS) do
    Scenes.visit(game, V, AWAY[1], log)
    dropCaches()
    measure(c, "cold")
    Scenes.visit(game, V, AWAY[1], log)
    Scenes.visit(game, V, AWAY[2], log)
    measure(c, "warm")
  end

  -- the ranked summary: per cold segment, frames to settle, worst frame,
  -- and the stages by total time, cold against warm
  log("")
  -- frame COUNTS mislead here: a frame that froze for 3 s counts as one.
  -- So the same moments in wall-clock milliseconds, summed from the
  -- segment's own frame log (Perf.frame, stamped per drawn frame).
  local function msTo(seg, n)
    if not (seg and n) then return "-" end
    local t = 0
    for i = 1, math.min(n, #seg.frames) do t = t + seg.frames[i] end
    return ("%.0f"):format(t * 1000)
  end
  log("map              kind  shown  full  shownMs  fullMs  settle  worst-ms  >33ms  luaMB held   stage totals (ms; n slices; max)")
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
      log(("%-16s %-5s %5s %5s %8s %7s %6s %9.1f %6d %6.0f %4d   %s"):format(
        r.id, r.kind, tostring(r.shown or "-"), tostring(r.full or "-"),
        msTo(seg, r.shown), msTo(seg, r.full),
        r.frames and tostring(r.frames) or "never",
        fs.worst, fs.over33, r.luaMB or 0, r.held or 0, table.concat(parts, "  ")))
    end
  end

  Scenes.unpin()
  H:finish({ probe = "cold_cost" })
  love.event.quit()
end
