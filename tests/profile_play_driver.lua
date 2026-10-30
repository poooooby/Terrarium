-- Driver: profile while you play by hand. Boots normally; nothing is
-- recorded until you press F8, which starts an AppleCake session (and
-- Perf's tables); F8 again stops it and writes the trace. Closing the
-- game with a session open stops and writes it too.
--
--   <DS_PROBE_DIR>/play_<n>.json        AppleCake trace -> ui.perfetto.dev
--   <DS_PROBE_DIR>/play_<n>.log         Perf report for that session
--   <DS_PROBE_DIR>/play_<n>_perf.json
--
--   DS_PROBE_DIR=<dir> POKEPORT_DRIVER=mods/<id>/tests/profile_play_driver.lua love .
-- (python tools/profiler/run.py profile_play_driver does this, Terrarium only.)
--
-- F8 is free in both the engine's and this mod's key maps (main.lua's key
-- block; the engine binds f1/f2/f3/f5/f10). It is read with
-- love.keyboard.isDown rather than a keypressed hook so the driver never
-- touches the game's input path.
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."

  -- the mod's export appears once the mods load; wait for it
  local id
  for _ = 1, 1800 do
    id = Harness.findMod(game)
    if id then break end
    coroutine.yield()
  end
  if not id then print("[profile] no Terrarium export; driver idle") return end
  print("[profile] attached to " .. id .. " -- F8 starts/stops a session, traces go to " .. OUT)

  local H, n = nil, 0
  local function stop()
    if not H then return end
    H:finish({ driver = "profile_play", session = n })
    print("[profile] session " .. n .. " written to " .. OUT)
    H = nil
  end

  -- a session open at quit still gets written
  local quit = love.quit
  love.quit = function(...)
    stop()
    if quit then return quit(...) end
  end

  local wasDown = false
  while true do
    local down = love.keyboard.isDown("f8")
    if down and not wasDown then
      if H then
        stop()
      else
        n = n + 1
        H = Harness.attach(game, { out = OUT, name = "play_" .. n, trace = true })
        if H then print("[profile] session " .. n .. " recording") end
      end
    end
    wasDown = down
    coroutine.yield()
    if H then H:frame() end
  end
end
