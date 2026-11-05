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
  -- DS_SHOT_CACHE=1 leaves the cache ON (still cleared first), so every
  -- build below WRITES its meshes: mod_cache/TERRARIUM then holds the exact
  -- vertex bytes this code uploads, for a byte-for-byte compare of two
  -- builds that are meant to produce the same geometry
  local keepCache = os.getenv("DS_SHOT_CACHE") == "1"
  if not keepCache then BuildCache.setting:sync("off") end
  log(keepCache and "3D CACHE cleared and ON: every build below is written"
      or "3D CACHE cleared and OFF: every visit below is a real build")

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

  -- DS_SHOT_SUM=1: an order-sensitive checksum of the sprite pass's whole
  -- input per map -- every quad's world corners, uvs and shades, in the
  -- order buildSpriteMesh pushes them -- taken just before the map's
  -- analysis is trimmed. It reads the old shape (S.spriteQuads, world
  -- space) and the new (S.spritePlacements, model + offset) the same way,
  -- so two builds meant to upload the same sprite vertices must print the
  -- same numbers.
  local sumLeft = nil      -- set below: sums the maps never trimmed
  if os.getenv("DS_SHOT_SUM") == "1" then
    local Structures = V.require("Structures")
    local trim = Structures.trim
    local seen = {}
    local function sumMap(mapId)
      local S = Structures.peek and Structures.peek({ id = mapId })
      if S and not S.trimmed and not seen[mapId] then
        seen[mapId] = true
        local n, s1, s2, k = 0, 0, 0, 0
        local function add(v)
          k = k + 1
          s1 = s1 + v
          s2 = s2 + v * (k % 9973 + 1)
        end
        -- either quad shape: corner tables and a uv of pairs, or emit's
        -- flat one (corners 1-12, u, v 13-20) -- the same numbers in the
        -- same order either way
        local function quad(q, mx, my, mz)
          n = n + 1
          local flat = type(q[1]) ~= "table"
          for i = 1, 4 do
            if flat then
              local b = (i - 1) * 3
              add(q[b + 1] + mx); add(q[b + 2] + my); add(q[b + 3] + mz)
              add(q[11 + 2 * i]); add(q[12 + 2 * i])
            else
              add(q[i][1] + mx); add(q[i][2] + my); add(q[i][3] + mz)
              add(q.uv[i][1]); add(q.uv[i][2])
            end
            local sh = q.shade
            add(type(sh) == "table" and sh[i] or (sh or -1))
          end
        end
        for _, q in ipairs(S.spriteQuads or {}) do quad(q, 0, 0, 0) end
        for _, p in ipairs(S.spritePlacements or {}) do
          for _, q in ipairs(p.quads) do quad(q, p.mx, p.my, p.mz) end
        end
        log(("SUM %-20s quads %8d  s1 %.17g  s2 %.17g"):format(mapId, n, s1, s2))
        -- and the terrain pass's objectQuads (the atlas-textured models
        -- stamp copies there, beside the terrain's own)
        n, s1, s2, k = 0, 0, 0, 0
        for _, q in ipairs(S.objectQuads or {}) do
          n = n + 1
          for i = 1, 4 do
            add(q[i][1]); add(q[i][2]); add(q[i][3])
            local uv = q.uv and q.uv[i]
            add(uv and uv[1] or (q.u or -1)); add(uv and uv[2] or (q.v or -1))
            local sh = q.shade
            add(type(sh) == "table" and sh[i] or (sh or -1))
          end
        end
        log(("OBJ %-20s quads %8d  s1 %.17g  s2 %.17g"):format(mapId, n, s1, s2))
      end
    end
    Structures.trim = function(mapId, ...)
      sumMap(mapId)
      return trim(mapId, ...)
    end
    -- a map is trimmed only once several newer ones are kept, so a short
    -- run (DS_SHOT_MAPS) would never sum its own maps: the visited ones
    -- still whole at the end are summed then
    sumLeft = function(ids) for _, id in ipairs(ids) do sumMap(id) end end
  end

  -- DS_SHOT_STILL=1: hold the frame still for a look comparison -- no cloud
  -- shadow drifting over the ground, no wildlife, no wind in the grass --
  -- so two shots differ by what was built and not by the moment they took
  if os.getenv("DS_SHOT_STILL") == "1" then
    V.require("CloudShade").setting:sync("off")
    V.require("AmbientLife").setting:sync("off")
    V.require("Wind").setting:sync(0)
    log("still frame: cloud shadow, wildlife and wind OFF")
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
    -- the map's own mesh (what the player waits for), apart from the whole
    -- queue draining (its neighbours' prefetch too) that `secs` waits on
    local own = Scenes.ownTime and (Scenes.ownTime - t0) or -1
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
    log(("%-20s %s  %6.2fs (own %5.2fs)  heap %6.0f MB  quads %8d  | %s"):format(
      id, ok and "ok  " or "FAIL", secs, own, heap, allQ, table.concat(parts, "  ")))
    -- leave the map's own builds behind before the next one is charged
    Scenes.wait(30)
  end
  Perf.setSegment(nil)
  if sumLeft then sumLeft(MAPS) end
  -- let the last map's slots finish writing before the run ends
  if keepCache then Scenes.wait(240) end
  BuildCache.setting:sync("on")
  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  H:finish({ probe = "kanto_shots" })
  love.event.quit()
end
