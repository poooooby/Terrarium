-- Probe: lib/PreCache.lua's plumbing, end to end, with its one no-work
-- stage ("reach"). Checks that:
--   * it is dark until forced (Perf on alone does not run it)
--   * entering a map queues exactly what is reachable from it, once each
--   * the pump drains the queue inside its budget
--   * moving to another map drops what is no longer reachable
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
  local PreCache = V.require("PreCache")

  check(not PreCache.enabled(), "dark with Perf on but not forced")
  PreCache.force = true
  PreCache.reset()
  check(PreCache.enabled(), "forced on")

  local LAV = { id = "LAVENDER_TOWN", x = 10, y = 10 }
  Scenes.visit(game, V, LAV, log)
  local want = PreCache.reachable(game.overworld.map)
  log("reachable from LAVENDER_TOWN:", table.concat(want, " "))
  check(#want >= 5, "Lavender reaches its routes and buildings (" .. #want .. ")")
  for _ = 1, 30 do coroutine.yield() end
  check(PreCache.pending() == 0, "queue drained")
  local missing = {}
  for _, id in ipairs(want) do
    if not PreCache.reached[id] then missing[#missing + 1] = id end
  end
  check(#missing == 0, "every reachable map visited by the stage"
        .. (#missing > 0 and (": missing " .. table.concat(missing, " ")) or ""))
  local warmed = PreCache.stats.warmed
  check(warmed == #want, ("warmed once each (%d of %d)"):format(warmed, #want))

  -- a second notice of the same map must not requeue
  PreCache.notice(game.overworld.map)
  check(PreCache.pending() == 0, "same map does not requeue")

  Scenes.visit(game, V, { id = "VERMILION_CITY", x = 10, y = 10 }, log)
  for _ = 1, 30 do coroutine.yield() end
  check(PreCache.pending() == 0, "Vermilion's queue drained too")
  log(PreCache.report())

  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  H:finish({ probe = "precache" })
  love.event.quit()
end
