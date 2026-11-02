-- Probe: does the voxel pipeline survive SGB (and every other COLORS mode)
-- on the settings a phone runs at?
--
-- Reported from Android: on SGB the voxels never built and the "Building
-- voxels" badge never showed; switching COLORS to ADVANCED fixed it. Both
-- symptoms at once point at src/render/Pipelines.lua's guard: one throw from
-- drawWorld / update / available marks the pipeline broken "for this
-- session", which stops the build pump and the badge with it.
--
-- This forces Device.mobile() and the phone's quality rungs, then walks a few
-- maps in each COLORS mode and reports every error the engine's guard caught
-- (Logger.error / Runtime.reportError are wrapped to record them), plus
-- whether the pipeline was still eligible at the end of each visit.
--
--   python tools/profiler/run.py sgb_mobile_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")
  local Logger = require("src.core.Logger")
  local Runtime = require("src.mods.Runtime")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "sgb_mobile" }))
  local log, V = H.log, H.V
  local fails = 0
  local function check(ok, what)
    log((ok and "PASS " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end

  -- every error the pipeline guard reports
  local errors = {}
  local origErr = Logger.error
  Logger.error = function(fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    msg = ok and msg or tostring(fmt)
    if msg:find("pipeline", 1, true) then errors[#errors + 1] = msg end
    return origErr(fmt, ...)
  end

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)

  -- the phone: mobile, lowest RES rung, shadows off
  local Device = V.require("Device")
  Device.mobile = function() return true end
  local Quality = V.require("Quality")
  pcall(function() Quality.setting:sync(Quality.setting.values[#Quality.setting.values]) end)
  pcall(function() Quality.shadowSetting:sync("off") end)
  log("Device.mobile forced; RES " .. tostring(Quality.setting:get())
      .. ", shadows " .. tostring(Quality.shadowSetting:get()))

  local PIPE = "terrarium_voxel"
  local MAPS = {
    { id = "PALLET_TOWN", x = 10, y = 11 },
    { id = "ROUTE_1", x = 10, y = 20 },
    { id = "VIRIDIAN_CITY", x = 18, y = 18 },
  }
  for _, mode in ipairs(PaletteFX.MODES) do
    game.save.options.colors = mode
    PaletteFX.setMode(mode)
    -- a clean slate per mode, as a fresh session would have
    Pipelines.applyOptions(game.save.options)
    Pipelines.setLevel(PIPE, 4)
    errors = {}
    for _, c in ipairs(MAPS) do
      pcall(Scenes.visit, game, V, c, log, false)
      Scenes.wait(30)
    end
    local eligible = Pipelines.eligible(PIPE)
    check(eligible and #errors == 0,
          ("%-8s pipeline %s%s"):format(mode, eligible and "alive" or "DISABLED",
            #errors > 0 and (": " .. errors[1]) or ""))
    if mode == "gbc" then Scenes.shot(OUT, "sgb_mobile") end
  end

  -- DEBUG INFO: over the 3D view, and over a 2D frame (VOXEL off), where
  -- it used to draw nothing at all
  local Diag = V.require("Diag")
  Diag.setting:sync("on")
  Pipelines.setLevel(PIPE, 4)
  Scenes.wait(20)
  Scenes.shot(OUT, "diag_3d")
  Pipelines.setLevel(PIPE, 0)
  Scenes.wait(60)
  Scenes.shot(OUT, "diag_2d")
  for _, l in ipairs(Diag.lines()) do log("diag | " .. l) end
  Diag.setting:sync("off")

  Logger.error = origErr
  log(fails == 0 and "PASS all" or ("FAIL %d modes"):format(fails))
  H:finish()
  love.event.quit()
end
