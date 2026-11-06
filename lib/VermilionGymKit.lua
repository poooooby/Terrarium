-- Voxel world mode: Lt. Surge's Gym in Vermilion OUTSIDE -- the one building
-- of the harbour town the developer's kits (lib/VermilionHouseKit.lua) left
-- to the generic pass.
--
-- The drawing is the standard gym (data/voxel_heights.lua `gym`, 96 x 64).
-- What stands here, in the harbour's language and the developer's colours
-- (tools/town_houses.py "vermilion", read off his sheet): a hall of red
-- brick on a stone plinth, the electric man's gym -- a steel fascia with GYM
-- in gold, a lightning flash beside it, a hipped terracotta roof cut flat in
-- lead with a lattice mast and two insulator arms on it, tall windows,
-- lanterns at the door.
--
-- Built from lib/HouseLib.lua. Chosen ONLY for the gym on VERMILION_CITY
-- (lib/HouseKits.lua). Coordinates are the plot's: x east, z south, y up.
-- Nothing here is extracted from the ROM; no Nintendo mark.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/vermilion_houses_hl.png",
              SHEET_W = Lib.SHEET_W, SHEET_H = Lib.SHEET_H }
Kit.MAP = "VERMILION_CITY"
Kit.TEMPLATES = { gym = true }

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local sw = Lib.sw
local R = Lib.ROWS
Kit.GLASS_UV = { 0, R.GLASS / Kit.SHEET_H, 1, (R.LIGHT + 1) / Kit.SHEET_H }
local M = Lib.materials(R)

local GYM = { "XXXXX.X...X.X...X",
              "X......X.X..XX.XX",
              "X.......X...X.X.X",
              "X..XX...X...X...X",
              "X...X...X...X...X",
              "X...X...X...X...X",
              "XXXXX...X...X...X" }
-- a lightning flash, seven wide and eight tall
local BOLT = { "....XXX", "...XXX.", "..XXX..", ".XXXXXX", "...XXX.", "..XXX..", ".XX....", "X......" }

local function gym()
  local Z1 = 54
  local CAP = 50
  local roof = Lib.hip(1, 94, 4, 58, 37, Lib.pitchOf(0.75), CAP)
  local function skin(y)
    if y >= 25 and y <= 32 then return function() return sw(R.LEAD, 3) end end
    if y == 24 or y == 33 then return function() return sw(R.WHITE, 5) end end
    return function(u, yy, salt)
      if u % 16 < 2 and yy > 5 then return sw(R.STONE, 5 + floor(yy / 4) % 2) end   -- piers
      return M.brick(u, yy, salt)
    end
  end
  local windows = {}
  for _, c in ipairs({ 13, 25, 37, 49 }) do
    windows[#windows + 1] = { face = "s", c = c, w2 = 4, y0 = 9, y1 = 21 }
  end
  windows[#windows + 1] = { face = "s", c = 86, w2 = 3, y0 = 9, y1 = 21 }
  for _, c in ipairs({ 18, 32, 46 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 4, y0 = 9, y1 = 21 }
    windows[#windows + 1] = { face = "w", c = c, w2 = 4, y0 = 9, y1 = 21 }
  end
  for _, c in ipairs({ 20, 48, 76 }) do
    windows[#windows + 1] = { face = "n", c = c, w2 = 4, y0 = 9, y1 = 21 }
  end
  local MX, MZ = 30, 31            -- the mast on the lead flat
  return Lib.house({
    R = R, W = 96, D = 64, x0 = 4, x1 = 91, z0 = 8, z1 = Z1, wall = 36, plinth = 5,
    salt = 6, ytop = 78, doorX0 = 65, doorX1 = 78,
    skin = skin, quoin = R.STONE,
    roof = roof, tile = M.pantile, ridgeRow = R.TERRA_DK,
    door = R.BLUE, porch = true,
    windows = windows,
    lights = { { x = 61, y = 16, z = Z1 + 2 } },
    extra = function(x, y, z)
      -- the sign: GYM in gold on the lead fascia, a flash beside it
      if z == Z1 + 1 and y >= 26 and y <= 32 then
        if x >= 31 and x <= 47 and Lib.glyph(GYM, 31, 32, x, y) then return true, sw(R.GOLD, 5 + (y % 2)) end
        if x >= 51 and x <= 57 and Lib.glyph(BOLT, 51, 33, x, y + 0) then return true, sw(R.GOLD, 6) end
      end
      -- a second lantern, left of the door
      if x >= 60 and x <= 62 and z >= Z1 + 1 and z <= Z1 + 3 and y >= 13 and y <= 19 then
        if y == 19 or y == 13 then return true, sw(R.IRON, 3) end
        if x == 61 and z == Z1 + 2 then return true, sw(R.LIGHT, 5) end
        if (x + z) % 2 == 0 then return true, sw(R.IRON, 3) end
        return true, sw(R.LIGHT, 3)
      end
      -- the mast: a lattice tower on the flat, two insulator arms
      if y > CAP and y <= CAP + 26 then
        local dx, dz = x - MX, z - MZ
        local hy = y - CAP
        local half = 2.5 - hy * 0.06
        if abs(dx) <= half + 0.5 and abs(dz) <= half + 0.5 then
          local corner = abs(dx) >= half - 0.5 and abs(dz) >= half - 0.5
          if corner or hy % 5 == 0 then return true, sw(R.IRON, 3 + hy % 2) end
          return false
        end
        for _, ay in ipairs({ 18, 24 }) do
          if hy == ay and abs(dz) <= 0.5 and abs(dx) <= 7 then return true, sw(R.IRON, 4) end
          if hy == ay + 1 and abs(dz) <= 0.5 and (abs(dx) == 6 or abs(dx) == 7) then return true, sw(R.WHITE, 6) end
        end
      end
      return false
    end,
  })
end

Kit.PLACES = { ["16:32"] = gym }

function Kit.model(sp, t, tx, ty)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local make = Kit.PLACES[tostring(tx) .. ":" .. tostring(ty)]
  if not make then return nil, "no gym of Vermilion's stands at " .. tostring(tx) .. ":" .. tostring(ty) end
  return make()
end

return Kit
