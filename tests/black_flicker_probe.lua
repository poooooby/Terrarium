-- Probe: does the whole screen strobe black while walking outdoors?
--
-- Reported 2026-10-29: walking around outdoors, the whole screen blinks
-- black, repeatedly. This walks long legs through outdoor maps under the
-- player's OWN settings (run it with --all-mods, so options.lua is theirs
-- and nothing is pinned), reads every presented frame back and counts the
-- frames that are almost entirely black, logging beside each one what
-- might be switching: the RESOLUTION AUTO rung, the map, the screen on top,
-- the follow camera.
--
--   python tools/profiler/run.py black_flicker_probe --all-mods
--
-- DS_FLICKER_MAPS=ID,ID overrides the map list.
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "black_flicker" }))
  local log, V = H.log, H.V
  local function quit(msg) log(msg); H:finish({ probe = "black_flicker" }); love.event.quit() end
  if not Scenes.boot(game, log) then return quit("FAIL boot") end

  local Runtime = require("src.mods.Runtime")
  local function noUpdate() end
  local AutoQuality = V.require("AutoQuality")
  local Quality = V.require("Quality")
  local MarioCam = V.require("MarioCam")
  local Pipelines = require("src.render.Pipelines")
  log(("settings: RESOLUTION=%s voxel level=%s follow cam=%s"):format(
    tostring(Quality.setting:get()), tostring(Pipelines.level("terrarium_voxel")),
    tostring(MarioCam.rung())))

  -- EVERY presented frame, read back: mean brightness over a 24x18 grid.
  -- No "one readback in flight" guard -- a black frame every OTHER frame
  -- is exactly what a guarded sampler aliases away (the first version of
  -- this probe saw nothing while the window strobed in front of the user).
  local lum = {}
  -- DS_FLICKER_KEEP=n: also write frames base+300 .. +300+n-1 of the
  -- first map to disk, to look at rather than average
  local keepFrames = {}
  local keepN = tonumber(os.getenv("DS_FLICKER_KEEP") or "") or 0
  for f = 300, 300 + keepN - 1 do keepFrames[f] = true end
  local drawN, savedDark = 0, 0
  local function sample(f)
    love.graphics.captureScreenshot(function(img)
      local w, h = img:getDimensions()
      local sum, n = 0, 0
      for gy = 1, 18 do
        for gx = 1, 24 do
          local r, g, b = img:getPixel(math.floor((gx - 0.5) / 24 * w),
                                       math.floor((gy - 0.5) / 18 * h))
          sum = sum + 0.299 * r + 0.587 * g + 0.114 * b
          n = n + 1
        end
      end
      lum[f] = sum / n
      if lum[f] < 0.03 and savedDark < 3 then
        savedDark = savedDark + 1
        keepFrames[f] = true
      end
      if keepFrames[f] then
        local fh = io.open(("%s/frame_%04d.png"):format(OUT, f), "wb")
        if fh then fh:write(img:encode("png"):getString()); fh:close() end
      end
    end)
  end
  -- Queued from love.draw, not from this driver: the driver may be resumed
  -- zero or several times per loop, so a capture per resume both misses
  -- presented frames and doubles others. One per draw sees every present.
  local innerDraw = love.draw
  local capturing = false
  local ctxOf, tAt = {}, {}
  love.draw = function(...)
    local r = innerDraw(...)
    if capturing then
      drawN = drawN + 1
      tAt[drawN] = love.timer.getTime()
      local ow = game.overworld
      local top = game.stack and game.stack:top()
      ctxOf[drawN] = ("%s %s%s"):format(tostring(ow and ow.map and ow.map.id),
        top == ow and "overworld" or Scenes.describe(top),
        (ow and ow.transitioning) and " TRANSITION" or "")
      sample(drawN)
    end
    return r
  end
  -- GPU allocations: every canvas and image created while walking, with
  -- its size and the line that asked for it. A pass that keeps creating and
  -- dropping big targets can make the driver rebuild the window's own
  -- buffers -- a black frame on screen that no presented frame contains.
  local allocs, allocLog = {}, {}
  local function wrapAlloc(name)
    local inner = love.graphics[name]
    love.graphics[name] = function(...)
      local obj = inner(...)
      if capturing then
        local w, h = 0, 0
        if obj and obj.getDimensions then
          local okD, a, b = pcall(obj.getDimensions, obj)
          if okD then w, h = a, b end
        end
        local info = debug.getinfo(2, "Sl")
        local where = info and (info.short_src:match("[^/\\]+$") .. ":" .. info.currentline) or "?"
        local key = ("%s %dx%d %s"):format(name, w, h, where)
        allocs[key] = (allocs[key] or 0) + 1
        allocLog[#allocLog + 1] = { drawN, key }
      end
      return obj
    end
    return inner
  end
  local innerCanvas = wrapAlloc("newCanvas")
  local innerImage = wrapAlloc("newImage")
  -- which frames the sun pass actually redrew the shadow map on
  local ShadowMap = V.require("ShadowMap")
  local redrew = {}
  local curFrame = 0
  local innerBegin = ShadowMap.begin
  ShadowMap.begin = function(...)
    local ok = innerBegin(...)
    if ok then redrew[curFrame] = true end
    return ok
  end
  if os.getenv("DS_FLICKER_NIGHT") then
    V.require("DayNight").setting:sync("night")
    log("forced NIGHT")
  end

  local maps = { { id = "CELADON_CITY", x = 10, y = 10 },
                 { id = "PALLET_TOWN", x = 10, y = 11 },
                 { id = "LAVENDER_TOWN", x = 10, y = 10 },
                 { id = "VERMILION_CITY", x = 10, y = 10 } }
  local env = os.getenv("DS_FLICKER_MAPS")
  if env then
    maps = {}
    for id in env:gmatch("[^,]+") do maps[#maps + 1] = { id = id, x = 10, y = 10 } end
  end

  local LEGS = { "right", "down", "left", "up" }
  local total, blackFrames, shots = 0, 0, 0
  for _, c in ipairs(maps) do
    if Scenes.visit(game, V, c, log) then
      log("== " .. c.id)
      local base = drawN
      capturing = true
      for f = 1, 600 do
        local dir = LEGS[math.floor((f - 1) / 75) % 4 + 1]
        game.input.pressQueue[#game.input.pressQueue + 1] = dir
        curFrame = drawN + 1
        coroutine.yield()
        pcall(Runtime.call, "core.update", noUpdate, game, 1 / 60)
        total = total + 1
      end
      capturing = false
      Scenes.wait(4)          -- the last readbacks land
      local last = drawN
      -- a DIP is a frame much darker than both its neighbours
      local dips, dipsSkip, dipsRedraw, series = 0, 0, 0, {}
      for f = base + 2, last - 1 do
        local a0, a1, a2 = lum[f - 1], lum[f], lum[f + 1]
        if a0 and a1 and a2 and a1 < 0.6 * math.min(a0, a2) then
          dips = dips + 1
          if redrew[f] then dipsRedraw = dipsRedraw + 1 else dipsSkip = dipsSkip + 1 end
          if shots < 4 then shots = shots + 1 end
        end
      end
      -- every fully black frame, with what was on screen around it
      local f = base + 1
      while f <= last do
        if lum[f] and lum[f] < 0.03 then
          local e = f
          while lum[e + 1] and lum[e + 1] < 0.03 do e = e + 1 end
          log(("   BLACK frames %d-%d (%d): before %.2f [%s] | during [%s] | after %.2f [%s]")
              :format(f, e, e - f + 1, lum[f - 1] or -1, tostring(ctxOf[f - 1]),
                      tostring(ctxOf[f]), lum[e + 1] or -1, tostring(ctxOf[e + 1])))
          dips = dips + (e - f + 1)
          f = e + 1
        else
          f = f + 1
        end
      end
      -- frame times: spikes and the spacing between them
      local dts = {}
      for f = base + 2, last do
        if tAt[f] and tAt[f - 1] then dts[#dts + 1] = { f, (tAt[f] - tAt[f - 1]) * 1000 } end
      end
      local sorted = {}
      for i, d in ipairs(dts) do sorted[i] = d[2] end
      table.sort(sorted)
      local med = sorted[math.ceil(#sorted / 2)] or 0
      local spikes, prevSpike, gaps = {}, nil, {}
      for _, d in ipairs(dts) do
        if d[2] > med * 1.8 and d[2] > 25 then
          spikes[#spikes + 1] = ("%d:%.0f"):format(d[1] - base, d[2])
          if prevSpike then gaps[#gaps + 1] = d[1] - prevSpike end
          prevSpike = d[1]
        end
      end
      log(("   frame time median %.1f ms; %d spikes (>1.8x and >25 ms)"):format(med, #spikes))
      log("   spikes (frame:ms): " .. table.concat(spikes, " ", 1, math.min(#spikes, 40)))
      log("   gaps between spikes (frames): " .. table.concat(gaps, " ", 1, math.min(#gaps, 40)))
      local rows = {}
      for k, v in pairs(allocs) do rows[#rows + 1] = { k, v } end
      table.sort(rows, function(a, b) return a[2] > b[2] end)
      log(("   GPU allocations while walking: %d"):format(#allocLog))
      for i = 1, math.min(12, #rows) do
        log(("     %5d x %s"):format(rows[i][2], rows[i][1]))
      end
      allocs, allocLog = {}, {}
      blackFrames = blackFrames + dips
      for f = base + 300, base + 330 do
        series[#series + 1] = ("%.2f%s"):format(lum[f] or -1, redrew[f] and "R" or "")
      end
      log(("   %d presented frames captured"):format(last - base))
      log(("   %d dark-dip frames (%d on a frame the shadow map was "
           .. "redrawn, %d on a frame that reused it)"):format(dips, dipsRedraw, dipsSkip))
      log("   brightness f300-330 (R = shadow redrawn): " .. table.concat(series, " "))
      local p = game.overworld.player
      log(("   %s done, player at cell (%d,%d)"):format(c.id,
        math.floor(((p and p.px) or 0) / 16), math.floor(((p and p.py) or 0) / 16)))
    end
  end
  ShadowMap.begin = innerBegin
  love.draw = innerDraw
  love.graphics.newCanvas, love.graphics.newImage = innerCanvas, innerImage
  quit(("%s: %d dark-dip frames of %d"):format(blackFrames == 0 and "PASS" or "FLICKER",
                                              blackFrames, total))
end
