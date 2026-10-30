-- Probe: LOAD FADE (lib/LoadVeil.lua).
--   * a cold entry into a Mart / a Tower floor holds black, then fades,
--     and is gone within MAX_HOLD + FADE
--   * the frame during the hold is black, the frame after is not
--   * a revisit (room already built) gets no veil
--   * with the row OFF there is no veil at all
--   * the hold shortens the build (it earns the covered slice) -- logged
--
--   python tools/profiler/run.py load_veil_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "load_veil" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "ok   " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end
  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  local Veil = V.require("LoadVeil")
  local CM = V.require("ChunkMesher")
  local clock = love.timer.getTime

  -- mean brightness of a screenshot, 0..1
  local function brightness(name)
    local done, mean = false, nil
    love.graphics.captureScreenshot(function(img)
      local w, h = img:getDimensions()
      local sum, n = 0, 0
      for y = 0, h - 1, 16 do
        for x = 0, w - 1, 16 do
          local r, g, b = img:getPixel(x, y)
          sum, n = sum + (r + g + b) / 3, n + 1
        end
      end
      mean = sum / n
      pcall(function()
        local f = io.open(OUT .. "/" .. name .. ".png", "wb")
        f:write(img:encode("png"):getString()); f:close()
      end)
      done = true
    end)
    for _ = 1, 4 do coroutine.yield(); if done then break end end
    return mean
  end

  local function enter(id)
    -- from outside, settled, with every cache dropped: a true first visit
    Scenes.visit(game, V, { id = "LAVENDER_TOWN", x = 10, y = 10 }, log)
    CM.invalidate()
    local t0 = clock()
    Scenes.visit(game, V, { id = id, x = 4, y = 4 }, log, true)
    local held, faded, gone, shotDuringHold = nil, nil, nil, nil
    for f = 1, 600 do
      coroutine.yield()
      if Veil.holding() and not shotDuringHold and f >= 3 then
        shotDuringHold = brightness("veil_hold_" .. id)
      end
      if Veil.holding() then held = f end
      if not Veil.holding() and Veil.alpha() > 0 and not faded then faded = f end
      if held and Veil.alpha() == 0 then gone = f; break end
    end
    local after = brightness("veil_after_" .. id)
    log(("%s: held to frame %s, fading from %s, gone at %s (%.2f s); hold shot %.3f, after %.3f")
      :format(id, tostring(held), tostring(faded), tostring(gone), clock() - t0,
              shotDuringHold or -1, after or -1))
    return held, gone, shotDuringHold, after, clock() - t0
  end

  for _, id in ipairs({ "LAVENDER_MART", "POKEMON_TOWER_1F" }) do
    local held, gone, holdB, afterB, secs = enter(id)
    check(held ~= nil, id .. " held black on a cold entry")
    check(gone ~= nil and secs < Veil.MAX_HOLD + Veil.FADE + 1.5,
          id .. " revealed within MAX_HOLD + FADE")
    check(holdB ~= nil and holdB < 0.05, id .. " screen is black during the hold")
    check(afterB ~= nil and afterB > 0.1, id .. " room visible after the fade")
    check(CM.peek(game.overworld.map, false) ~= nil, id .. " room built when revealed")
  end

  -- revisit: the room entered last is still built (retention), so no veil
  -- (the Mart is not: the Tower's cold entry invalidated every cache)
  Scenes.visit(game, V, { id = "LAVENDER_TOWN", x = 10, y = 10 }, log)
  Scenes.visit(game, V, { id = "POKEMON_TOWER_1F", x = 4, y = 4 }, log, true)
  local any = false
  for _ = 1, 30 do coroutine.yield(); if Veil.alpha() > 0 then any = true end end
  check(not any, "revisit: no veil")

  -- OFF: no veil even cold
  Veil.setting:sync("off")
  Scenes.visit(game, V, { id = "LAVENDER_TOWN", x = 10, y = 10 }, log)
  CM.invalidate()
  Scenes.visit(game, V, { id = "VIRIDIAN_MART", x = 4, y = 4 }, log, true)
  any = false
  for _ = 1, 60 do coroutine.yield(); if Veil.alpha() > 0 then any = true end end
  check(not any, "row OFF: no veil")
  Veil.setting:sync("on")

  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  H:finish({ probe = "load_veil" })
  love.event.quit()
end
