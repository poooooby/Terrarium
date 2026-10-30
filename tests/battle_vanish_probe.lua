-- Probe: do the mons vanish mid-battle next to another battle-sprite mod?
--
-- Reported with g9-battle-sprites: a battle sprite disappears partway through
-- a fight. This plays several long wild battles (bulky mons on both sides,
-- A mashed so turns keep coming) and logs, frame by frame, every CHANGE in
-- what each side looks like to the 3D arena:
--   spr  what battler.sprite is (nil / path string / Image)
--   eng  whether the engine itself would draw that side this frame (its own
--        drawPicsLayer guards, minus the sprite test)
--   tex  whether OverworldBattle.textures produced a billboard for it
-- A side the engine would draw but that has no billboard is a VANISH; the
-- first one per side per battle is screenshotted, and the run ends with a
-- per-battle count of vanish frames.
--
--   python tools/profiler/run.py battle_vanish_probe --with g9-battle-sprites
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "battle_vanish" }))
  local log, V = H.log, H.V
  local function quit(code) log(code); H:finish({ probe = "battle_vanish" }); love.event.quit() end
  if not Scenes.boot(game, log) then return quit("FAIL boot") end
  Scenes.pin(V, log)
  local others = {}
  for id in pairs(game.mods and game.mods.exports or {}) do others[#others + 1] = id end
  table.sort(others)
  log("mods with exports:", table.concat(others, " "))

  local function sprKindEarly(bt)
    local s = bt and bt.sprite
    if s == nil then return "nil" end
    return type(s) == "string" and "path" or "img"
  end
  local OverworldBattle = V.require("OverworldBattle")
  local lastTex = { enemy = false, player = false }
  local dumpTex, dumpName = false, nil
  local innerTextures = OverworldBattle.textures
  OverworldBattle.textures = function(battle)
    local t = innerTextures(battle)
    lastTex.enemy = (t and t.enemy) and true or false
    lastTex.player = (t and t.player) and true or false
    if dumpTex and t and t.enemy and t.enemy.canvas then
      dumpTex = false
      local okI, data = pcall(t.enemy.canvas.newImageData, t.enemy.canvas)
      if okI and data then
        local fh = io.open(OUT .. "/" .. dumpName .. ".png", "wb")
        if fh then fh:write(data:encode("png"):getString()); fh:close() end
      end
    end
    return t
  end

  local IDLE = os.getenv("DS_VANISH_IDLE") ~= nil
  local Runtime = require("src.mods.Runtime")
  local function noUpdate() end
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  -- Outermost wrap of the pics layer (installed after every mod): how often
  -- the whole chain runs per frame, and what it does to the sprites.
  local layerCalls, layerNote = 0, ""
  local outerLayer = BattleState.drawPicsLayer
  log("g9 patched BattleState:", tostring(BattleState.__g9BattleSprites))
  BattleState.drawPicsLayer = function(self, ...)
    layerCalls = layerCalls + 1
    local b4e, b4p = sprKindEarly(self.enemy), sprKindEarly(self.player)
    local r1, r2, r3 = outerLayer(self, ...)
    layerNote = ("layer %s->%s / %s->%s"):format(b4e, sprKindEarly(self.enemy),
                                                 b4p, sprKindEarly(self.player))
    return r1, r2, r3
  end

  local function sprKind(s)
    if s == nil then return "nil" end
    if type(s) == "string" then return "path" end
    if type(s) == "userdata" then return "img" end
    return type(s)
  end
  local function engineDraws(b, side)
    if side == "enemy" then
      if b.showEnemyTrainer and b.trainerPic then return "trainer" end
      local e = b.enemy
      return (e and not b.enemyHidden and not b.enemySendingOut
              and not b:fxHidden(e)) and "y" or "n"
    end
    if b.showPlayerBack and b.playerBackPic then return "trainer" end
    local p = b.player
    return (p and not (b.safari or b.demo) and not b.sendingOut
            and not b:fxHidden(p)) and "y" or "n"
  end

  local FOES = { "MACHAMP", "GENGAR", "ONIX", "SNORLAX" }
  if os.getenv("DS_VANISH_ONE") then FOES = { "MACHAMP" } end
  local totals = {}
  for n, foe in ipairs(FOES) do
    game.save.party = { Pokemon.new(game.data, "CHANSEY", 40),
                        Pokemon.new(game.data, "SNORLAX", 40) }
    -- one HP: the first blow faints her, so every battle runs the
    -- faint -> "Use next POKeMON?" -> party menu -> send-out path
    game.save.party[1].hp = 1
    local ok, battle = pcall(BattleState.newWild, game, foe, 40)
    if not (ok and battle) or battle.dead then return quit("FAIL no battle") end
    game.overworld:pushBattle(battle)
    log(("== battle %d: CHANSEY vs %s"):format(n, foe))
    local prev, vanish, shotTaken = nil, { enemy = 0, player = 0 }, {}
    local f = 0
    -- A fainted mon asks for the next one: the party screen goes on top of
    -- the battle, and mashing A there only re-picks the fainted slot. On a
    -- new screen over the battle, step to the second slot once and confirm.
    local lastTop, script, burst, pushes = battle, {}, 0, 0
    local idleSince = nil
    while f < 3600 do
      f = f + 1
      local top = game.stack:top()
      if top ~= lastTop then
        lastTop = top
        log(("f%-5d top -> %s"):format(f, top == battle and "battle"
                                        or Scenes.describe(top)))
        if top ~= battle and top ~= game.overworld then
          -- first the "Use next POKeMON?" YES/NO (A = YES), then the party
          -- menu (second slot, SWITCH)
          pushes = pushes + 1
          script = pushes % 2 == 1 and { "up", "a" } or { "down", "a", "a" }
        end
        burst = 240     -- shoot the screens around every change of screen
      end
      -- DS_VANISH_IDLE: reported as happening with no input at all, just
      -- left on screen -- so once the command menu is up, stop pressing
      local idle = IDLE and battle.phase == "menu"
      if idle and not idleSince then
        idleSince = f
        log(("f%-5d idle from here: no more input"):format(f))
      end
      if f % 12 == 0 and not idleSince then
        local b = table.remove(script, 1) or "a"
        game.input.pressQueue[#game.input.pressQueue + 1] = b
      end
      if idleSince and f - idleSince < 600 and (f - idleSince) % 5 == 0 then
        dumpTex, dumpName = true, ("tex_b%d_f%04d"):format(n, f)
      end
      if idleSince and (f - idleSince) % 600 == 0 or (idleSince and f - idleSince < 600 and (f - idleSince) % 5 == 0) then
        Scenes.shot(OUT, ("idle_b%d_f%04d"):format(n, f))
      end
      coroutine.yield()
      -- Under POKEPORT_DRIVER the engine calls Game:update straight, never
      -- the core.update hook chain (gen1recomp main.lua, the driverCo loop),
      -- and that chain is where a sprite mod bakes its sheets. Run it here
      -- with a no-op vanilla step so the game is not updated twice.
      pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
      if game.stack:top() == game.overworld then break end
      if burst > 0 then
        burst = burst - 1
        if burst % 20 == 0 then
          Scenes.shot(OUT, ("b%d_f%04d_%s"):format(n, f, tostring(battle.phase)))
        end
      end
      if f % 300 == 0 then Scenes.shot(OUT, ("b%d_f%04d_%s"):format(n, f, tostring(battle.phase))) end
      if OverworldBattle.shot() then
        local row = {}
        for _, side in ipairs({ "enemy", "player" }) do
          local bt = battle[side]
          local eng = engineDraws(battle, side)
          local tex = lastTex[side]
          local dims = ""
          local sp = bt and bt.sprite
          if type(sp) == "userdata" and sp.getDimensions then
            local okD, w, h = pcall(sp.getDimensions, sp)
            if okD then dims = ("%dx%d"):format(w, h) end
          end
          local sc = ""
          if bt and bt.mon then
            local okS, v = pcall(BattleState.resolveBattleScale, game.data,
              side == "enemy" and "front" or "back", nil, bt.mon.species)
            if okS then sc = tostring(v) end
          end
          row[#row + 1] = ("%s spr=%s %s s=%s eng=%s tex=%s"):format(side:sub(1, 1),
            sprKind(sp), dims, sc, eng, tex and "y" or "n")
          if eng == "y" and not tex then
            vanish[side] = vanish[side] + 1
            if not shotTaken[side] then
              shotTaken[side] = true
              Scenes.shot(OUT, ("vanish_b%d_%s_f%d"):format(n, side, f))
            end
          end
        end
        local line = ("phase=%-12s %s  [%d calls, %s]"):format(tostring(battle.phase),
          table.concat(row, " | "), layerCalls, layerNote)
        layerCalls = 0
        if line ~= prev then log(("f%-5d %s"):format(f, line)); prev = line end
      elseif prev ~= "noshot" then
        prev = "noshot"
        log(("f%-5d phase=%-12s (no arena shot) e spr=%s p spr=%s"):format(f,
          tostring(battle.phase), sprKind(battle.enemy and battle.enemy.sprite),
          sprKind(battle.player and battle.player.sprite)))
      end
    end
    log(("battle %d over after %d frames: vanish frames enemy=%d player=%d")
        :format(n, f, vanish.enemy, vanish.player))
    totals[#totals + 1] = vanish.enemy + vanish.player
    for _ = 1, 20 do
      if game.stack:top() == game.overworld then break end
      pcall(game.stack.pop, game.stack); Scenes.wait(10)
    end
    Scenes.wait(30)
  end
  OverworldBattle.textures = innerTextures
  local sum = 0
  for _, v in ipairs(totals) do sum = sum + v end
  quit(sum == 0 and "PASS no vanish frames" or ("VANISH frames total " .. sum))
end
