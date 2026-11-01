-- Probe: the title page's 3D build prompt (lib/BuildVeil.lua) and the
-- in-game "Building voxels" badge (lib/BuildBadge.lua), end to end.
--
--   1. cache cleared, so this is a "first boot"
--   2. tap through the title to the CONTINUE / NEW GAME menu: the prompt
--      must come up on its own                          -> veil_ask.png
--   3. choose NEAREST: the veil builds the save's neighbourhood
--                                                        -> veil_build.png
--      and closes when done; every map it listed is then cached
--   4. the prompt must NOT come back (asked is remembered)
--   5. new game, then a warp to a map nothing built: the badge must show
--      over the 2D picture                               -> badge.png
--      and go once the map is in
--
-- Under POKEPORT_DRIVER the engine never runs the core.update hook chain,
-- which is where main.lua drives the prompt, so this runs it each frame
-- itself (tests/battle_vanish_probe.lua does the same for G9).
--
--   python tools/profiler/run.py build_veil_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local Runtime = require("src.mods.Runtime")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "build_veil" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "PASS " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end

  local function noUpdate() end
  -- one frame, with the hook chain the engine skips under a driver
  local function frame()
    pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
    coroutine.yield()
  end
  local function frames(n) for _ = 1, n do frame() end end
  local function tap(b)
    game.input.pressQueue[#game.input.pressQueue + 1] = b
    frame()
  end

  local BuildCache = V.require("BuildCache")
  local BuildVeil = V.require("BuildVeil")
  local BuildBadge = V.require("BuildBadge")
  local ChunkMesher = V.require("ChunkMesher")
  require("src.render.Pipelines").setLevel("terrarium_voxel", 4)

  -- 1. first boot
  BuildCache.clear()
  check(not BuildCache.asked(), "cache cleared, prompt not yet answered")

  -- 2. to the CONTINUE / NEW GAME menu
  local n = 0
  while not (game.stack and game.stack:top()) do frame(); n = n + 1 end
  local reached = false
  for _ = 1, 40 do
    local top = game.stack:top()
    if BuildVeil.active() then reached = true; break end
    if top and top.items then frames(10) else tap("start"); frames(20) end
  end
  check(reached and BuildVeil.active(), "the prompt came up on the title menu by itself")
  frames(5)
  Scenes.shot(OUT, "veil_ask")

  -- 3a. ALL, then B partway: the veil draws, and stopping keeps what is done
  tap("a")
  frames(40)
  Scenes.shot(OUT, "veil_build")
  local doneBefore = BuildCache.totalBytes()
  tap("b")
  frames(3)
  check(not BuildVeil.active(), "B stopped the ALL build")
  check(doneBefore > 0, ("what ALL had built so far stayed cached (%.1f MB)")
                        :format(doneBefore / 1048576))
  -- and again from the top, for NEAREST
  BuildCache.clear()
  BuildVeil.resetForProbe()
  for _ = 1, 30 do
    if BuildVeil.active() then break end
    frames(2)
  end
  check(BuildVeil.active(), "the prompt is back after the cache was cleared")

  -- 3b. NEAREST (second choice)
  tap("down"); frames(2); tap("a")
  local t0 = love.timer.getTime()
  frames(3)
  local guard = 0
  while BuildVeil.active() and guard < 20000 do frame(); guard = guard + 1 end
  local secs = love.timer.getTime() - t0
  check(not BuildVeil.active(), ("the veil closed after building (%.1f s)"):format(secs))
  local ids = BuildVeil.nearestIds(BuildVeil.saveMap())
  local cached = 0
  for _, id in ipairs(ids) do
    local map = BuildVeil.mapFor(id)
    if map and BuildVeil.current(map) then cached = cached + 1 end
  end
  log(("nearest set from %s: %s"):format(BuildVeil.saveMap(), table.concat(ids, " ")))
  check(cached == #ids, ("every NEAREST map cached and current (%d of %d)"):format(cached, #ids))
  check(BuildCache.asked(), "the answer is remembered")
  log(("cache: %.1f MB"):format(BuildCache.totalBytes() / 1048576))

  -- 4. would it ask again? (it must not: answered, nothing changed)
  local want = BuildVeil.wanted()
  check(not want, "no second prompt when nothing changed")

  -- 5. into the game, then somewhere nothing has built
  local ok = pcall(game.startNewGame, game, { intro = false })
  n = 0
  while not (game.overworld and game.stack:top() == game.overworld
             and game.overworld.map) and n < 600 do frame(); n = n + 1 end
  check(ok and game.overworld and game.overworld.map, "new game reached free roam")
  Scenes.pin(V, log)
  -- the start map was in the NEAREST set: it should come up from disk
  local tr = love.timer.getTime()
  n = 0
  while not ChunkMesher.peek(game.overworld.map, true)
        and not ChunkMesher.peek(game.overworld.map, false) and n < 600 do
    frame(); n = n + 1
  end
  log(("%s: 3D after %.2f s (%d frames)"):format(game.overworld.map.id,
      love.timer.getTime() - tr, n))
  check(n < 30, "the save's map came up from the cache within half a second")

  pcall(function() game.overworld:setMap("CERULEAN_CITY", 18, 18, "down") end)
  local seen = false
  for _ = 1, 120 do
    frame()
    if BuildBadge.showing() then seen = true end
    if seen and _ > 40 then break end
  end
  check(seen, "the badge showed on a map nothing had built")
  Scenes.shot(OUT, "badge")
  n = 0
  while BuildBadge.showing() and n < 3000 do frame(); n = n + 1 end
  check(not BuildBadge.showing(), "the badge went once the map was in")
  check(BuildCache.has(game.overworld.map, "body"), "and the build was written to the cache")

  -- 6. staleness: a geometry row flip makes cached maps miss, and back
  local pallet = BuildVeil.mapFor("PALLET_TOWN")
  check(BuildCache.has(pallet, "body"), "Pallet is cached")
  local TowerKit = V.require("TowerKit")
  local was = TowerKit.setting:get()
  TowerKit.setting:sync(was == "new" and "classic" or "new")
  check(not BuildCache.has(pallet, "body"), "flipping TOWER STYLE makes it miss")
  TowerKit.setting:sync(was)
  check(BuildCache.has(pallet, "body"), "flipping it back hits again")

  -- 7. a damaged file is a miss, never a crash, and is dropped
  V.mod.cache:write("maps/PALLET_TOWN.body.bin", "not a cache file at all")
  local okL, layout = pcall(BuildCache.load, pallet, "body")
  check(okL and layout == nil, "a damaged file loads as a miss")
  check(not BuildCache.has(pallet, "body"), "and is dropped from the index")
  local bytes = V.mod.cache:read("maps/PALLET_TOWN.aux.bin")
  if bytes then
    V.mod.cache:write("maps/PALLET_TOWN.aux.bin", bytes:sub(1, #bytes - 40))
    local okT, lt = pcall(BuildCache.load, pallet, "aux")
    check(okT and lt == nil, "a truncated file loads as a miss")
  end

  log(fails == 0 and "PASS all" or ("FAIL %d checks"):format(fails))
  H:finish()
  love.event.quit()
end
