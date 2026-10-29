-- Probe: thunderstorm flash (cel steps) and thunder delay.
--
--   POKEPORT_VERSION=yellow DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/TERRARIUM/tests/thunder_probe.lua gen1recomp
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local logf = assert(io.open(OUT .. "/thunder_probe.log", "w"))
  local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    logf:write(table.concat(parts, " "), "\n"); logf:flush()
  end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local function tap(b)
    game.input.pressQueue[#game.input.pressQueue + 1] = b; coroutine.yield()
  end

  love.math.setRandomSeed(20260806)

  local n = 0
  while not (game.overworld and game.stack and game.stack:top()) do
    wait(1); n = n + 1
    if n > 900 then log("FAIL: no overworld") logf:close() love.event.quit() return end
  end
  n = 0
  while game.stack:top() ~= game.overworld do
    tap("a"); wait(10); n = n + 11
    if n > 1500 then log("FAIL: never reached free roam") break end
  end

  local exports = game.mods and game.mods.exports
  local lib = exports and exports.TERRARIUM and exports.TERRARIUM.lib
  if not lib then
    log("FAIL: TERRARIUM not loaded"); logf:close(); love.event.quit(); return
  end
  log("version:", exports.TERRARIUM.version)

  local Weather = lib.require("Weather")
  local DayNight = lib.require("DayNight")
  local Pipelines = require("src.render.Pipelines")

  DayNight.setting:sync("day")
  Weather.setting:sync("rain")
  Pipelines.setLevel("terrarium_voxel", 4)

  game.overworld:setMap("ROUTE_1", 10, 20, "down")
  wait(180)

  -- force peak power so storming() is true
  for _ = 1, 600 do
    Weather.update(1 / 30)
  end
  local kind, power = Weather.visible()
  log(("visible kind=%s power=%.3f storming=%s"):format(
    tostring(kind), power or -1, tostring(Weather.storming())))

  -- ---- flash cel steps ----
  Weather.forceStrike(0.2)
  local samples = {}
  local seen = {}
  for i = 1, 40 do
    local f = Weather.flash()
    samples[#samples + 1] = f
    seen[tostring(f)] = true
    Weather.update(1 / 60)
  end
  local steps = {}
  for k in pairs(seen) do steps[#steps + 1] = k end
  table.sort(steps)
  log("flash steps seen:", table.concat(steps, ","))
  local onlyCel = true
  for _, v in ipairs(samples) do
    if v ~= 0 and v ~= 0.5 and v ~= 1 then onlyCel = false end
  end
  log(onlyCel and "PASS: flash is cel-stepped (0/0.5/1)"
              or "FAIL: flash left continuous values")

  -- ---- thunder delay ----
  local far = 0.5
  Weather.forceStrike(far)
  local expect = Weather.thunderDelay(far)
  log(("thunderDelay(far=%.2f)=%.3fs"):format(far, expect))
  local got = nil
  local t = 0
  for _ = 1, 200 do
    local d = 1 / 60
    t = t + d
    Weather.update(d)
    local due = Weather.thunderDue()
    if due ~= nil then got = t; log(("thunderDue at t=%.3f far=%s"):format(t, tostring(due))); break end
  end
  if got and math.abs(got - expect) < 0.08 then
    log("PASS: thunder delay matches far")
  else
    log(("FAIL: thunder delay got=%s expect~%.3f"):format(tostring(got), expect))
  end

  logf:close()
  love.event.quit()
end
