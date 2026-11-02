-- Probe: the "Terrarium needs ADVANCED colours" panel (lib/ColorsPrompt.lua),
-- end to end, in free roam:
--
--   1. COLORS on ADVANCED: no panel, ever
--   2. COLORS on SGB: the panel comes up by itself after the settle
--                                                     -> colors_ask.png
--   3. KEEP: it closes, COLORS is untouched, and it does not come back
--   4. COLORS on OG (another mode): it asks again
--   5. SWITCH: COLORS becomes ADVANCED in PaletteFX and in the options
--   6. ADVANCED -> SGB again: the old KEEP was forgotten, so it asks again
--
-- Under POKEPORT_DRIVER the engine never runs the core.update hook chain,
-- which is where main.lua drives the panel, so this runs it each frame
-- itself (as tests/build_veil_probe.lua does).
--
--   python tools/profiler/run.py colors_prompt_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local Runtime = require("src.mods.Runtime")
  local PaletteFX = require("src.render.PaletteFX")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "colors_prompt" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "PASS " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end

  local function noUpdate() end
  local function frame()
    pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
    coroutine.yield()
  end
  local function frames(n) for _ = 1, n do frame() end end
  local function tap(b)
    game.input.pressQueue[#game.input.pressQueue + 1] = b
    frame()
  end
  local function setColors(mode)
    game.save.options.colors = mode
    PaletteFX.setMode(mode)
    frames(30)    -- the colour change reloads the map
  end

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)
  local ColorsPrompt = V.require("ColorsPrompt")
  local was = game.save.options.colors
  ColorsPrompt.resetForProbe()

  -- 1.
  setColors("redpp")
  frames(150)
  check(not ColorsPrompt.active(), "no panel on ADVANCED")

  -- 2.
  setColors("gbc")
  local n = 0
  while not ColorsPrompt.active() and n < 300 do frame(); n = n + 1 end
  check(ColorsPrompt.active(), ("the panel came up on SGB (after %d frames)"):format(n))
  -- setColors already ran 30 frames of the settle; 60 frames is 1.0 s
  check(30 + n >= 55, ("and waited out the settle first (%d frames)"):format(30 + n))
  frames(5)
  Scenes.shot(OUT, "colors_ask")

  -- 3. KEEP is the second row
  tap("down"); tap("a"); frames(2)
  check(not ColorsPrompt.active(), "KEEP closed it")
  check(PaletteFX.mode == "gbc" and game.save.options.colors == "gbc",
        "and left COLORS on SGB")
  check(game.stack:top() == game.overworld, "the overworld is back on top")
  frames(240)
  check(not ColorsPrompt.active(), "no second ask for the mode KEEP answered")

  -- 4.
  setColors("og")
  n = 0
  while not ColorsPrompt.active() and n < 300 do frame(); n = n + 1 end
  check(ColorsPrompt.active(), "a different mode asks again")

  -- 5. SWITCH is the first row
  tap("a"); frames(30)
  check(not ColorsPrompt.active(), "SWITCH closed it")
  check(PaletteFX.mode == "redpp", "PaletteFX is on ADVANCED")
  check(game.save.options.colors == "redpp", "and so is the saved COLORS option")
  frames(150)
  check(not ColorsPrompt.active(), "and nothing more is asked")
  Scenes.shot(OUT, "colors_after")

  -- 6.
  setColors("gbc")
  n = 0
  while not ColorsPrompt.active() and n < 300 do frame(); n = n + 1 end
  check(ColorsPrompt.active(), "leaving ADVANCED again asks again (old KEEP forgotten)")
  tap("b"); frames(2)
  check(not ColorsPrompt.active(), "B closes it (as KEEP)")

  ColorsPrompt.resetForProbe()
  setColors(was or "gbc")
  log(fails == 0 and "PASS all" or ("FAIL %d checks"):format(fails))
  H:finish()
  love.event.quit()
end
