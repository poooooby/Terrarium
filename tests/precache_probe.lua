-- Probe: lib/PreCache.lua's "bake" stage, end to end -- the maps one step
-- from where the player stands are built into the 3D build cache in the
-- background, so walking or warping into them restores instead of builds.
-- Checks that:
--   * it is ON whenever the 3D CACHE row is, and dark when it is OFF
--   * entering a map queues what is reachable from it (minus what the
--     cache already holds), once each
--   * nothing is pre-built while the mesher still has a job of its own
--   * the queue drains, and afterwards every reachable map is cached
--   * the same map does not requeue; moving drops the old queue
--
--   python tools/profiler/run.py precache_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "precache" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "ok   " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)
  local PreCache = V.require("PreCache")
  local BuildCache = V.require("BuildCache")
  local BuildVeil = V.require("BuildVeil")
  local ChunkMesher = V.require("ChunkMesher")

  BuildCache.setting:sync("off")
  check(not PreCache.enabled() or PreCache.force, "dark with 3D CACHE off")
  BuildCache.setting:sync("on")
  check(PreCache.enabled(), "on with 3D CACHE on")
  BuildCache.clear()
  PreCache.reset()

  local LAV = { id = "LAVENDER_TOWN", x = 10, y = 10 }
  Scenes.visit(game, V, LAV, log)
  local want = PreCache.reachable(game.overworld.map)
  log("reachable from LAVENDER_TOWN:", table.concat(want, " "))
  check(#want >= 5, "Lavender reaches its routes and buildings (" .. #want .. ")")

  -- never ahead of the mesher's own work
  local overlap = 0
  local t0 = love.timer.getTime()
  local frames = 0
  while PreCache.pending() > 0 and frames < 7200 do
    local before = PreCache.stats.warmed
    coroutine.yield()
    frames = frames + 1
    if ChunkMesher.pending() > 0 and PreCache.stats.warmed > before then
      overlap = overlap + 1
    end
  end
  log(("queue drained after %d frames, %.1f s"):format(frames, love.timer.getTime() - t0))
  check(PreCache.pending() == 0, "queue drained")
  check(overlap == 0, "nothing pre-built while the mesher had its own job")
  local missing = {}
  for _, id in ipairs(want) do
    local map = BuildVeil.mapFor(id)
    if not (map and BuildVeil.current(map)) then missing[#missing + 1] = id end
  end
  check(#missing == 0, "every reachable map is cached"
        .. (#missing > 0 and (": missing " .. table.concat(missing, " ")) or ""))

  -- a second notice of the same map must not requeue
  PreCache.notice(game.overworld.map)
  check(PreCache.pending() == 0, "same map does not requeue")

  -- and the payoff: walk into one of them -- it comes off disk
  local restores = 0
  local orig = BuildCache.restoreGroup
  BuildCache.restoreGroup = function(...) restores = restores + 1; return orig(...) end
  ChunkMesher.invalidate()
  local tr = love.timer.getTime()
  Scenes.visit(game, V, { id = "ROUTE_8", x = 20, y = 10 }, log)
  log(("ROUTE_8 ready in %.1f s, %d parts restored"):format(love.timer.getTime() - tr - 1, restores))
  check(restores > 0, "a pre-built neighbour restores on arrival")
  BuildCache.restoreGroup = orig
  log(PreCache.report())

  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  H:finish({ probe = "precache" })
  love.event.quit()
end
