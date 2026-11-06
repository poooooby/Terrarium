-- Probe: the battle UI fixes of 2026-11-05, in a real fight.
--
--   1. POPS. The message panel pops once per message (BattlePanelsXY
--      _msgIdentity): never again over a message whose lines linger under
--      its move animation or a hold after A, never twice for one item.
--   2. TEXT. The box shows the engine's two-line window cut by glyphs
--      (BattleBoxXY._engineLines): every line the engine has finished
--      typing reads exactly as the engine's own text, and no control
--      character (\n, \v) ever reaches the font.
--   3. SIGNS. NIDORAN's sign stays in its name, and a mon a mod gave a
--      gender to gets its mark (BattleHudXY.genderName), once.
--   4. SCALE. Opening the party mid-battle keeps the battle's scale, with
--      g9-battle-sprites' 640x576 party screen in the stack
--      (BattleScene.fitScale).
--
--   python tools/profiler/run.py battleui_probe --with g9-battle-sprites
--
-- Both mons are healed at each command menu; the save is never written
-- (Scenes.boot).
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "battleui" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "PASS: " or "FAIL: ") .. what)
    if not ok then fails = fails + 1 end
  end
  local function quit()
    log(fails == 0 and "PASS" or ("FAIL x" .. fails))
    H:finish({ probe = "battleui" }); love.event.quit()
  end
  if not Scenes.boot(game, log) then return quit() end
  Scenes.pin(V, log)

  local Panels = V.require("BattlePanelsXY")
  local Box = V.require("BattleBoxXY")
  local Hud = V.require("BattleHudXY")
  local Scene = V.require("BattleScene")
  local Renderer = require("src.render.Renderer")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local MALE, FEMALE = "\xe2\x99\x82", "\xe2\x99\x80"

  -- ------- 1: every pop, against the messages the engine started
  local started, seenItem, poppedItem = 0, {}, {}
  local startMessage = BattleState.startMessage
  BattleState.startMessage = function(self, item, ...)
    if type(item) == "table" and not seenItem[item] then
      seenItem[item] = true
      started = started + 1
    end
    return startMessage(self, item, ...)
  end
  local calls, pops, bad = 0, 0, 0
  local realIdentity = Panels._msgIdentity
  Panels._msgIdentity = function(battle, lines, prev)
    local id = realIdentity(battle, lines, prev)
    calls = calls + 1
    if id ~= prev then
      pops = pops + 1
      local cur = battle and battle.current
      local what = (type(cur) == "table" and type(cur.text) == "string")
                   and cur.text or table.concat(lines or {}, "/")
      local why = ""
      if type(id) == "table" then
        if poppedItem[id] then bad = bad + 1; why = "  <-- SAME MESSAGE AGAIN" end
        poppedItem[id] = true
      elseif battle and battle.phase == "messages" and #(lines or {}) > 0
             and table.concat(lines) ~= "" then
        -- a pop on lines with no message item, mid-message: the old bug
        bad = bad + 1; why = "  <-- LINGERING LINES"
      elseif prev ~= nil and table.concat(lines or {}) == "" then
        -- a pop on an EMPTY frame replays the pop on the pane being held
        bad = bad + 1; why = "  <-- EMPTY GAP (old pane pops again)"
      end
      log(("pop %2d  phase=%-11s anim=%-5s hold=%-5s %q%s"):format(
        pops, tostring(battle and battle.phase),
        tostring(battle and battle.animPlaying and true or false),
        tostring(battle and battle.msgHold and true or false),
        (what:gsub("[\n\v]", "/")), why))
    end
    return id
  end

  -- ------- 2: the text, every frame of the messages phase
  local textBad, linesDone, controlBad = 0, 0, 0
  local doneLine = {}
  local function watchText(battle)
    if battle.phase ~= "messages" then return end
    local ours = Box._engineLines(battle)
    if not ours then return end
    for _, s in ipairs(ours) do
      if s:find("[\n\v]") then controlBad = controlBad + 1 end
    end
    local L, shown, li = battle.lines, battle.shown, battle.lineIndex
    if not (L and shown and li) then return end
    local count = #shown
    for j = 1, count do
      local ln = L[li - count + j]
      if ln and ln.codes and type(shown[j]) == "table"
         and #shown[j] >= #ln.codes and not doneLine[ln] then
        doneLine[ln] = true
        linesDone = linesDone + 1
        if ours[j] ~= ln.text then
          textBad = textBad + 1
          log(("TEXT MISMATCH: engine %q, box %q"):format(ln.text, tostring(ours[j])))
        end
      end
    end
  end

  -- ------- the fight
  local function heal(b)
    if b and b.mon then
      local mx = (b.mon.stats and b.mon.stats.hp) or b.mon.hp
      b.mon.hp = mx
      if b.shownHP then b.shownHP = mx end
    end
  end
  local mine = Pokemon.new(game.data, "SNORLAX", 50)
  mine.moves = { { id = "TACKLE", pp = 35 } }
  mine.gender = "M"                       -- what Kanto-Reforged would give it
  local second = Pokemon.new(game.data, "PIKACHU", 30)
  second.gender = "F"
  game.save.party = { mine, second }
  local ok, battle = pcall(BattleState.newWild, game, "NIDORAN_F", 40)
  if not (ok and battle) or battle.dead then
    check(false, "wild battle starts"); return quit()
  end
  if battle.enemy and battle.enemy.mon then
    battle.enemy.mon.moves = { { id = "TACKLE", pp = 35 } }
    battle.enemy.curMoves = battle.enemy.mon.moves
  end
  game.overworld:pushBattle(battle)
  local function step(n)
    for _ = 1, n or 1 do watchText(battle); coroutine.yield() end
  end
  local function reach(want)
    for _ = 1, 60 do
      if battle.phase == want then return true end
      Scenes.tap(game, "a"); step(12)
    end
    return battle.phase == want
  end

  local hudShot = false
  for r = 1, 2 do
    if not reach("menu") then log("no command menu at round " .. r); break end
    heal(battle.player); heal(battle.enemy)
    if not hudShot then
      step(20)
      Scenes.shot(OUT, "ui_hud")
      hudShot = true
    end
    battle.menuIndex = 1
    step(10)
    if not reach("moveSelect") then log("no move select at round " .. r); break end
    step(8)
    pcall(battle.chooseMove, battle, 1)
    local menuRun, shotMsg = 0, false
    for _ = 1, 2400 do
      if not shotMsg and battle.phase == "messages" and battle.current then
        step(30); Scenes.shot(OUT, "ui_message_r" .. r); shotMsg = true
      end
      if battle.dead then break end
      -- A on every waiting prompt, as a player does
      if battle.msgWaiting or battle.msgPrompt then Scenes.tap(game, "a") end
      menuRun = (battle.phase == "menu") and (menuRun + 1) or 0
      if menuRun >= 12 then break end
      step(1)
    end
    if battle.dead then break end
  end

  -- ------- 3: the names, as the HUD reads them
  local pInfo = Hud.read(battle.player)
  local eInfo = Hud.read(battle.enemy)
  log("HUD names: player " .. tostring(pInfo and pInfo.name)
      .. "  enemy " .. tostring(eInfo and eInfo.name))
  local function count(s, pat)
    local _, n = tostring(s):gsub(pat, "")
    return n
  end
  check(pInfo and pInfo.name:sub(-3) == MALE and count(pInfo.name, MALE) == 1,
        "a mon with a gender gets its mark once (SNORLAX" .. MALE .. ")")
  check(eInfo and count(eInfo.name, FEMALE) == 1 and count(eInfo.name, MALE) == 0,
        "NIDORAN" .. FEMALE .. " keeps its one sign and is not marked again")

  -- ------- 4: the party, over the battle
  local sBefore = select(3, Scene.letterbox())
  local fitBefore = Renderer:fitScale()
  local okParty = reach("menu")
  if okParty then
    battle.menuIndex = 2
    step(10)
    Scenes.tap(game, "a"); step(80)
  end
  local top = game.stack:top()
  local uw, uh = Renderer:uiSize()
  local sParty = select(3, Scene.letterbox())
  local fitParty = Renderer:fitScale()
  log(("scale: battle %s (engine fit %s)  party %s (engine fit %s, UI surface %sx%s, top %s)")
      :format(tostring(sBefore), tostring(fitBefore), tostring(sParty),
              tostring(fitParty), tostring(uw), tostring(uh),
              tostring(top and (top.screenId or top.name))))
  Scenes.shot(OUT, "ui_party")
  check(okParty and top ~= battle, "the party opened over the battle")
  check(sParty == sBefore, "the battle keeps its scale with the party open")
  if fitParty ~= fitBefore then
    log("(the engine's own fit scale did move -- " .. tostring(fitBefore) .. " -> "
        .. tostring(fitParty) .. " -- which is the case the fix exists for)")
  end
  Scenes.tap(game, "b"); step(60)

  -- ------- the verdicts on 1 and 2
  log(("messages started %d, panel pops %d, panel identity calls %d, bad pops %d")
      :format(started, pops, calls, bad))
  check(calls > 0, "the 3D message panel ran")
  check(bad == 0, "no message popped twice")
  log(("lines finished %d, mismatched %d, control characters %d")
      :format(linesDone, textBad, controlBad))
  check(linesDone > 0, "the box saw finished lines")
  check(textBad == 0, "every finished line reads as the engine's own text")
  check(controlBad == 0, "no control character reached the font")

  pcall(function() battle.dead = true end)
  for _ = 1, 30 do
    if game.stack:top() == game.overworld then break end
    pcall(function() game.stack:pop() end)
    Scenes.wait(4)
  end
  BattleState.startMessage = startMessage
  Panels._msgIdentity = realIdentity
  return quit()
end
