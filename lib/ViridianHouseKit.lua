-- Voxel world mode: Viridian City's buildings OUTSIDE -- its two cottages
-- and its Gym. (Its Centre and Mart are Lavender's, in Viridian's colours:
-- lib/LavenderCivicKit.lua, TOWNS.)
--
-- The cottages are one drawing (data/voxel_heights.lua `gabled_cottage`,
-- 64 x 32: a roof with its ends turned down, a door on the left, a window on
-- the right), the Gym another (`gym`, 96 x 64: a deep roof band, the GYM
-- sign over a row of windows, the door at the right). Built from
-- lib/HouseLib.lua in the village's language -- a stone plinth, white trim,
-- a roof told apart by its form -- in Viridian's colours: the town at the
-- forest's edge, warm grey stone, sage and cream render, dark green slate.
--
--   SPEARY   the cottage of the father, his girl and the Spearow she named
--            (the north one): cream render under a gabled slate roof, green
--            shutters, yellow flowers in a box, and a bird house on a post
--            by the door for Speary
--   SCHOOL   the Trainer School (the south one): brick under a hipped
--            slate roof with a little bell cote on its ridge, white quoins,
--            two tall windows, a notice board by the door
--   GYM      Viridian's Gym, the last in Kanto: a stone hall, pilasters
--            between tall windows, a dark green fascia with GYM in gold
--            letters, a hipped roof cut off flat in lead, lanterns at the
--            door
--
-- Each is the outside of its inside: Speary's moss and cream, the school's
-- brick. Chosen ONLY for these placements on VIRIDIAN_CITY
-- (lib/HouseKits.lua). The plot, the door (the drawing's door columns) and
-- the warp lane are the template's: nothing below head height stands in
-- the door's cell.
--
-- Coordinates are the plot's: x east, z south, y up. A person is sixteen
-- voxels. Nothing here is extracted from the ROM; no Nintendo mark.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/viridian_houses.png",
              SHEET_W = Lib.SHEET_W, SHEET_H = Lib.SHEET_H }
Kit.MAP = "VIRIDIAN_CITY"
Kit.TEMPLATES = { gabled_cottage = true, gym = true }

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local sw = Lib.sw
local R = Lib.ROWS
Kit.GLASS_UV = { 0, R.GLASS / Kit.SHEET_H, 1, (R.LIGHT + 1) / Kit.SHEET_H }

local M = Lib.materials(R)
local RENDER = M.stucco(R.CREAM)
local SLATES = M.shingle(R.SLATE)

