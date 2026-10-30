-- Probe: which part of the 3D pass makes the window strobe black?
--
-- Reported 2026-10-29: with VOXEL on (and only then), standing still
-- outdoors at night, the whole game area blinks black about every 0.7 s --
-- visible on the monitor, over remote desktop, and in a Snagit recording,
-- yet never in a frame read back with captureScreenshot. So this probe does
-- not look at the frames itself: run it while recording the window from
-- OUTSIDE (tools/profiler/flicker_record.py does both), and it switches the
-- heavy render features off one more per phase, logging the wall-clock
-- second each phase starts so the recording can be cut on them.
--
-- Phases are cumulative: the first phase that comes out clean names the
-- feature that was switched off at its start. Settings are changed with
-- sync(), so nothing is written to options.lua.
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "flicker_bisect" }))
  local log, V = H.log, H.V
  if not Scenes.boot(game, log) then log("FAIL boot"); H:finish(); love.event.quit(); return end
  local Runtime = require("src.mods.Runtime")
  local Pipelines = require("src.render.Pipelines")

  local c = { id = os.getenv("DS_BISECT_MAP") or "CELADON_CITY", x = 10, y = 10 }
  if not Scenes.visit(game, V, c, log) then H:finish(); love.event.quit(); return end
  V.require("DayNight").setting:sync("night")
  V.require("Weather").setting:sync("off")

  local function set(mod, field, value)
    return function() V.require(mod)[field]:sync(value) end
  end
  local PHASES = {
    { "baseline (player's settings)", function() end },
    { "SCREEN FX off", set("RayFX", "setting", "off") },
    { "+ SHADOWS off", set("Quality", "shadowSetting", "off") },
    { "+ T-SHIFT off", function() Pipelines.setLevel("terrarium_tiltshift", 0) end },
    { "+ CLOUDS off, CLOUD SHADOW off", function()
        set("Sky", "cloudSetting", 0)(); set("CloudShade", "setting", "off")()
      end },
    { "+ DISTANCE FOG off, HORIZON off", function()
        set("Aerial", "setting", 0)(); set("Skyline", "setting", 0)()
      end },
    { "+ LIGHTING flat, STREET LAMPS off", function()
        set("Light", "setting", false)(); set("StreetLamps", "setting", false)()
      end },
  }
  local SECS = tonumber(os.getenv("DS_BISECT_SECS") or "") or 12

  -- The recordings miss this flicker while a person watching sees it, so
  -- the person is the detector: the phase is printed big in the corner of
  -- the window, drawn after everything else, and they say where it stopped.
  local label = "WARMING UP"
  local font = love.graphics.newFont(40)
  local innerDraw = love.draw
  love.draw = function(...)
    local r = innerDraw(...)
    local g = love.graphics
    g.push("all")
    g.origin()
    g.setCanvas()
    g.setFont(font)
    g.setColor(0, 0, 0, 0.75)
    g.rectangle("fill", 8, 8, font:getWidth(label) + 24, 56)
    g.setColor(1, 1, 0.3, 1)
    g.print(label, 20, 14)
    g.pop()
    return r
  end

  local function noUpdate() end
  -- let the diorama come all the way up first: a phase that starts while
  -- the 3D view is still switching on measures the switch, not the feature
  local warm = tonumber(os.getenv("DS_BISECT_WARMUP") or "") or 12
  local t0w = love.timer.getTime()
  while love.timer.getTime() - t0w < warm do
    coroutine.yield()
    pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
  end
  log(("voxel level %s after %ds warm-up"):format(
    tostring(Pipelines.level("terrarium_voxel")), warm))
  log(("start epoch %d"):format(os.time()))
  for i, p in ipairs(PHASES) do
    p[2]()
    label = ("PHASE %d: %s"):format(i, p[1])
    log(("PHASE %d at epoch %d: %s"):format(i, os.time(), p[1]))
    local t0 = love.timer.getTime()
    while love.timer.getTime() - t0 < SECS do
      coroutine.yield()
      pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
    end
  end
  log(("end epoch %d"):format(os.time()))
  love.draw = innerDraw
  H:finish({ probe = "flicker_bisect" })
  love.event.quit()
end
