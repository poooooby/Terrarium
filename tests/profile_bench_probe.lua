-- Probe: the profiling bench. Walks the Scenes.MAPS palindrome (forward,
-- then reverse in the same process, which cancels the monotonic drift
-- this engine shows between the first and last phase of a run), with a
-- stand-still and a pacing segment per map, and writes:
--
--   <DS_PROBE_DIR>/profile_bench.log         per-segment report
--   <DS_PROBE_DIR>/profile_bench_perf.json   Perf's tables (diffable)
--   <DS_PROBE_DIR>/profile_bench.json        AppleCake trace -> ui.perfetto.dev
--   <DS_PROBE_DIR>/shot_<map>.png            one frame per map, first pass
--
-- DS_TRACE=0 skips the AppleCake trace (Perf's tables only).
--
--   POKEPORT_VERSION=yellow DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/<id>/tests/profile_bench_probe.lua love .
-- (python tools/profiler/run.py profile_bench_probe does this, Terrarium only.)
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local trace = os.getenv("DS_TRACE") ~= "0"
  local H = assert(Harness.attach(game, { out = OUT, name = "profile_bench" }))
  local log = H.log
  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(H.V, log)
  if trace then
    H:startTrace()
    H:useSink(true)
  end
  local Perf = H.Perf

  local STAND, WALK = 300, 300

  local function run(c, pass)
    Perf.setSegment(nil)
    if not Scenes.visit(game, H.V, c, log) then return end
    if pass == 1 then Scenes.shot(OUT, "shot_" .. c.id) end
    H:mark(c.id .. ":stand")
    Perf.setSegment(c.id .. ":stand")
    Perf.resync()
    for _ = 1, STAND do coroutine.yield(); H:frame() end
    if c.walk ~= false then
      H:mark(c.id .. ":walk")
      Perf.setSegment(c.id .. ":walk")
      local pace = Scenes.pacer(game)
      for i = 1, WALK do pace(i); coroutine.yield(); H:frame() end
    end
    Perf.setSegment(nil)
  end

  for i = 1, #Scenes.MAPS do run(Scenes.MAPS[i], 1) end
  for i = #Scenes.MAPS, 1, -1 do run(Scenes.MAPS[i], 2) end

  Scenes.unpin()
  H:finish({ probe = "profile_bench", stand = STAND, walk = WALK })
  love.event.quit()
end
