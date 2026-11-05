-- Voxel world mode: other mods' drawings in the diorama's overlay pass.
--
-- When the diorama is on, the engine's world canvas is never shown: the
-- pipeline hands the renderer a finished image of its own and the canvas is
-- skipped whole (src/render/Renderer.lua, the worldOverride blit). So a mod
-- that paints the map with love.graphics after OverworldState.drawWorld --
-- the only way to draw an arbitrary picture over a Gen 1 map, since Gen 1
-- has no emote bubble that takes one -- paints into nothing, and its
-- picture is simply gone in 3D.
--
-- This is the place for it instead. A function registered here runs once
-- per 3D frame inside the same overlay as the field effects, the ambient
-- life and the fishing line, with the same two arguments they get:
--
--   fn(project, scale, state)
--     project(wx, wy, wz) -> sx, sy   a world point (wy = height, world px)
--                                     to canvas pixels; nil behind the camera
--     scale                           canvas pixels per world pixel
--     state                           the OverworldState being drawn
--
-- so a picture anchored at a world point lands where that point is under
-- this camera. Other mods reach it as
--
--   game.mods.exports.TERRARIUM.overlay.add(fn [, claims]) / .remove(fn)
--
-- `claims` = true says "what I used to paint over the map after drawWorld,
-- I now draw here": while such a hook is registered, lib/WorldPostDraw.lua
-- stops catching those paints, so the picture is not drawn twice in 3D.
--
-- A function that throws is dropped (and logged once) rather than let it
-- throw every frame: the engine retires a pipeline that throws, and one
-- bad overlay must not take the whole diorama with it.

-- the mod namespace (see main.lua); nothing here needs a sibling
local V = ...  -- luacheck: ignore

local OverlayHooks = {}

local list = {}
local claiming = {}        -- the hooks that took over their post-draw paints
local nClaiming = 0

function OverlayHooks.add(fn, claims)
  if type(fn) ~= "function" then return false end
  local known = false
  for i = 1, #list do if list[i] == fn then known = true end end
  if not known then list[#list + 1] = fn end
  if claims and not claiming[fn] then
    claiming[fn] = true
    nClaiming = nClaiming + 1
  end
  return true
end

local function forget(fn)
  if claiming[fn] then
    claiming[fn] = nil
    nClaiming = nClaiming - 1
  end
end

function OverlayHooks.remove(fn)
  for i = #list, 1, -1 do
    if list[i] == fn then table.remove(list, i) end
  end
  forget(fn)
end

-- true while some hook draws, here, what it used to paint after drawWorld
function OverlayHooks.claimsPostDraw() return nClaiming > 0 end

function OverlayHooks.count() return #list end

function OverlayHooks.draw(project, scale, state)
  local i = 1
  while i <= #list do
    local fn = list[i]
    local ok, err = pcall(fn, project, scale, state)
    if ok then
      i = i + 1
    else
      table.remove(list, i)
      forget(fn)
      print("[TERRARIUM] overlay hook dropped after an error: " .. tostring(err))
    end
  end
end

return OverlayHooks