-- ---------------------------------------------------------------- Speary's
local function speary()
  local Z1 = 27
  return Lib.house({
    R = R, W = 64, D = 32, x0 = 5, x1 = 58, z0 = 4, z1 = Z1, wall = 24, plinth = 4,
    salt = 4, ytop = 50,
    skin = function() return RENDER end, quoin = R.STONE,
    roof = Lib.gableEW(2, 61, 1, 30, 25, 0.95), tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.GREEN,
    chimney = { x = 46, z = 8, top = 46 },
    windows = { { face = "s", c = 41, w2 = 5, y0 = 8, y1 = 18, shut = R.GREEN, box = R.FLOWER },
                { face = "e", c = 16, w2 = 4, y0 = 8, y1 = 18, shut = R.GREEN },
                { face = "w", c = 16, w2 = 4, y0 = 8, y1 = 18, shut = R.GREEN },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
    extra = function(x, y, z)
      -- the bird house on its post, left of the door: a post to y 16, a box
      -- with a round hole facing the street, a little pitched roof, a perch
      if x >= 8 and x <= 13 and z >= Z1 + 1 and z <= Z1 + 4 then
        if x >= 10 and x <= 11 and z >= Z1 + 2 and z <= Z1 + 3 and y >= 1 and y <= 16 then
          return true, M.timber(x, y)
        end
        if y >= 17 and y <= 21 then
          if z == Z1 + 4 and y == 19 and (x == 10 or x == 11) then return true, sw(R.SHADOW, 0) end
          if z == Z1 + 4 and y == 17 and (x == 10 or x == 11) then return true, sw(R.WOOD, 6) end
          return true, sw(R.WOOD, 3 + (x + y) % 2)
        end
        local ry = 22 + floor(min(x - 8, 13 - x) * 0.8)
        if y >= 22 and y <= ry then return true, sw(R.SLATE, 4 + (x % 2)) end
      end
      return false
    end,
  })
end

-- ------------------------------------------------------------- the school
local function school()
  local Z1 = 27
  local roof = Lib.hip(2, 61, 1, 30, 25, Lib.pitchOf(0.9))
  local CX, CZ = 31.5, 15.5                 -- the bell cote, astride the ridge
  local TOP = select(1, roof(31, 15))
  return Lib.house({
    R = R, W = 64, D = 32, x0 = 5, x1 = 58, z0 = 4, z1 = Z1, wall = 24, plinth = 4,
    salt = 5, ytop = 56,
    skin = function() return M.brick end, quoin = R.WHITE,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.BLUE, porch = true,
    windows = { { face = "s", c = 41, w2 = 4, y0 = 7, y1 = 20, arch = true },
                { face = "s", c = 53, w2 = 3, y0 = 7, y1 = 20, arch = true },
                { face = "e", c = 16, w2 = 4, y0 = 7, y1 = 20, arch = true },
                { face = "w", c = 16, w2 = 4, y0 = 7, y1 = 20, arch = true },
                { face = "n", c = 22, w2 = 4, y0 = 7, y1 = 20, arch = true },
                { face = "n", c = 42, w2 = 4, y0 = 7, y1 = 20, arch = true } },
    extra = function(x, y, z)
      -- the bell cote: four posts, a bell hung in them, a little hipped cap
      local dx, dz = abs(x - CX), abs(z - CZ)
      if TOP and dx <= 3.5 and dz <= 3.5 and y > TOP and y <= TOP + 13 then
        local hy = y - TOP
        if hy <= 8 then
          if dx >= 2.5 and dz >= 2.5 then return true, sw(R.WHITE, 5) end       -- posts
          if hy == 1 then return true, sw(R.WHITE, 4) end                       -- its floor
          local br = 1.6 - (hy - 3) * 0.12                                      -- the bell
          if hy >= 3 and hy <= 7 and (x - CX) ^ 2 + (z - CZ) ^ 2 <= br * br + 0.6 then
            return true, sw(R.GOLD, 3 + (hy % 2))
          end
          return false
        end
        local cap = 4 - (hy - 9)
        if dx <= cap and dz <= cap then return true, SLATES(x + z, hy, 5) end
        return false
      end
      -- the notice board by the door, on two legs
      if z == Z1 + 2 and x >= 35 and x <= 44 then
        if y >= 1 and y <= 8 and (x == 36 or x == 43) then return true, M.timber(x, y) end
        if y >= 9 and y <= 15 then
          if x == 35 or x == 44 or y == 9 or y == 15 then return true, sw(R.TIMBER, 4) end
          if (y == 13 and x >= 37 and x <= 40) or (y == 11 and x >= 38 and x <= 42) then
            return true, sw(R.WHITE, 6)                                         -- pinned papers
          end
          return true, sw(R.WOOD, 5)
        end
      end
      return false
    end,
  })
end

-- ---------------------------------------------------------------- the Gym
-- the letters of its sign, five wide and seven tall
local GYM = { "XXXXX.X...X.X...X",
              "X......X.X..XX.XX",
              "X.......X...X.X.X",
              "X..XX...X...X...X",
              "X...X...X...X...X",
              "X...X...X...X...X",
              "XXXXX...X...X...X" }

local function gym()
  local Z1 = 54
  local CAP = 50
  local roof = Lib.hip(1, 94, 4, 58, 37, Lib.pitchOf(0.75), CAP)
  -- stone below the string course, render above, a pilaster every twelve
  local function skin(y)
    if y >= 25 and y <= 32 then return function() return sw(R.GREEN, 3) end end
    if y == 24 or y == 33 then return function() return sw(R.WHITE, 5) end end
    return function(u, yy, salt)
      if u % 12 < 2 then return sw(R.STONE, 5 + floor(yy / 4) % 2) end
      if yy <= 12 then return M.stone(u, yy, salt) end
      return RENDER(u, yy, salt)
    end
  end
  local windows = {}
  for _, c in ipairs({ 13, 25, 37, 49 }) do
    windows[#windows + 1] = { face = "s", c = c, w2 = 4, y0 = 9, y1 = 21, arch = true }
  end
  windows[#windows + 1] = { face = "s", c = 86, w2 = 3, y0 = 9, y1 = 21, arch = true }
  for _, c in ipairs({ 18, 32, 46 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 4, y0 = 9, y1 = 21, arch = true }
    windows[#windows + 1] = { face = "w", c = c, w2 = 4, y0 = 9, y1 = 21, arch = true }
  end
  for _, c in ipairs({ 20, 48, 76 }) do
    windows[#windows + 1] = { face = "n", c = c, w2 = 4, y0 = 9, y1 = 21, arch = true }
  end
  return Lib.house({
    R = R, W = 96, D = 64, x0 = 4, x1 = 91, z0 = 8, z1 = Z1, wall = 36, plinth = 5,
    salt = 6, ytop = 66, doorX0 = 65, doorX1 = 78,
    skin = skin, quoin = R.STONE,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.GREEN, porch = true,
    windows = windows,
    lights = { { x = 61, y = 16, z = Z1 + 2 } },
    extra = function(x, y, z)
      -- the sign: GYM in gold letters on the fascia, a voxel proud of it
      if z == Z1 + 1 and y >= 26 and y <= 32 and x >= 31 and x <= 47 then
        if Lib.glyph(GYM, 31, 32, x, y) then return true, sw(R.GOLD, 5 + (y % 2)) end
      end
      -- a second lantern, left of the door (HouseLib stands one right of it)
      if x >= 60 and x <= 62 and z >= Z1 + 1 and z <= Z1 + 3 and y >= 13 and y <= 19 then
        if y == 19 or y == 13 then return true, sw(R.IRON, 3) end
        if x == 61 and z == Z1 + 2 then return true, sw(R.LIGHT, 5) end
        if (x + z) % 2 == 0 then return true, sw(R.IRON, 3) end
        return true, sw(R.LIGHT, 3)
      end
      return false
    end,
  })
end

-- Which building stands on the placement whose top-left TILE is (tx, ty).
Kit.PLACES = { ["40:16"] = speary, ["40:28"] = school, ["56:8"] = gym }

function Kit.model(sp, t, tx, ty)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local make = Kit.PLACES[tostring(tx) .. ":" .. tostring(ty)]
  if not make then return nil, "no building of Viridian's stands at " .. tostring(tx) .. ":" .. tostring(ty) end
  return make()
end

return Kit
