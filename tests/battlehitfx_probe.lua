-- Probe: do hits land on the mon that was struck, and does HIT FRAMES
-- actually switch them?
--
-- Written against a user report (1.52.2): "hit frames only show the
-- player's mon getting hit, not the other, and the option does not turn it
-- off or on". Both were real. The defender was the attacker latched at the
-- move's start, flipped -- and anything that skipped that edge left it at
-- clear()'s false, so the blow went on the player. And every battle path
-- forced its way past the row. The claims:
--
--   1. ON (the default): a thrown move puts a tagged battle Vfx in the shot.
--   2. BOTH SIDES: over several rounds, hits land on the player AND on the
--      foe, and every landed hit is on the side whose bar was draining
--      when it landed (BattleHitFX.debug().lastHitSide against the bars).
--   3. Same with the engine's ANIMATIONS option OFF -- the flash/shake path,
--      which has no anim and so no start edge for a latch to read.
--   4. OFF: a round with the row OFF plays no battle Vfx and leaves no
--      marks or damage figures behind.
--
-- Both mons are healed at every command menu so the fight runs as many
-- rounds as asked; that writes nothing but the in-memory battle of a save
-- that is never written (Scenes.boot).
--
--   python tools/profiler/run.py battlehitfx_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "battlehitfx" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "PASS: " or "FAIL: ") .. what)
    if not ok then fails = fails + 1 end
  end
  local function quit()
    log(fails == 0 and "PASS" or ("FAIL x" .. fails))
    H:finish({ probe = "battlehitfx" }); love.event.quit()
  end
  if not Scenes.boot(game, log) then return quit() end
  Scenes.pin(V, log)

  local HitFX = V.require("BattleHitFX")
  local Vfx = V.require("Vfx")
  local OverworldBattle = V.require("OverworldBattle")
  log("3D battles:", tostring(OverworldBattle.enabled()))
  log("HIT FRAMES at boot:", Vfx.level())
  check(Vfx.level() == "on" or Vfx.level() == "off",
        "HIT FRAMES reads a value")

  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  local function draining(b)
    return b and b.mon and b.shownHP and b.shownHP > b.mon.hp or false
  end
  local function heal(b)
    if b and b.mon then
      local mx = (b.mon.stats and b.mon.stats.hp) or b.mon.maxHP or b.mon.hp
      b.mon.hp = mx
      if b.shownHP then b.shownHP = mx end
    end
  end

  -- one fight of `rounds` rounds; returns what it saw
  local function fight(label, rounds)
    -- bulky on both sides and TACKLE only, so a round is two blows: the
    -- first run of this probe drew a status move in slot 1 and the foe
    -- was never touched for a reason that had nothing to do with the FX
    local function tackleOnly() return { { id = "TACKLE", pp = 35 } } end
    local mine = Pokemon.new(game.data, "SNORLAX", 50)
    mine.moves = tackleOnly()
    game.save.party = { mine }
    local ok, battle = pcall(BattleState.newWild, game, "SNORLAX", 50)
    if not (ok and battle) or battle.dead then
      check(false, label .. ": wild battle starts"); return nil
    end
    if battle.enemy and battle.enemy.mon then
      battle.enemy.mon.moves = tackleOnly()
      battle.enemy.curMoves = battle.enemy.mon.moves
    end
    game.overworld:pushBattle(battle)
    local function reach(want)
      for _ = 1, 40 do
        if battle.phase == want then return true end
        Scenes.tap(game, "a"); Scenes.wait(12)
      end
      return battle.phase == want
    end
    local seen = { player = 0, enemy = 0, wrong = 0, live = 0,
                   marks = 0, tags = 0, landed = 0 }
    local lastCount = { player = 0, enemy = 0 }
    local shotDone = false
    for r = 1, rounds do
      if not reach("menu") then
        log(label .. ": no command menu at round " .. r
            .. " (phase=" .. tostring(battle.phase) .. ")")
        break
      end
      heal(battle.player); heal(battle.enemy)
      battle.menuIndex = 1
      Scenes.wait(10)
      if not reach("moveSelect") then
        log(label .. ": no move select at round " .. r
            .. " (phase=" .. tostring(battle.phase) .. ")")
        break
      end
      Scenes.wait(8)
      for _, b in ipairs({ battle.player, battle.enemy }) do
        for _, m in ipairs((b and b.curMoves) or {}) do m.pp = 35 end
      end
      local okc, why = pcall(battle.chooseMove, battle, 1)
      if not okc then log(label .. ": chooseMove failed: " .. tostring(why)) end
      local menuRun = 0
      for _ = 1, 2400 do
        local d = HitFX.debug()
        seen.live = math.max(seen.live, (Vfx.battleCount and Vfx.battleCount()) or 0)
        seen.marks = math.max(seen.marks, d.marks or 0)
        seen.tags = math.max(seen.tags, d.tags or 0)
        local hp, he = d.hitsOn.player or 0, d.hitsOn.enemy or 0
        for side, now in pairs({ player = hp, enemy = he }) do
          if now > lastCount[side] then
            -- a hit was just put on `side`: was that the bar draining?
            local pDr, eDr = draining(battle.player), draining(battle.enemy)
            local bar = (pDr and not eDr and "player")
                        or (eDr and not pDr and "enemy") or "?"
            log(("%s r%d: hit on %-6s  bar=%-6s anim=%s attackerIsPlayer=%s key=%s")
                :format(label, r, side, bar, tostring(battle.animName),
                        tostring(battle.animAttackerIsPlayer),
                        tostring(d.hitKey)))
            if bar ~= "?" and bar ~= side then seen.wrong = seen.wrong + 1 end
            seen[side] = seen[side] + (now - lastCount[side])
            seen.landed = seen.landed + (now - lastCount[side])
            lastCount[side] = now
            if not shotDone then
              Scenes.shot(OUT, label .. "_hit"); shotDone = true
            end
          end
        end
        if battle.dead then break end
        menuRun = (battle.phase == "menu") and (menuRun + 1) or 0
        if menuRun >= 12 then break end
        coroutine.yield()
      end
      if battle.dead then log(label .. ": battle ended in round " .. r) break end
    end
    pcall(function() battle.dead = true end)
    for _ = 1, 30 do
      if game.stack:top() == game.overworld then break end
      pcall(function() game.stack:pop() end)
      Scenes.wait(4)
    end
    Scenes.wait(20)
    log(("%s: hits player=%d enemy=%d wrong-side=%d  max live=%d marks=%d tags=%d")
        :format(label, seen.player, seen.enemy, seen.wrong, seen.live,
                seen.marks, seen.tags))
    return seen
  end

  local opts = game.save.options or {}
  game.save.options = opts
  local hadAnims = opts.animations

  -- ------- 1 + 2: ON, animations ON
  Vfx.setting:sync("on")
  opts.animations = true
  local a = fight("anims_on", 6)
  if a then
    check(a.live > 0, "ON: a thrown move puts a battle Vfx in the shot")
    check(a.player > 0, "anims ON: a hit landed on the player's mon")
    check(a.enemy > 0, "anims ON: a hit landed on the foe")
    check(a.wrong == 0, "anims ON: every hit is on the side whose bar drained")
  end

  -- ------- 3: ON, animations OFF (the flash/shake path, no start edge)
  opts.animations = false
  local b = fight("anims_off", 6)
  if b then
    check(b.player > 0, "anims OFF: a hit landed on the player's mon")
    check(b.enemy > 0, "anims OFF: a hit landed on the foe")
    check(b.wrong == 0, "anims OFF: every hit is on the side whose bar drained")
  end

  -- ------- 4: OFF
  opts.animations = true
  Vfx.setting:sync("off")
  local c = fight("row_off", 3)
  if c then
    check(c.live == 0, "OFF: no battle Vfx plays")
    check(c.landed == 0, "OFF: no hit is put on anyone")
    check(c.marks == 0 and c.tags == 0, "OFF: no marks or damage figures")
  end

  Vfx.setting:sync("on")
  opts.animations = hadAnims
  return quit()
end
