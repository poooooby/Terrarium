-- Probe: do the mons vanish when the attack menu opens?
--
-- Reported 2026-10-29 (with g9-battle-sprites): the battle sprites disappear
-- when the player opens the attack (move) menu. This enters a wild battle,
-- opens FIGHT the same way battle_theme_probe does, then holds the move list
-- for ten seconds with no input, logging every change in what each side
-- looks like to the arena and screenshotting once a second.
--
--   python tools/profiler/run.py moves_menu_probe --with g9-battle-sprites
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "moves_menu" }))
  local log, V = H.log, H.V
  local function quit(msg) log(msg); H:finish({ probe = "moves_menu" }); love.event.quit() end
  if not Scenes.boot(game, log) then return quit("FAIL boot") end
  local Runtime = require("src.mods.Runtime")
  local function noUpdate() end
  local function step(n)
    for _ = 1, n or 1 do
      coroutine.yield()
      pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
    end
  end

  local OverworldBattle = V.require("OverworldBattle")
  local tex = { enemy = false, player = false }
  local innerTextures = OverworldBattle.textures
  OverworldBattle.textures = function(b)
    local t = innerTextures(b)
    tex.enemy = (t and t.enemy) and true or false
    tex.player = (t and t.player) and true or false
    return t
  end

  -- textures() pcalls each side and drops a failure to nil: catch the error
  local errs, errN = {}, 0
  local innerSide = OverworldBattle.sideTexture
  OverworldBattle.sideTexture = function(b, side)
    local okS, r = pcall(innerSide, b, side)
    if not okS then
      local msg = tostring(r)
      if not errs[msg] then
        errs[msg] = true
        errN = errN + 1
        if errN <= 5 then log(("sideTexture(%s) ERROR: %s"):format(side, msg)) end
      end
      error(r, 0)
    end
    return r
  end

  -- DS_MOVES_MAP: fight somewhere else (the report: a cave)
  local mapId = os.getenv("DS_MOVES_MAP")
  if mapId then
    local okV = Scenes.visit(game, V, { id = mapId, x = 10, y = 10 }, log)
    log(("on %s: %s"):format(mapId, tostring(okV)))
  end

  local Pokemon = require("src.pokemon.Pokemon")
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 22) }
  local BattleState = require("src.battle.BattleState")
  local ok, battle = pcall(BattleState.newWild, game, "RATTATA", 9)
  if not (ok and battle) or battle.dead then return quit("FAIL no battle") end
  game.overworld:pushBattle(battle)

  local function reach(want)
    for _ = 1, 40 do
      if battle.phase == want then return true end
      Scenes.tap(game, "a"); step(12)
    end
    return battle.phase == want
  end
  if not reach("menu") then return quit("FAIL never reached the command menu") end
  battle.menuIndex = 1
  step(60)
  -- let go of everything the taps left held, then one clean A into FIGHT
  local st = game.input.state
  for _, d in ipairs({ "a", "b", "up", "down", "left", "right" }) do st[d] = false end
  game.input.pressQueue = {}
  log("command menu up; both sides: enemy=" .. tostring(tex.enemy)
      .. " player=" .. tostring(tex.player))
  Scenes.shot(OUT, "menu")
  Scenes.tap(game, "a")
  for _ = 1, 60 do
    if battle.phase == "moveSelect" then break end
    step(1)
  end
  st.a = false
  log("phase now " .. tostring(battle.phase))

  -- every push and pop in the frame, tallied by the line that made it, so
  -- an unbalanced caller shows up by name
  local tally = {}
  local gpush, gpop = love.graphics.push, love.graphics.pop
  local function where()
    local i = debug.getinfo(3, "Sl")
    return i and (i.short_src:match("[^/\\]+$") .. ":" .. i.currentline) or "?"
  end
  love.graphics.push = function(...)
    local k = where(); local t = tally[k] or { 0, 0 }; tally[k] = t; t[1] = t[1] + 1
    return gpush(...)
  end
  love.graphics.pop = function(...)
    local k = where(); local t = tally[k] or { 0, 0 }; tally[k] = t; t[2] = t[2] + 1
    return gpop(...)
  end
  local prev, gone = nil, { enemy = 0, player = 0 }
  -- DS_MOVES_STEER: walk the cards right and left every half second
  local steer = os.getenv("DS_MOVES_STEER") ~= nil
  local dirs = { "right", "right", "right", "left", "left", "left" }
  for f = 1, 600 do
    if steer and f % 30 == 0 then
      Scenes.tap(game, dirs[(f / 30 - 1) % #dirs + 1])
      st.right, st.left = false, false
    end
    step(1)
    for _, side in ipairs({ "enemy", "player" }) do
      if not tex[side] then gone[side] = gone[side] + 1 end
    end
    local bt = battle.player
    local line = ("phase=%s enemy=%s player=%s p.spr=%s hidden=%s sendingOut=%s")
      :format(tostring(battle.phase), tostring(tex.enemy), tostring(tex.player),
              type(bt and bt.sprite), tostring(bt and battle:fxHidden(bt)),
              tostring(battle.sendingOut))
    if line ~= prev then log(("f%-4d %s"):format(f, line)); prev = line end
    if f % 60 == 0 then Scenes.shot(OUT, ("moves_f%03d"):format(f)) end
  end
  love.graphics.push, love.graphics.pop = gpush, gpop
  -- file-level balance: pushes and pops per source file
  local byFile = {}
  for k, t in pairs(tally) do
    local f = k:match("^(.-):%d+$") or k
    local b = byFile[f] or { 0, 0 }; byFile[f] = b
    b[1], b[2] = b[1] + t[1], b[2] + t[2]
  end
  for f, b in pairs(byFile) do
    log(("push/pop %-32s pushes %6d pops %6d net %+d"):format(f, b[1], b[2], b[1] - b[2]))
  end
  OverworldBattle.textures = innerTextures
  OverworldBattle.sideTexture = innerSide
  quit(("%s: frames without a billboard in the move menu: enemy %d, player %d")
       :format((gone.enemy + gone.player) == 0 and "PASS" or "GONE",
               gone.enemy, gone.player))
end
