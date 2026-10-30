-- Probe: BATTLE THEME, GLASS against IVORY, in a real wild fight.
--
-- Screenshots the command menu and the move cards in both themes, under
-- both BATTLE UI layouts that draw panels (DYNAMIC floats them in the
-- arena, CLASSIC lays them flat), flipping the theme MID-FIGHT -- which is
-- also the check that the cached faces (cards, chips, message) repaint on a
-- flip instead of hanging the old theme. And it checks the palette swap:
-- under GLASS the text ink must be light, under IVORY dark.
--
--   python tools/profiler/run.py battle_theme_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "battle_theme" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "ok   " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end
  local function quit() log(fails == 0 and "PASS" or ("FAIL x" .. fails))
    H:finish({ probe = "battle_theme" }); love.event.quit() end
  if not Scenes.boot(game, log) then return quit() end
  Scenes.pin(V, log)

  local HudXY = V.require("BattleHudXY")
  local BattleDynamic = V.require("BattleDynamic")
  local OverworldBattle = V.require("OverworldBattle")
  log("3D battles:", tostring(OverworldBattle.enabled()))

  -- the fresh save has nobody to send out; lend it a mon with four moves
  local Pokemon = require("src.pokemon.Pokemon")
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 22) }

  local function theme(t)
    HudXY.themeSetting:sync(t)
    HudXY.applyTheme()
  end
  local function luma(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end
  theme("glass")
  check(luma(HudXY.INK) > 0.8, ("GLASS ink is light (%.2f)"):format(luma(HudXY.INK)))
  theme("ivory")
  check(luma(HudXY.INK) < 0.25, ("IVORY ink is dark (%.2f)"):format(luma(HudXY.INK)))

  local BattleState = require("src.battle.BattleState")
  for _, mode in ipairs({ "dynamic", "classic" }) do
    BattleDynamic.onOptionsChanged(mode)
    local ok, battle = pcall(BattleState.newWild, game, "RATTATA", 9)
    if not (ok and battle) or battle.dead then
      check(false, mode .. ": wild battle starts"); return quit()
    end
    game.overworld:pushBattle(battle)
    local function reach(want)
      for _ = 1, 40 do
        if battle.phase == want then return true end
        Scenes.tap(game, "a"); Scenes.wait(12)
      end
      return battle.phase == want
    end
    check(reach("menu"), mode .. ": command menu")
    battle.menuIndex = 1
    Scenes.wait(60)
    for _, t in ipairs({ "glass", "ivory" }) do
      theme(t); Scenes.wait(20)
      Scenes.shot(OUT, ("%s_menu_%s"):format(mode, t))
    end
    check(reach("moveSelect"), mode .. ": move select")
    -- the fan deals its cards in over a second and more; shoot once settled
    Scenes.wait(150)
    for _, t in ipairs({ "glass", "ivory", "glass" }) do
      theme(t); Scenes.wait(20)
      Scenes.shot(OUT, ("%s_moves_%s"):format(mode, t))
    end
    -- out of the fight without playing it: pop the battle screen
    pcall(function() battle.dead = true end)
    for _ = 1, 10 do
      if game.stack:top() == game.overworld then break end
      pcall(game.stack.pop, game.stack); Scenes.wait(10)
    end
    Scenes.wait(30)
  end
  theme("glass")
  BattleDynamic.onOptionsChanged("dynamic")
  quit()
end
