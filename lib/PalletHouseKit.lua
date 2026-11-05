-- Voxel world mode: Pallet Town's buildings OUTSIDE -- Red's house, Blue's
-- house and Oak's lab.
--
-- Red's and Blue's are one drawing (data/voxel_heights.lua `gabled_house`,
-- 64 x 48: a gable over three upper windows, an awning band, the door and
-- a double window under it), Oak's lab another (`oaks_lab`, 96 x 64: a deep
-- roof, a clerestory and a ground row of windows in brick, the door in the
-- middle). Built from lib/HouseLib.lua -- VermilionHouseKit's house, made a
-- library -- in one language for the village: a pale stone plinth, white
-- trim, and told apart first by the roof, because what the camera sees of
-- a house is mostly its roof:
--
--   RED   white weatherboard under a red clay gable, a pent roof along the
--         whole front over the door (the drawing's awning band), a red door,
--         lilac shutters, a box of flowers under the double window
--   BLUE  cream render under a hipped roof of blue-grey slate, a little
--         tiled porch over a blue door, blue shutters and Daisy's flowers
--   LAB   brick with a white string course and stone quoins, a long low
--         slate hip with a glazed ridge and a copper vane, clerestory
--         lights over a row of tall windows, a green door under its porch
--
-- Each is the outside of its inside: Red's lilac-white rooms, Daisy's blue
-- stripe, the lab's white walls. Chosen ONLY for these placements on
-- PALLET_TOWN (lib/HouseKits.lua). The plot, the door (the drawing's door
-- columns) and the warp lane are the template's: nothing below head height
-- stands in the door's cell.
--
-- Coordinates are the plot's: x east, z south, y up. A person is sixteen
-- voxels. Nothing here is extracted from the ROM; no Nintendo mark is drawn.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/pallet_houses.png", SHEET_W = 8, SHEET_H = 28 }
Kit.MAP = "PALLET_TOWN"
Kit.TEMPLATES = { gabled_house = true, oaks_lab = true }

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local sw = Lib.sw

-- rows of the sheet (every town's houses sheet: HouseLib.ROWS, mirrored by
-- tools/town_houses.py)
local R = Lib.ROWS
-- the GLASS and LIGHT rows, neighbours, as a UV rect: VoxelScene lights them
Kit.GLASS_UV = { 0, R.GLASS / Kit.SHEET_H, 1, (R.LIGHT + 1) / Kit.SHEET_H }

local M = Lib.materials(R)
local WEATHERBOARD = M.clapboard(R.WEATHER)
local RENDER = M.stucco(R.CREAM)
local SLATES = M.shingle(R.SLATE)

-- ----------------------------------------------------------------- Red's
local function red()
  local Z1 = 38
  return Lib.house({
    R = R, W = 64, D = 48, x0 = 5, x1 = 58, z0 = 8, z1 = Z1, wall = 36, plinth = 4,
    salt = 1, ytop = 62,
    skin = function() return WEATHERBOARD end, quoin = R.WHITE,
    roof = Lib.gableEW(2, 61, 4, 42, 37, 0.95), tile = M.pantile,
    door = R.RED,
    chimney = { x = 44, z = 12, top = 60 },
    windows = { { face = "s", c = 40, w2 = 6, y0 = 8, y1 = 18, shut = R.LILAC, box = R.FLOWER },
                { face = "s", c = 20, w2 = 3, y0 = 26, y1 = 33 },
                { face = "s", c = 40, w2 = 5, y0 = 26, y1 = 33, shut = R.LILAC },
                { face = "e", c = 23, w2 = 4, y0 = 26, y1 = 33 },
                { face = "w", c = 23, w2 = 4, y0 = 26, y1 = 33 },
                { face = "e", c = 23, w2 = 5, y0 = 8, y1 = 18 },
                { face = "w", c = 23, w2 = 5, y0 = 8, y1 = 18 },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
    extra = function(x, y, z)
      -- the pent roof along the front over the door, between the storeys:
      -- the drawing's awning band, in the roof's own clay, on three brackets
      if x >= 4 and x <= 59 and z > Z1 and z <= Z1 + 4 then
        local py = 24 - floor((z - Z1) * 0.75)
        if y == py or y == py - 1 then return true, M.pantile(x, z - Z1, 1) end
        if (x == 6 or x == 57) and y >= 18 and y < py - 1 and y >= 22 - (Z1 + 4 - z) then
          return true, M.timber(x, y)
        end
      end
      return false
    end,
  })
end

-- ---------------------------------------------------------------- Blue's
local function blue()
  return Lib.house({
    R = R, W = 64, D = 48, x0 = 6, x1 = 57, z0 = 8, z1 = 38, wall = 36, plinth = 4,
    salt = 2, ytop = 62,
    skin = function() return RENDER end, quoin = R.STONE,
    roof = Lib.hip(3, 60, 5, 41, 37, Lib.pitchOf(0.85)), tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.BLUE, porch = true,
    chimney = { x = 44, z = 12, top = 58 },
    windows = { { face = "s", c = 40, w2 = 6, y0 = 8, y1 = 18, shut = R.BLUE, box = R.FLOWER },
                { face = "s", c = 20, w2 = 3, y0 = 26, y1 = 33, shut = R.BLUE },
                { face = "s", c = 40, w2 = 4, y0 = 26, y1 = 33, shut = R.BLUE, box = R.FLOWER },
                { face = "e", c = 23, w2 = 5, y0 = 8, y1 = 18, shut = R.BLUE },
                { face = "w", c = 23, w2 = 5, y0 = 8, y1 = 18, shut = R.BLUE },
                { face = "e", c = 23, w2 = 4, y0 = 26, y1 = 33 },
                { face = "w", c = 23, w2 = 4, y0 = 26, y1 = 33 },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
  })
end

-- -------------------------------------------------------------- the lab
local function lab()
  local Z1 = 54
  local roof = Lib.hip(1, 94, 5, 58, 35, Lib.pitchOf(0.6))
  -- the vane's mast stands on the ridge near its east end
  local VX, VZ = 76, 31
  local VTOP = roof(VX, VZ)
  local brick = M.brick
  -- brick, a white string course at y 23, brick again over it
  local function skin(y)
    if y == 23 or y == 24 then return function() return sw(R.WHITE, 5) end end
    return brick
  end
  return Lib.house({
    R = R, W = 96, D = 64, x0 = 4, x1 = 91, z0 = 8, z1 = Z1, wall = 34, plinth = 5,
    salt = 3, ytop = 72, doorX0 = 33, doorX1 = 46,
    skin = skin, quoin = R.STONE,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.GREEN, porch = true,
    windows = { { face = "s", c = 13, w2 = 4, y0 = 8, y1 = 19 }, { face = "s", c = 24, w2 = 4, y0 = 8, y1 = 19 },
                { face = "s", c = 57, w2 = 4, y0 = 8, y1 = 19 }, { face = "s", c = 68, w2 = 4, y0 = 8, y1 = 19 },
                { face = "s", c = 79, w2 = 4, y0 = 8, y1 = 19 },
                { face = "s", c = 13, w2 = 3, y0 = 27, y1 = 31 }, { face = "s", c = 24, w2 = 3, y0 = 27, y1 = 31 },
                { face = "s", c = 57, w2 = 3, y0 = 27, y1 = 31 }, { face = "s", c = 68, w2 = 3, y0 = 27, y1 = 31 },
                { face = "s", c = 79, w2 = 3, y0 = 27, y1 = 31 },
                { face = "e", c = 22, w2 = 4, y0 = 8, y1 = 19 }, { face = "e", c = 40, w2 = 4, y0 = 8, y1 = 19 },
                { face = "w", c = 22, w2 = 4, y0 = 8, y1 = 19 }, { face = "w", c = 40, w2 = 4, y0 = 8, y1 = 19 },
                { face = "n", c = 30, w2 = 4, y0 = 8, y1 = 19 }, { face = "n", c = 66, w2 = 4, y0 = 8, y1 = 19 } },
    extra = function(x, y, z)
      -- the glazed ridge: the top course of the roof near its crest is glass
      -- in iron bars, the hall's daylight
      local top, _, d = roof(x, z)
      if top and y == top and d >= 21 and x >= 22 and x <= 73 then
        if x % 6 == 0 then return true, sw(R.IRON, 3) end
        return true, sw(R.GLASS, 3 + (x + z) % 3)
      end
      -- the vane: a copper mast, an arrow across it with a split tail, a
      -- ball at the top
      if x == VX and z == VZ and y > VTOP and y <= VTOP + 12 then
        return true, sw(R.COPPER, y == VTOP + 12 and 6 or 3)
      end
      if z == VZ and x >= VX - 5 and x <= VX + 4 then
        local ax = x - VX
        if y == VTOP + 9 then return true, sw(R.COPPER, ax == 4 and 6 or 4) end      -- shaft, point east
        if (y == VTOP + 10 or y == VTOP + 8) and (ax == -5 or ax == -4 or ax == 3) then
          return true, sw(R.COPPER, 5)                                               -- tail, barbs
        end
      end
      return false
    end,
  })
end

-- Which building stands on the placement whose top-left TILE is (tx, ty).
Kit.PLACES = { ["8:6"] = red, ["24:6"] = blue, ["20:16"] = lab }

function Kit.model(sp, t, tx, ty)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local make = Kit.PLACES[tostring(tx) .. ":" .. tostring(ty)]
  if not make then return nil, "no building of Pallet's stands at " .. tostring(tx) .. ":" .. tostring(ty) end
  return make()
end

return Kit
