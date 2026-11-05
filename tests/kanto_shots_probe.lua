-- Probe: the Kanto import's maps, built for real, photographed and costed.
--
-- The yardstick for the efficiency work on FadeyMods' Kanto scenes (3adf5ed
-- onwards). Every fix that is meant NOT to change the look is held to the
-- screenshots this writes: run it twice on the old build (the run-to-run
-- noise -- water, grass, clouds move with the clock) and once on the new,
-- then
--
--   python tools/profiler/imgdiff.py <base_a> <base_b> <fixed>
--
-- The 3D CACHE is cleared and switched OFF first, so every visit is a real
-- build: a cached map would load meshes another build wrote under the same
-- version signature (BuildCache keys on the mod's version, not its code) and
-- measure, and show, the wrong thing.
--
-- Per map it logs: seconds to a finished scene, the Lua heap after a full
-- collect (what the build LEFT behind), and the templates that cost most --
-- time from the bld.<id> spans and quads from the bldq.<id> counters
-- (lib/Buildings.lua; both dark unless Perf is on, which the harness does).
--
--   python tools/profiler/run.py kanto_shots_probe --out shots_a
--   DS_SHOT_MAPS=PEWTER_CITY,MT_MOON_1F   to shoot only those
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "kanto_shots" }))
  local log, Perf, V = H.log, H.Perf, H.V

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)

  local BuildCache = V.require("BuildCache")
  pcall(BuildCache.clear)
  BuildCache.setting:sync("off")
  log("3D CACHE cleared and OFF: every visit below is a real build")

  local MAPS = {
    -- control: content that was already there before the import
    "LAVENDER_TOWN", "VERMILION_CITY",
    -- the import's towns and routes, the two that never settled among them
    "PALLET_TOWN", "PEWTER_CITY", "CERULEAN_CITY", "FUCHSIA_CITY",
    "CELADON_CITY", "CINNABAR_ISLAND", "ROUTE_17", "INDIGO_PLATEAU",
    "SAFARI_ZONE_CENTER", "VIRIDIAN_FOREST",
    -- and its interiors
    "MT_MOON_1F", "SILPH_CO_1F", "SS_ANNE_1F", "POWER_PLANT",
  }
  local only = os.getenv("DS_SHOT_MAPS")
  if only and only ~= "" then
    MAPS = {}
    for id in only:gmatch("[^,%s]+") do MAPS[#MAPS + 1] = id end
  end

  local function snapCounters()
    local c = {}
    for k, v in pairs(Perf.counters or {}) do c[k] = v end
    return c
  end

  local fails = 0
  for _, id in ipairs(MAPS) do
    Perf.setSegment("map:" .. id)
    local before = snapCounters()
    local t0 = love.timer.getTime()
    -- the same cell every run, so the camera frames the same view
    local c = { id = id, x = 6, y = 6 }
    local ok = Scenes.visit(game, V, c, log)
    local secs = love.timer.getTime() - t0
    if not ok then fails = fails + 1 end
    Scenes.shot(OUT, "shot_" .. id)
    collectgarbage("collect")
    local heap = collectgarbage("count") / 1024
    -- the templates that cost most on this map
    local seg = Perf.segments and Perf.segments["map:" .. id]
    local rows = {}
    for label, s in pairs((seg and seg.labels) or {}) do
      local tid = label:match("^bld%.(.+)$")
      if tid then
        local q = (Perf.counters["bldq." .. tid] or 0) - (before["bldq." .. tid] or 0)
        rows[#rows + 1] = { tid = tid, ms = s.total * 1000, q = q }
      end
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    local parts = {}
    for i = 1, math.min(6, #rows) do
      parts[i] = ("%s %.0fms %dq"):format(rows[i].tid, rows[i].ms, rows[i].q)
    end
    local allQ = 0
    for _, r in ipairs(rows) do allQ = allQ + r.q end
    log(("%-20s %s  %6.2fs  heap %6.0f MB  quads %8d  | %s"):format(
      id, ok and "ok  " or "FAIL", secs, heap, allQ, table.concat(parts, "  ")))
    -- leave the map's own builds behind before the next one is charged
    Scenes.wait(30)
  end
  Perf.setSegment(nil)
  BuildCache.setting:sync("on")
  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  H:finish({ probe = "kanto_shots" })
  love.event.quit()
end
