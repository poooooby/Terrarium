-- "Building voxels... 42%": a small badge over the flat 2D picture while a
-- map's 3D is still being built.
--
-- Why. On a first visit the engine draws its own flat 2D path until the
-- map's mesh lands -- seconds on a desktop, 7-10 s or more on a phone with
-- the JIT off -- and nothing on screen said anything was happening. Players
-- read that as the mod not working and turned it off. The badge says it is
-- working, and roughly how long is left; when the map has been built once
-- the 3D build cache (lib/BuildCache.lua) makes the next visit near-instant
-- and the badge does not come up at all.
--
-- The percentage is TIME against this device's own learned build rate
-- (BuildCache.estimate / noteBuild), held under 95% until the map is
-- actually in: the build has no honest single progress counter (the kits,
-- the mesh walk and the uploads are different kinds of work), and a bar
-- that fills at the speed this phone has been building is a better promise
-- than a stage count that jumps.
--
-- Drawn from the engine's `render.hud` hook (screen space, after the whole
-- frame, 2D frames included). UI only: it reads the mesher and never
-- touches the world, the save or input.

local V = ...

local ChunkMesher = V.require("ChunkMesher")
local BuildCache = V.require("BuildCache")
local Lang = V.require("Lang")

local BuildBadge = {}

local clock = (love and love.timer and love.timer.getTime) or os.clock

-- The map the badge is up for: { id, map, t0, est }, or nil.
local shown = nil
-- Show only builds that take long enough to be noticed: a small interior
-- lands in a few frames, and a badge flashing for those would be noise.
BuildBadge.DELAY = 0.35
-- the fade out once the map is in
BuildBadge.FADE = 0.3
local fading = nil      -- { t, pct } while the badge fades away

-- Called once per update after VoxelScene.prefetch, while voxel mode is on.
-- `ready` is Voxel.ready (the current map has a mesh to draw).
function BuildBadge.note(map, ready)
  local id = map and map.id
  if shown and shown.id ~= id then
    shown = nil
  end
  if ready then
    if shown then
      -- the build the badge was timing: teach the estimate this device's
      -- real rate, so the next bar fills at the right speed
      BuildCache.noteBuild(shown.map, clock() - shown.t0)
      fading = { t = clock(), pct = 1 }
      shown = nil
    end
    return
  end
  if not shown and id and ChunkMesher.building(id) then
    shown = { id = id, map = map, t0 = clock(), est = BuildCache.estimate(map) }
    fading = nil
  end
end

-- Leaving voxel mode (or the overworld) drops the badge without teaching
-- anything: that build was not watched to the end.
function BuildBadge.reset()
  shown, fading = nil, nil
end

local fonts = {}
local function fontFor(px)
  px = math.max(10, math.floor(px))
  local f = fonts[px]
  if not f then
    local ok, nf = pcall(love.graphics.newFont, px)
    f = ok and nf or love.graphics.getFont()
    fonts[px] = f
  end
  return f
end

local function progress()
  if not shown then return nil end
  local k = (clock() - shown.t0) / shown.est
  -- ease toward 95%: linear for most of the estimate, then a slow creep,
  -- so a build that runs long never sits at a pinned number
  if k > 0.8 then k = 0.8 + 0.15 * (1 - math.exp(-(k - 0.8) * 3)) end
  return math.min(0.95, k)
end

function BuildBadge.draw()
  local g = love.graphics
  local alpha, pct = 1, nil
  if shown then
    if clock() - shown.t0 < BuildBadge.DELAY then return end
    pct = progress()
  elseif fading then
    local k = (clock() - fading.t) / BuildBadge.FADE
    if k >= 1 then fading = nil; return end
    alpha, pct = 1 - k, fading.pct
  else
    return
  end
  local w, h = g.getDimensions()
  local cv = g.getCanvas()
  if cv then w, h = cv:getDimensions() end
  -- sized off the screen's height, so it reads the same on a phone and a
  -- 1440p monitor
  local px = h / 34
  local font = fontFor(px)
  local text = Lang.pick("Building voxels", "Construindo voxels")
               .. ("  %d%%"):format(math.floor(pct * 100 + 0.5))
  local pad = math.floor(px * 0.6)
  local tw = font:getWidth(text)
  local bw = tw + pad * 2
  local bh = font:getHeight() + pad * 2 + math.floor(px * 0.35)
  local x = w - bw - math.floor(px * 0.8)
  local y = math.floor(px * 0.8)
  g.push("all")
  g.origin()
  g.setShader()
  -- the dark glass the battle HUD wears (lib/BattleHudXY.lua glassPane)
  g.setColor(0.055, 0.075, 0.10, 0.80 * alpha)
  g.rectangle("fill", x, y, bw, bh, pad * 0.6, pad * 0.6)
  g.setColor(1, 1, 1, 0.12 * alpha)
  g.setLineWidth(1)
  g.rectangle("line", x + 0.5, y + 0.5, bw - 1, bh - 1, pad * 0.6, pad * 0.6)
  g.setFont(font)
  g.setColor(0.92, 0.95, 1.0, alpha)
  g.print(text, x + pad, y + pad)
  -- the bar, under the text
  local by = y + bh - pad * 0.5 - math.max(2, px * 0.12)
  local bh2 = math.max(2, math.floor(px * 0.12))
  g.setColor(1, 1, 1, 0.15 * alpha)
  g.rectangle("fill", x + pad, by, bw - pad * 2, bh2)
  g.setColor(0.45, 0.82, 1.0, alpha)
  g.rectangle("fill", x + pad, by, (bw - pad * 2) * pct, bh2)
  g.pop()
end

function BuildBadge.showing()
  return shown ~= nil or fading ~= nil
end

return BuildBadge
