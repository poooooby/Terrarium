-- Probe: the lifecycle reports, and one real scenario per lifecycle fix.
-- (assets/docs/state-machines.md is the catalogue this proves.)
--
--   python tools/profiler/run.py state_report_probe
--
-- Every scenario drives the real game. Each is written so the bug it guards
-- would fail it: the soft reset really pops a live battle, the atlas really
-- throws once, the mesh build really fails. Boots on a fresh in-memory save
-- (Scenes.boot); run.py restores options.lua, which the FULL scenario writes.
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "state_report" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "PASS: " or "FAIL: ") .. what)
    if not ok then fails = fails + 1 end
  end
  local function quit()
    log(fails == 0 and "PASS" or ("FAIL x" .. fails))
    H:finish({ probe = "state_report" }); love.event.quit()
  end
  local function step(n) for _ = 1, n or 1 do coroutine.yield() end end

  local StateReport = V.require("StateReport")
  -- A typo'd expectation must not pass by never matching, so the state is
  -- checked against the declaration before it is compared.
  local function is(name, want)
    local got, detail = StateReport.state(name)
    check(StateReport.declares(name, want) and got == want,
          ("%s is %s (got %s%s)"):format(name, want, tostring(got),
                                         detail and (", " .. tostring(detail)) or ""))
  end
  local function allValid(where)
    local bad = {}
    for _, r in ipairs(StateReport.all()) do
      log(("  %-18s %s%s"):format(r.name, r.state, r.detail and ("  " .. r.detail) or ""))
      if r.state == "error" or r.state:sub(1, 1) == "?" then
        bad[#bad + 1] = r.name .. "=" .. r.state .. " " .. tostring(r.detail)
      end
    end
    check(#bad == 0, where .. ": every report answers a declared state " .. table.concat(bad, "; "))
  end

  if not Scenes.boot(game, log) then return quit() end
  Scenes.pin(V, log)
  local BuildCache = V.require("BuildCache")
  BuildCache.setting:sync("off")
  local Pipelines = require("src.render.Pipelines")
  local c = { id = "PALLET_TOWN", x = 10, y = 11 }
  if not Scenes.visit(game, V, c, log) then return quit() end

  -- ------- free roam
  log("--- free roam")
  allValid("free roam")
  is("world.freeroam", "freeroam")
  is("pipeline.voxel", "eligible")
  is("scene.gate", "on")
  is("scene.mesh", "ready")
  is("battle.session", "none")
  is("battle.nav", "retired")
  is("battle.exit", "idle")

  -- ------- the atlas retry: one throw must not condemn the tileset
  --
  -- Pins behaviour that already held. animate()'s
  -- `(entry == false) and false or attemptFailed(key)` always takes the
  -- attemptFailed arm, so even a `false` from newEntry spends the retry
  -- budget. Worth keeping: tidying that idiom would make this fail.
  log("--- atlas retry")
  do
    local TerrainAtlas = V.require("TerrainAtlas")
    local map = game.overworld.map
    local base = map.renderer.image
    TerrainAtlas.invalidate()
    -- Only a call made from TerrainAtlas itself: the renderer's pixel paths
    -- allocate inside their own pcalls on the way in, and a throw landing
    -- there would be a different miss.
    local real, thrown = love.graphics.newImage, 0
    love.graphics.newImage = function(...)
      local from = debug.getinfo(2, "S")
      if thrown == 0 and from and from.source:find("TerrainAtlas", 1, true) then
        thrown = 1
        error("probe: one failed texture")
      end
      return real(...)
    end
    local first = TerrainAtlas.forMap(map, nil)
    love.graphics.newImage = real
    local second = TerrainAtlas.forMap(map, nil)
    check(thrown == 1, "the throw was reached inside the build")
    check(first == base and second ~= base,
          "a throw is retried, and the next try animates")
    step(5)
  end

  -- ------- the weather: `kind` outlives the fade
  log("--- weather fade")
  do
    local Weather = V.require("Weather")
    local function falling() return Weather.falling() end
    Weather.setting:sync("rain")
    for _ = 1, 3000 do
      local _, p = falling()
      if (p or 0) > 0.06 then break end
      step()
    end
    local kind0, p0 = falling()
    check(kind0 == "rain" and (p0 or 0) > 0.05, "a pinned shower builds")
    is("weather.spell", "pinned")
    Weather.setting:sync("auto")
    step(3)
    local kind1, p1 = falling()
    check(kind1 == "rain" and (p1 or 0) > 0,
          ("leaving the pin, rain keeps falling through the fade (%s, %s)")
            :format(tostring(kind1), tostring(p1)))
    is("weather.spell", "fading")
    for _ = 1, 3000 do
      local _, p = falling()
      if (p or 0) <= 0 then break end
      step()
    end
    local kind2, p2 = falling()
    check(kind2 == nil and (p2 or 0) == 0, "and the fade ends with nothing falling")
    Weather.setting:sync("off")
    step(3)
  end

  -- ------- FULL holds DAYTIME against the manager page, on disk too
  log("--- FULL and the manager page")
  do
    local Voxel = V.require("VoxelState")
    local DayNight = V.require("DayNight")
    local Runtime = require("src.mods.Runtime")
    Pipelines.setLevel("terrarium_voxel", Voxel.FULL_LEVEL)
    step(5)
    is("preset.full", "on")
    local id = V.mod.id
    local opts = game.save.options
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[id] = opts.modOptions[id] or {}
    opts.modOptions[id].daytime = "night"   -- what the manager persists
    Runtime.emit("mod.options_changed", { mod = id, key = "daytime", value = "night" })
    step(2)
    check(DayNight.setting:get() == "sync", "FULL snaps the live row back to SYNC")
    check(opts.modOptions[id].daytime == "sync",
          ("and the saved value agrees (%s)"):format(tostring(opts.modOptions[id].daytime)))
    Pipelines.setLevel("terrarium_tiltshift", 0)
    Scenes.pin(V, log)
    step(90)
    is("preset.full", "off")
  end

  -- ------- a mesh build that fails says so, and the badge lets go
  log("--- mesh failure")
  do
    local ChunkMesher = V.require("ChunkMesher")
    local Structures = V.require("Structures")
    local BuildBadge = V.require("BuildBadge")
    local MapLoader = require("src.world.MapLoader")
    -- a map nothing is drawing, so a failure cannot reach the live scene
    local far = MapLoader.load(game.data, "CELADON_CITY")
    local real = Structures.forMap
    Structures.forMap = function(m, ...)
      if m and m.id == far.id then error("probe: this build fails") end
      return real(m, ...)
    end
    -- main.lua notes the LIVE map every frame, which would clear a badge
    -- following any other: silenced for the scenario, called by hand
    local note = BuildBadge.note
    BuildBadge.note = function() end
    BuildBadge.reset()
    ChunkMesher.request(far, false)
    check(ChunkMesher.status(far.id, "full") == "queued", "a requested build is queued")
    note(far, false)
    check(BuildBadge.showing(), "the badge picks the build up")
    for _ = 1, 600 do
      if not ChunkMesher.building(far.id) then break end
      step()
    end
    Structures.forMap = real
    local st, why = ChunkMesher.status(far.id, "full")
    check(st == "failed", ("the build reports failed (%s: %s)"):format(tostring(st), tostring(why)))
    note(far, false)
    check(not BuildBadge.showing(), "and the badge drops instead of creeping to 95%")
    BuildBadge.note = note
    BuildBadge.reset()
  end

  -- ------- the Colors prompt, popped from under itself
  log("--- soft reset under the Colors prompt")
  do
    local ColorsPrompt = V.require("ColorsPrompt")
    local PaletteFX = require("src.render.PaletteFX")
    local Runtime = require("src.mods.Runtime")
    -- the core.update hook does not fire under a driver, so it is called by
    -- hand, as tests/colors_prompt_probe.lua does
    local function tick(n)
      for _ = 1, n do
        pcall(Runtime.call, "core.update", function() end, game, 1 / 60)
        step()
      end
    end
    local mode, settle = PaletteFX.mode, ColorsPrompt.SETTLE
    ColorsPrompt.resetForProbe()
    ColorsPrompt.SETTLE, PaletteFX.mode = 0, "gbc"
    for _ = 1, 120 do
      if ColorsPrompt.active() then break end
      tick(1)
    end
    check(ColorsPrompt.active(), "the prompt came up")
    game:returnToTitle()
    tick(10)
    check(not ColorsPrompt.active(), "a soft reset clears it")
    PaletteFX.mode, ColorsPrompt.SETTLE = mode, settle
  end

  if not Scenes.boot(game, log) then return quit() end
  Scenes.pin(V, log)
  c = { id = "PALLET_TOWN", x = 10, y = 11 }
  if not Scenes.visit(game, V, c, log) then return quit() end

  -- ------- a staged battle, and a soft reset in the middle of it
  log("--- staged battle")
  do
    local Pokemon = require("src.pokemon.Pokemon")
    local BattleState = require("src.battle.BattleState")
    local OverworldBattle = V.require("OverworldBattle")
    local Grass3D = V.require("Grass3D")
    OverworldBattle.setting:sync(true)
    local realSplat, landings = Grass3D.splat, 0
    Grass3D.splat = function(x, z, r, s, ...)
      if r == 22 and s == 1.35 then landings = landings + 1 end
      return realSplat(x, z, r, s, ...)
    end
    game.save.party = { Pokemon.new(game.data, "SNORLAX", 50) }
    local ow = game.overworld
    local cast = ow.entities
    local battle = BattleState.newWild(game, "RATTATA", 5)
    ow:pushBattle(battle)
    for _ = 1, 80 do
      if battle.phase == "menu" then break end
      Scenes.tap(game, "a"); step(12)
    end
    step(30)
    check(battle.phase == "menu", "the fight reached its command menu")
    allValid("in battle")
    is("world.freeroam", "covered")
    local session = StateReport.state("battle.session")
    check(session == "staged" or session == "in-frame",
          "the arena is staged (" .. tostring(session) .. ")")
    check(StateReport.state("battle.nav") == "menu", "the costume owns the D-pad on the menu")
    check(landings == 2, ("two landing splats for the whole arrival (%d)"):format(landings))
    Grass3D.splat = realSplat

    -- the soft reset: every screen popped, nothing emitted
    game:returnToTitle()
    step(3)
    is("battle.session", "none")
    is("battle.nav", "retired")
    check(OverworldBattle.shot() == nil, "nothing is staged behind the title")
    check(ow.entities == cast, "the map's cast is back, by identity")
    allValid("on the title")
  end

  -- ------- and a new game after it starts clean
  log("--- new game after the reset")
  if not Scenes.boot(game, log) then return quit() end
  step(60)
  is("world.freeroam", "freeroam")
  is("battle.session", "none")
  do
    local ow, found = game.overworld, false
    for _, e in ipairs(ow.entities or {}) do
      if e == ow.player then found = true end
    end
    check(found, "the player stands in the new map's cast")
  end
  allValid("after the reset")
  BuildCache.setting:sync("on")
  return quit()
end
