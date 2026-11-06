-- Voxel world mode: what other mods paint over the map, carried into 3D.
--
-- With the diorama on, the engine's world canvas is never shown: the
-- pipeline hands the renderer a finished picture and the canvas is skipped
-- whole (src/render/Renderer.lua, the worldOverride blit). A mod that wraps
-- OverworldState.drawWorld and paints over the map after it -- the one way
-- to put an arbitrary picture on a Gen 1 map, which has no emote bubble that
-- takes one -- paints into that skipped canvas, and in 3D its picture is
-- simply gone. Untamed Tohjo (goldenroddeptstore/untamed-tohjo) draws its
-- follower's emote that way on Gen 1 (main.lua's setupGen1EmoteDraw):
-- love.graphics.draw(image, px - cam.x, py - cam.y - 20).
--
-- So this sits OUTSIDE every such wrapper and listens. Its own wrapper of
-- drawWorld (installed lazily, so it lands on top of whatever the other
-- mods installed while loading) arms a recorder on love.graphics.draw for
-- the stretch after the diorama has finished its frame and before drawWorld
-- returns -- a stretch in which the engine itself draws nothing (the
-- override branch ends there), so every draw in it, into the canvas
-- drawWorld was called on, is a mod painting over the map. Each is noted in
-- WORLD coordinates (the flat canvas is world pixels less the camera) and
-- drawn again on the next frame in the overlay pass, through this camera.
-- The draw itself still goes through, to the canvas no one sees, exactly
-- as before.
--
-- Placed by the engine's own rule for a field effect (ctx.drawFx): anchored
-- at a figure's foot (px + 8, py + 16) projected at ground level, and kept
-- at its flat 2D offset from there, times canvas pixels per world pixel --
-- unscaled by depth, like the engine's billboards. The figure is the one
-- whose head the picture sits on (its bottom edge within a cell of the
-- sprite's top), and it is FOLLOWED: the anchor is read off the figure when
-- drawn, so a bubble rides a walking follower. A picture over no figure is
-- stood on the ground under its own bottom edge.
--
-- One frame late by construction (recorded on frame N, drawn on N+1, when
-- the overlay pass comes round again); for a bubble that is a pixel at
-- walking pace. Mods that want it exact register a draw function with
-- lib/OverlayHooks.lua instead, passing `claims` -- and while one does,
-- nothing is caught here, so the picture is not drawn twice.

-- the mod namespace (see main.lua)
local V = ...
local OverlayHooks = V.require("OverlayHooks")

local WorldPostDraw = {}

local okOS, OverworldState = pcall(require, "src.world.OverworldController")
if not okOS then OverworldState = nil end

local lg = love and love.graphics
local realDraw = lg and lg.draw

local ours = setmetatable({}, { __mode = "k" })   -- the wrappers we made
local depth = 0             -- inside our outermost wrapper
local armed = false         -- the recorder is on love.graphics.draw
local baseCanvas = nil      -- the canvas drawWorld was called on
local liveState = nil       -- the OverworldState being drawn

-- recorded this frame / to draw next frame; records are reused
local caught, nCaught = {}, 0
local shown, nShown = {}, 0

-- The figure a picture sits on: its bottom edge (bx, by) near the top of a
-- 16x16 sprite, (px + 8, py - 4) in world pixels, within a cell sideways
-- and a cell and a half up or down.
local function figureUnder(state, bx, by)
  local best, bestD = nil, nil
  for _, e in ipairs(state.entities or {}) do
    if e.px and e.py then
      local dx, dy = bx - (e.px + 8), by - (e.py - 4)
      if dx >= -16 and dx <= 16 and dy >= -24 and dy <= 24 then
        local d = dx * dx + dy * dy
        if not bestD or d < bestD then best, bestD = e, d end
      end
    end
  end
  return best
end

local function record(drawable, quad, x, y, r, sx, sy, ox, oy)
  local cam = liveState and liveState.camera
  if not (cam and cam.x and cam.y) then return end
  local okD, w, h
  if quad then
    okD, w, h = pcall(function() local _, _, qw, qh = quad:getViewport(); return qw, qh end)
  else
    okD, w, h = pcall(drawable.getDimensions, drawable)
  end
  if not (okD and w and h) then return end
  x, y, r = x or 0, y or 0, r or 0
  sx = sx or 1
  sy = sy or sx
  ox, oy = ox or 0, oy or 0
  -- the origin point in world pixels, and the picture's bottom middle
  local wx, wy = x + cam.x, y + cam.y
  local bx = wx + (w / 2 - ox) * sx
  local by = wy + (h - oy) * sy
  nCaught = nCaught + 1
  local c = caught[nCaught]
  if not c then c = {}; caught[nCaught] = c end
  local ent = figureUnder(liveState, bx, by)
  c.ent = ent
  if ent then
    c.offX, c.offY = wx - (ent.px + 8), wy - (ent.py + 16)
  else
    c.ax, c.ay = bx, by
    c.offX, c.offY = wx - bx, wy - by
  end
  c.drawable, c.quad, c.r, c.sx, c.sy, c.ox, c.oy = drawable, quad, r, sx, sy, ox, oy
  c.cr, c.cg, c.cb, c.ca = lg.getColor()
end

local function recorder(drawable, a, ...)
  if armed and lg.getCanvas() == baseCanvas and type(drawable) == "userdata" then
    if type(a) == "number" or a == nil then
      pcall(record, drawable, nil, a, ...)
    elseif type(a) == "userdata" and a.typeOf and a:typeOf("Quad") then
      pcall(record, drawable, a, ...)
    end
  end
  return realDraw(drawable, a, ...)
end

local function disarm()
  if armed then
    armed = false
    lg.draw = realDraw
  end
end

-- Called by the diorama when its frame is finished (main.lua, the end of
-- the drawWorld pipeline): from here until drawWorld returns, a draw into
-- drawWorld's own canvas is a mod painting over the map. Only inside our
-- own wrapper -- armed anywhere else there would be nobody to disarm it.
function WorldPostDraw.arm()
  if depth > 0 and not armed and realDraw
     and not OverlayHooks.claimsPostDraw() then
    armed = true
    lg.draw = recorder
  end
end

local function wrap(inner)
  local function wrapper(self, ...)
    if depth > 0 then return inner(self, ...) end
    depth = depth + 1
    -- last frame's catch becomes this frame's to draw
    caught, shown = shown, caught
    nShown, nCaught = nCaught, 0
    baseCanvas, liveState = lg.getCanvas(), self
    local ok, a, b = pcall(inner, self, ...)
    disarm()
    depth = depth - 1
    baseCanvas, liveState = nil, nil
    -- drop what no longer belongs to anyone (a record keeps its figure)
    for i = nCaught + 1, #caught do caught[i].ent, caught[i].drawable = nil, nil end
    if not ok then error(a, 0) end
    return a, b
  end
  ours[wrapper] = true
  return wrapper
end

-- Put our wrapper on the outside of drawWorld, once per change: a mod that
-- wraps it after us is wrapped in turn, and ours inside it stands aside
-- (depth) so only the outermost listens.
function WorldPostDraw.ensure()
  if not (OverworldState and realDraw) then return end
  local fn = OverworldState.drawWorld
  if type(fn) == "function" and not ours[fn] then
    OverworldState.drawWorld = wrap(fn)
  end
end

-- Last frame's catch, through this camera. In the overlay pass.
function WorldPostDraw.draw(project, scale)
  if nShown == 0 then return end
  local r0, g0, b0, a0 = lg.getColor()
  for i = 1, nShown do
    local c = shown[i]
    local ax, ay
    if c.ent then
      ax, ay = c.ent.px and (c.ent.px + 8), c.ent.py and (c.ent.py + 16)
    else
      ax, ay = c.ax, c.ay
    end
    local sx, sy = nil, nil
    if ax and ay and c.drawable then sx, sy = project(ax, 0, ay) end
    if sx then
      lg.setColor(c.cr, c.cg, c.cb, c.ca)
      local x = math.floor(sx + c.offX * scale + 0.5)
      local y = math.floor(sy + c.offY * scale + 0.5)
      if c.quad then
        realDraw(c.drawable, c.quad, x, y, c.r, c.sx * scale, c.sy * scale, c.ox, c.oy)
      else
        realDraw(c.drawable, x, y, c.r, c.sx * scale, c.sy * scale, c.ox, c.oy)
      end
    end
  end
  lg.setColor(r0, g0, b0, a0)
end

return WorldPostDraw
