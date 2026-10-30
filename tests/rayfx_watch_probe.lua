-- Probe: catch the SCREEN FX pass turning a frame black.
--
-- The black strobe reported on 2026-10-29 goes away with SCREEN FX off and
-- comes and goes on its own. Rather than look at the screen (recordings
-- kept missing it), this watches lib/RayFX.lua's apply() itself: every
-- frame, a patch of what went IN and the same patch of what came OUT are
-- read back, and a frame where light went in and black came out is logged
-- with everything the pass was handed -- level, matrix, eye, camera.
--
--   python tools/profiler/run.py rayfx_watch_probe --all-mods
--
-- DS_WATCH_SECS (default 180) is how long to stand there.
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "rayfx_watch" }))
  local log, V = H.log, H.V
  if not Scenes.boot(game, log) then log("FAIL boot"); H:finish(); love.event.quit(); return end
  local Runtime = require("src.mods.Runtime")
  local function noUpdate() end

  local c = { id = os.getenv("DS_WATCH_MAP") or "CELADON_CITY", x = 10, y = 10 }
  if not Scenes.visit(game, V, c, log) then H:finish(); love.event.quit(); return end
  V.require("DayNight").setting:sync("night")

  local RayFX = V.require("RayFX")
  local Mat4 = V.require("Mat4")
  local MarioCam = V.require("MarioCam")
  log(("SCREEN FX setting %s -> level %s, follow cam %s"):format(
    tostring(RayFX.setting:get()), tostring(RayFX.level()), tostring(MarioCam.rung())))

  -- mean brightness of a centred patch of a canvas
  local function patch(cv)
    local w, h = cv:getDimensions()
    local pw, ph = math.max(1, math.floor(w / 4)), math.max(1, math.floor(h / 4))
    local ok, data = pcall(cv.newImageData, cv, 1, 1,
                           math.floor((w - pw) / 2), math.floor((h - ph) / 2), pw, ph)
    if not ok or not data then return nil end
    local sum, n = 0, 0
    for y = 0, ph - 1, 4 do
      for x = 0, pw - 1, 4 do
        local r, g, b = data:getPixel(x, y)
        sum = sum + r + g + b
        n = n + 1
      end
    end
    data:release()
    return sum / (3 * math.max(1, n))
  end

  local function det3(m)
    -- determinant of the upper 3x3, enough to see a matrix collapsing
    return m[1] * (m[6] * m[11] - m[7] * m[10])
         - m[2] * (m[5] * m[11] - m[7] * m[9])
         + m[3] * (m[5] * m[10] - m[6] * m[9])
  end

  local frames, caught, shots = 0, 0, 0
  local lastIn, lastOut = nil, nil
  local inner = RayFX.apply
  RayFX.apply = function(o)
    local out = inner(o)
    frames = frames + 1
    if out and o and o.canvas then
      local a, b = patch(o.canvas), patch(out)
      lastIn, lastOut = a, b
      if a and b and a > 0.05 and b < 0.25 * a then
        caught = caught + 1
        local inv = Mat4.invert(o.vp)
        local lk = MarioCam.lakitu
        local camDist = -1
        if lk then
          local dx = lk.curFocus[1] - lk.curPos[1]
          local dy = lk.curFocus[2] - lk.curPos[2]
          local dz = lk.curFocus[3] - lk.curPos[3]
          camDist = math.sqrt(dx * dx + dy * dy + dz * dz)
        end
        if caught <= 40 then
          log(("BLACK f%d in=%.3f out=%.3f level=%s %dx%d det3(vp)=%.3g inv=%s "
               .. "eye=(%.1f,%.1f,%.1f) camDist=%.1f floor=%s")
              :format(frames, a, b, tostring(RayFX.level()), o.w or -1, o.h or -1,
                      det3(o.vp), inv and "ok" or "NIL",
                      o.eye and o.eye[1] or 0, o.eye and o.eye[2] or 0,
                      o.eye and o.eye[3] or 0, camDist, tostring(RayFX.floor)))
        end
        if shots < 3 then
          shots = shots + 1
          local okI, data = pcall(out.newImageData, out)
          if okI and data then
            local f = io.open(("%s/rayfx_out_black_%d.png"):format(OUT, frames), "wb")
            if f then f:write(data:encode("png"):getString()); f:close() end
          end
          local okJ, dIn = pcall(o.canvas.newImageData, o.canvas)
          if okJ and dIn then
            local f = io.open(("%s/rayfx_in_%d.png"):format(OUT, frames), "wb")
            if f then f:write(dIn:encode("png"):getString()); f:close() end
          end
        end
      end
    end
    return out
  end

  local secs = tonumber(os.getenv("DS_WATCH_SECS") or "") or 180
  local t0 = love.timer.getTime()
  local lastReport = t0
  while love.timer.getTime() - t0 < secs do
    coroutine.yield()
    pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
    if love.timer.getTime() - lastReport > 15 then
      lastReport = love.timer.getTime()
      log(("t=%3.0fs frames=%d caught=%d last in=%.3f out=%.3f"):format(
        lastReport - t0, frames, caught, lastIn or -1, lastOut or -1))
    end
  end
  RayFX.apply = inner
  log(("%s: %d of %d SCREEN FX frames came out black"):format(
    caught == 0 and "CLEAN" or "CAUGHT", caught, frames))
  H:finish({ probe = "rayfx_watch" })
  love.event.quit()
end
