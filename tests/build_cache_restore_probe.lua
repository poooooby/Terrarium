-- Probe: does a map RESTORED from the 3D build cache look exactly like the
-- same map BUILT? And does the restore really skip the build?
--
-- Three passes over the same maps, the in-memory meshes dropped before
-- each visit (ChunkMesher.invalidate -- the cache files are untouched):
--   a/  cache ON, cache cleared first: every map is built, and written
--   b/  cache OFF: every map is built again (the run-to-run noise baseline:
--       water, grass and clouds move with the clock, so no two frames match)
--   c/  cache ON: every map should be RESTORED -- the log says how many
--       parts came off disk and whether Structures.forMap ran at all
-- Then compare with tools/profiler/imgdiff.py a b c: a restore that drew
-- anything differently reads far outside the a/b noise.
--
--   python tools/profiler/run.py build_cache_restore_probe
--   python tools/profiler/imgdiff.py <out>/a <out>/b <out>/c
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "build_cache_restore" }))
  local log, V = H.log, H.V

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)
  Scenes.wait(120)

  local ChunkMesher = V.require("ChunkMesher")
  local BuildCache = V.require("BuildCache")
  local Structures = V.require("Structures")

  -- count restores and analysis builds without touching the mod's code
  local restores, builds = 0, 0
  local builtIds = {}
  -- which part missed, when a visit had to build (the reason is the fix)
  local origHas = BuildCache.has
  local misses = {}
  BuildCache.has = function(map, part, masks)
    local hit = origHas(map, part, masks)
    if not hit then misses[#misses + 1] = map.id .. "." .. part end
    return hit
  end
  local origRestore = BuildCache.restoreGroup
  BuildCache.restoreGroup = function(...) restores = restores + 1; return origRestore(...) end
  local origForMap = Structures.forMap
  Structures.forMap = function(map, ...)
    local S = Structures.peek(map)
    if not S or S.trimmed then
      builds = builds + 1
      builtIds[#builtIds + 1] = map.id
    end
    return origForMap(map, ...)
  end

  local MAPS = {
    { id = "PALLET_TOWN", x = 10, y = 11 },
    { id = "LAVENDER_TOWN", x = 10, y = 10 },
    { id = "VERMILION_CITY", x = 10, y = 10 },
    { id = "ROUTE_12", x = 10, y = 15 },
    { id = "VIRIDIAN_MART", x = 3, y = 5 },
  }

  local function pass(dir, cacheOn)
    os.execute(('mkdir "%s" 2>nul'):format((OUT .. "/" .. dir):gsub("/", "\\")))
    BuildCache.setting:sync(cacheOn and "on" or "off")
    for _, c in ipairs(MAPS) do
      ChunkMesher.invalidate()
      restores, builds = 0, 0
      builtIds, misses = {}, {}
      local t0 = love.timer.getTime()
      if Scenes.visit(game, V, c, log, false) then
        log(("%s %-16s ready  restores=%d  analysis builds=%d  %.1f s")
            :format(dir, c.id, restores, builds, love.timer.getTime() - t0 - 1))
        if cacheOn and dir == "c" then
          log("   built:", table.concat(builtIds, " "), " missed:", table.concat(misses, " "))
        end
        Scenes.shot(OUT .. "/" .. dir, "shot_" .. c.id)
      end
    end
  end

  BuildCache.clear()
  pass("a", true)
  log(("cache after pass a: %.1f MB"):format(BuildCache.totalBytes() / 1048576))
  pass("b", false)
  pass("c", true)

  -- the verdicts the log reader wants
  BuildCache.setting:sync("on")
  H:finish()
  love.event.quit()
end
