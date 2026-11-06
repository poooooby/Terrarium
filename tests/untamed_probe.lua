-- Probe: Untamed Tohjo (goldenroddeptstore/untamed-tohjo, mod id
-- `overworldmons`) under the diorama.
--
-- UT puts wild Pokemon, a follower and their effects on the map as real
-- engine NPCs, which the 3D pass draws like any other figure. Three of its
-- things lean on parts of the 2D path the diorama did not copy:
--
--   the shiny SPARKLE   a 16x24, 21-frame sheet stood on the mon's own cell
--                       and animated through npc.frameOverride
--   the POKE BALL       a 3-frame sheet, the same way (Pokemon Center heal)
--   the EMOTE bubble    on Gen 1, a raw love.graphics.draw after
--                       OverworldState.drawWorld -- into the world canvas a
--                       pipeline's override skips
--
-- This stands a scene with all of them up on Route 1 and photographs it in
-- 3D and in flat 2D, and logs what every UT figure asks the renderer for.
--
--   python tools/profiler/run.py untamed_probe --with overworldmons --out ut
--
-- Rigged for a picture, NOT for play: every wild roll comes up shiny
-- (Stats.isShiny is pinned true for the run) and the fresh save is handed a
-- BULBASAUR so the follower has someone to be. Nothing is saved.
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "untamed" }))
  local log, V = H.log, H.V
  local Pipelines = require("src.render.Pipelines")

  -- every wanderer rolls shiny, so the sparkles are there to look at (UT
  -- caps them at three live)
  local okS, Stats = pcall(require, "src.pokemon.Stats")
  if okS and Stats and Stats.isShiny then
    Stats.isShiny = function() return true end
  end

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)
  V.require("CloudShade").setting:sync("off")
  V.require("Wind").setting:sync(0)

  local OverworldState = require("src.world.OverworldController")
  log("UT loaded:", tostring(OverworldState.__owmEmoteDrawHooked == true))

  -- a lead for the follower
  local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
  if okP and game.save then
    local okN, mon = pcall(Pokemon.new, game.data, "BULBASAUR", 5)
    if okN and mon then
      game.save.party = game.save.party or {}
      game.save.party[#game.save.party + 1] = mon
      log("party: BULBASAUR L5")
    else
      log("party: Pokemon.new failed:", tostring(mon))
    end
  end

  local function entities()
    return (game.overworld and game.overworld.entities) or {}
  end
  local function utFigures()
    local list = {}
    for _, e in ipairs(entities()) do
      local def = e.sprite and e.sprite.def
      local id = def and tostring(def.id or "")
      if id and id:match("^OWM_") then list[#list + 1] = e end
    end
    return list
  end
  local function report(tag)
    local figs = utFigures()
    log(("%s: %d UT figures"):format(tag, #figs))
    for _, e in ipairs(figs) do
      local d = e.sprite.def
      log(("  %-24s %2sx%-2s frames %-2s cols %s anchor %s,%s  cell %s,%s  px %s,%s  frameOverride %s"):format(
        tostring(d.id), tostring(d.frameWidth or 16), tostring(d.frameHeight or 16),
        tostring(d.frames), tostring(d.frameColumns or 1),
        tostring(d.anchorX), tostring(d.anchorY),
        tostring(e.cellX), tostring(e.cellY), tostring(e.px), tostring(e.py),
        tostring(e.frameOverride)))
    end
    return figs
  end

  local c = { id = "ROUTE_1", x = 9, y = 26 }
  if not Scenes.visit(game, V, c, log) then
    H:finish({ probe = "untamed" }); love.event.quit(); return
  end
  -- UT tops up its wanderers on arrival and every few seconds after; give
  -- it time, and walk a little so its step hooks run too
  local pace = Scenes.pacer(game)
  for i = 1, 240 do pace(i); coroutine.yield() end
  Scenes.wait(240)
  local figs = report("after spawn")

  -- bring the first shiny to the player: two cells to the right, on the
  -- open path the camera has in the middle of the frame (Route 1's canopy
  -- hides most of the map from a camera looking north). UT keeps its
  -- sparkle on the host's cell every frame, so moving the host moves both;
  -- moved in place, because a setMap would re-enter the map and UT would
  -- reroll its wanderers
  do
    local p = game.overworld.player
    local sparkle = nil
    for _, e in ipairs(figs) do
      if tostring(e.sprite.def.id) == "OWM_SPARKLE_SHEET" then sparkle = e; break end
    end
    for _, e in ipairs(figs) do
      if sparkle and e ~= sparkle and e.cellX == sparkle.cellX and e.cellY == sparkle.cellY then
        local tx, ty = p.cellX + 2, p.cellY
        e.cellX, e.cellY, e.px, e.py = tx, ty, tx * 16, ty * 16
        e.targetX, e.targetY, e.moving = nil, nil, false
        log(("shiny %s moved from %d,%d to %d,%d"):format(
          tostring(e.sprite.def.id), sparkle.cellX, sparkle.cellY, tx, ty))
        break
      end
    end
  end
  Scenes.wait(10)
  figs = report("shiny beside the player")

  -- the bubble: what UT puts in its own RUNTIME.gen1Emote when the follower
  -- reacts, set here directly (the reaction needs a facing and a press the
  -- probe cannot aim reliably). UT's own frame 0 of assets/vfx/emotes.png.
  local follower = nil
  for _, e in ipairs(figs) do
    if tostring(e.sprite.def.id):match("FOLLOWER") then follower = e end
  end
  -- UT's RUNTIME table, an upvalue of its OverworldState.drawWorld wrapper,
  -- which may be inside another wrapper (lib/WorldPostDraw.lua's), so the
  -- search follows function upvalues a few levels down. The probe runs as
  -- a driver, outside the mod sandbox, so it has the debug library; the
  -- mod itself does not (src/mods/Sandbox.lua), which is why the mod has to
  -- catch the bubble's draw rather than read this table.
  local function findRuntime(fn, depth, seen)
    if type(fn) ~= "function" or seen[fn] then return nil end
    seen[fn] = true
    for i = 1, 200 do
      local name, v = debug.getupvalue(fn, i)
      if not name then break end
      if name == "RUNTIME" and type(v) == "table" and v.setupGen1EmoteDraw then
        return v
      end
      if depth > 0 and type(v) == "function" then
        local r = findRuntime(v, depth - 1, seen)
        if r then return r end
      end
    end
    return nil
  end
  local runtime = findRuntime(OverworldState.drawWorld, 3, {})
  if follower and runtime then
    local okI, image = pcall(function()
      local path = "mods/overworldmons/assets/vfx/emotes.png"
      local data = love.image.newImageData(path)
      local out = love.image.newImageData(16, 16)
      out:paste(data, 0, 0, 0, 0, 16, 16)
      return love.graphics.newImage(out)
    end)
    if okI and image then
      runtime.gen1Emote = { hostNpc = follower, image = image, left = 1e9 }
      log("emote: set on the follower")
    else
      log("emote: image failed:", tostring(image))
    end
  else
    log("emote: follower", tostring(follower ~= nil), "runtime", tostring(runtime ~= nil))
  end

  -- a burst in 3D, then the same in flat 2D (the reference for what each
  -- figure should look like): the sparkle's cycle has blank frames, so one
  -- shot can catch it between glints
  local function burst(tag)
    for i = 1, 8 do
      Scenes.shot(OUT, ("ut_%s_%d"):format(tag, i))
      local line = {}
      for _, e in ipairs(utFigures()) do
        if tostring(e.sprite.def.id) == "OWM_SPARKLE_SHEET" then
          line[#line + 1] = tostring(e.frameOverride)
        end
      end
      log(("%s %d: sparkle frames %s"):format(tag, i, table.concat(line, " ")))
      Scenes.wait(18)
    end
  end
  Scenes.wait(30)
  burst("3d")
  Pipelines.setLevel("terrarium_voxel", 0)
  Scenes.wait(20)
  burst("2d")
  Pipelines.setLevel("terrarium_voxel", 4)
  Scenes.wait(30)

  -- THE RESKIN. UT repaints its follower with npc:setSpriteDef(def) on the
  -- UNBAKED def, whose image is an ImageData rather than a path (the engine
  -- takes either). The 3D pass keyed caches on def.image .. "#", threw on
  -- the userdata, and the engine retired the pipeline for the session --
  -- "render pipeline failed: VoxelScene.lua:1221: invalid value (userdata
  -- at index 382 in table for 'concat')". Counted here by the frames the
  -- pipeline still hands back a canvas.
  local delivered, asked = 0, 0
  local realDrawWorld = Pipelines.drawWorld
  Pipelines.drawWorld = function(...)
    asked = asked + 1
    local out = realDrawWorld(...)
    if out then delivered = delivered + 1 end
    return out
  end
  local reskinned = false
  if follower and follower.setSpriteDef then
    local okR, err = pcall(function()
      local def = follower.sprite.def
      local copy = {}
      for k, v in pairs(def) do copy[k] = v end
      local path = type(def.image) == "string" and def.image or nil
      copy.image = love.image.newImageData(path)
      copy.id = tostring(def.id) .. "_MEM"
      follower:setSpriteDef(copy)
    end)
    reskinned = okR
    log("reskin with an ImageData sheet:", okR and "done" or tostring(err))
  else
    log("reskin: no follower with setSpriteDef")
  end
  Scenes.wait(90)
  Scenes.shot(OUT, "ut_reskin")
  Pipelines.drawWorld = realDrawWorld
  local survived = asked > 0 and delivered == asked
  log(("after the reskin: pipeline delivered %d of %d frames"):format(delivered, asked))

  log((#figs > 0 and reskinned and survived) and "PASS"
      or ("FAIL: figures " .. #figs .. ", reskinned " .. tostring(reskinned)
          .. ", pipeline survived " .. tostring(survived)))
  H:finish({ probe = "untamed" })
  love.event.quit()
end
