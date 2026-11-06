-- Voxel world mode: Cerulean City's buildings OUTSIDE -- its three homes,
-- the four houses of its streets, the Bike Shop and Misty's Gym. (Its
-- Centre and Mart are Lavender's, in Cerulean's colours:
-- lib/LavenderCivicKit.lua, TOWNS.)
--
-- Four drawings, each already a template (data/voxel_heights.lua): the
-- wide 6x2 house (`gabled_house_wide`, 96 x 32, a door on the left), the
-- same house without a door (`gabled_block_6x2`), the flat block
-- (`flat_commercial`, 64 x 64) and the big-city Gym (`gym_large`, 128 x 64).
-- Built from lib/HouseLib.lua in the village's language -- a stone plinth,
-- white trim, a roof told apart by its form -- in Cerulean's colours: the
-- city on the water, white and pale blue render, deep blue slate.
--
--   BADGE    the house of the man who tells of the badges (16:20): white
--            render, blue shutters, a little garden gate round to his back
--            door on the north side (the game's second warp)
--   TRADE    the trade house (24:28), in Yellow Melanie's home where the
--            Bulbasaur waits: cream weatherboard, a window box of yellow
--            flowers, a bench by the door
--   TRASHED  the house the Rocket broke into (52:20): its back wall broken
--            through to the north (his way out, the second warp), rubble
--            spilled at the foot of the hole, a board nailed half over it
--   STREET   the four doorless houses: render under slate, two each in
--            white and pale blue, shutters in the town's blue
--   BIKES    the Bike Shop: a shop front of big windows under a striped
--            awning, a bicycle on its sign, two in the window
--   GYM      Misty's Gym, the Cerulean Gym: a white hall with a sea-blue
--            fascia carrying GYM twice in white letters, a wave course of
--            blue tiles along the plinth, a hipped slate roof cut flat
--
-- Chosen ONLY for these placements on CERULEAN_CITY (lib/HouseKits.lua).
-- The plot, the door and the warp lane are the template's: nothing below
-- head height stands in the door's cell. Coordinates are the plot's: x
-- east, z south, y up. Nothing here is extracted from the ROM; no Nintendo
-- mark.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/cerulean_houses.png",
              SHEET_W = Lib.SHEET_W, SHEET_H = Lib.SHEET_H }
Kit.MAP = "CERULEAN_CITY"
-- ...and Bill's cottage on the cape at Route 25's end (`gabled_house`, 64 x 48)
Kit.MAPS = { CERULEAN_CITY = true, ROUTE_25 = true }
Kit.TEMPLATES = { gabled_house_wide = true, gabled_block_6x2 = true,
                  flat_commercial = true, gym_large = true, gabled_house = true }

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local sw = Lib.sw
local R = Lib.ROWS
Kit.GLASS_UV = { 0, R.GLASS / Kit.SHEET_H, 1, (R.LIGHT + 1) / Kit.SHEET_H }

local M = Lib.materials(R)
local SLATES = M.shingle(R.SLATE)
local WHITE_RENDER = M.stucco(R.WEATHER)
local BLUE_RENDER = M.stucco(R.LILAC)
local CREAM_RENDER = M.stucco(R.CREAM)

-- ------------------------------------------------------- the wide house
-- a 96 x 32 plot: walls 5..90, 4..27, a gable roof along x
local function wide(o)
  local Z1 = 27
  local win = {}
  for _, c in ipairs(o.door and { 50, 72 } or { 26, 48, 70 }) do
    win[#win + 1] = { face = "s", c = c, w2 = 5, y0 = 8, y1 = 18, shut = o.shut, box = o.box }
  end
  win[#win + 1] = { face = "e", c = 16, w2 = 4, y0 = 8, y1 = 18, shut = o.shut }
  win[#win + 1] = { face = "w", c = 16, w2 = 4, y0 = 8, y1 = 18, shut = o.shut }
  for _, c in ipairs({ 28, 68 }) do
    win[#win + 1] = { face = "n", c = c, w2 = 4, y0 = 8, y1 = 18 }
  end
  return Lib.house({
    R = R, W = 96, D = 32, x0 = 5, x1 = 90, z0 = 4, z1 = Z1, wall = 24, plinth = 4,
    salt = o.salt, ytop = 50,
    skin = function() return o.skin end, quoin = R.STONE,
    roof = Lib.gableEW(2, 93, 1, 30, 25, 0.95), tile = SLATES, ridgeRow = R.SLATE_DK,
    door = o.door,
    chimney = { x = o.chimneyX or 70, z = 8, top = 46 },
    windows = win, extra = o.extra,
  })
end

-- the badge man's house: a gate and a path round to the back door
local function badge()
  return wide({ salt = 3, skin = WHITE_RENDER, shut = R.BLUE, door = R.BLUE,
    extra = function(x, y, z)
      -- a low picket gate east of the house end, white
      if x >= 91 and x <= 94 and z >= 10 and z <= 22 then
        if y >= 1 and y <= 7 and (z % 3 == 1 or y == 6) then return true, sw(R.WHITE, 5) end
        return false
      end
      return false
    end })
end

-- the trade house (Melanie's in Yellow): weatherboard, flowers, a bench
local function trade()
  return wide({ salt = 4, skin = M.clapboard(R.CREAM), shut = R.BLUE, door = R.GREEN,
    box = R.FLOWER, chimneyX = 74,
    extra = function(x, y, z)
      -- a bench right of the door against the front wall
      if z >= 28 and z <= 30 and x >= 34 and x <= 43 then
        if y >= 1 and y <= 3 and (x == 35 or x == 42) then return true, sw(R.TIMBER, 3) end
        if y == 4 then return true, sw(R.WOOD, 5 - (z == 30 and 1 or 0)) end
        if z == 28 and y >= 5 and y <= 8 then return true, sw(R.WOOD, y == 8 and 6 or 4) end
      end
      return false
    end })
end

-- the robbed house: the north wall broken through, rubble, a board
local function trashed()
  local HX0, HX1 = 22, 33              -- the hole, behind the door's column
  return wide({ salt = 5, skin = BLUE_RENDER, shut = R.BLUE, door = R.BLUE,
    extra = function(x, y, z)
      if x >= HX0 - 2 and x <= HX1 + 2 and z >= 2 and z <= 6 then
        local cx = (HX0 + HX1) / 2
        local edge = floor(abs(x - cx) * 1.6 + ((x * 7 + y * 3) % 3))
        local top = 19 - max(0, edge - 6)
        if z >= 4 and z <= 6 and x >= HX0 and x <= HX1 and y >= 1 and y <= top then
          -- the hole through the wall, dark; a plank nailed across it
          if y == 11 and z == 4 and x >= HX0 + 1 then return true, sw(R.WOOD, 4) end
          return true, (z == 4) and nil or sw(R.SHADOW, 1)
        end
        -- rubble at its foot outside
        if z <= 3 and y <= 2 - floor(abs(x - cx) / 4) and (x + z * 3) % 4 ~= 0 then
          return true, sw(R.STONE, 2 + (x + y + z) % 4)
        end
      end
      return false
    end })
end

local STREET = {
  function() return wide({ salt = 6, skin = WHITE_RENDER, shut = R.BLUE }) end,
  function() return wide({ salt = 7, skin = BLUE_RENDER, shut = R.BLUE, box = R.FLOWER }) end,
  function() return wide({ salt = 8, skin = BLUE_RENDER, shut = R.GREEN, chimneyX = 22 }) end,
  function() return wide({ salt = 9, skin = WHITE_RENDER, shut = R.GREEN, box = R.FLOWER }) end,
}

-- ------------------------------------------------------------ the shop
-- a bicycle, side on, in a 13 x 8 box: two wheels, a frame, a saddle
local function bike(u, v)
  local function ring(cu, cv)
    local d = math.sqrt((u - cu) ^ 2 + (v - cv) ^ 2)
    return d >= 2.2 and d <= 3.1
  end
  if ring(3, 3) or ring(10, 3) then return "W" end
  if v == 4 and u >= 4 and u <= 9 then return "F" end
  if (u - 3) == (v - 3) * 1 and u >= 3 and u <= 6 and v >= 3 then return "F" end
  if u == 9 and v >= 3 and v <= 6 then return "F" end
  if v == 7 and u >= 5 and u <= 7 then return "S" end
  if v == 7 and u >= 9 and u <= 11 then return "F" end
  return nil
end

local function bikes()
  local Z1 = 59
  local windows = {}
  windows[#windows + 1] = { face = "s", c = 46, w2 = 9, y0 = 4, y1 = 18 }
  for _, c in ipairs({ 20, 44 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 4, y0 = 8, y1 = 20 }
    windows[#windows + 1] = { face = "w", c = c, w2 = 4, y0 = 8, y1 = 20 }
    windows[#windows + 1] = { face = "n", c = c + 0, w2 = 4, y0 = 8, y1 = 20 }
  end
  return Lib.house({
    R = R, W = 64, D = 64, x0 = 4, x1 = 59, z0 = 8, z1 = Z1, wall = 36, plinth = 4,
    salt = 10, ytop = 46,
    skin = function(y)
      if y >= 26 and y <= 33 then return function() return sw(R.BLUE, 3) end end   -- the fascia
      return M.brick
    end,
    quoin = R.WHITE,
    roof = Lib.hip(2, 61, 6, 61, 37, Lib.pitchOf(0.4), 40), tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.BLUE, windows = windows,
    extra = function(x, y, z)
      -- the sign: a bicycle in white on the blue fascia, a voxel proud
      if z == Z1 + 1 and y >= 26 and y <= 33 and x >= 30 and x <= 42 then
        local k = bike(x - 30, y - 26)
        if k then return true, sw(R.WHITE, k == "S" and 4 or 6) end
      end
      -- a striped awning over the shop window, sloping out
      if x >= 35 and x <= 57 and z > Z1 and z <= Z1 + 4 then
        local ay = 22 - (z - Z1)
        if y == ay then return true, sw(floor((x - 35) / 3) % 2 == 0 and R.BLUE or R.WHITE, 5) end
      end
      -- two bicycles in the window, behind the glass
      if z == Z1 - 3 and x >= 38 and x <= 56 and y >= 4 and y <= 12 then
        local u = (x - 38) % 10
        local k = u <= 9 and bike(u + 1, y - 4)
        if k then return true, sw(k == "W" and R.IRON or R.RED, k == "W" and 2 or 4) end
      end
      return false
    end,
  })
end

-- ---------------------------------------------------------------- the Gym
local GYM = { "XXXXX.X...X.X...X",
              "X......X.X..XX.XX",
              "X.......X...X.X.X",
              "X..XX...X...X...X",
              "X...X...X...X...X",
              "X...X...X...X...X",
              "XXXXX...X...X...X" }

local function gym()
  local Z1 = 54
  local roof = Lib.hip(1, 126, 4, 58, 37, Lib.pitchOf(0.75), 50)
  local function skin(y)
    if y >= 25 and y <= 32 then return function() return sw(R.BLUE, 3) end end
    if y == 24 or y == 33 then return function() return sw(R.WHITE, 6) end end
    return function(u, yy, salt)
      -- a wave course of blue tiles along the plinth's top
      if yy >= 6 and yy <= 8 then
        local w = floor(1.2 * math.sin(u * 0.55)) + 7
        if yy == w then return sw(R.BLUE, 5) end
        return sw(R.LILAC, 4 + (yy == 6 and 0 or 1))
      end
      if u % 16 < 2 then return sw(R.WHITE, 5) end
      return WHITE_RENDER(u, yy, salt)
    end
  end
  local windows = {}
  for _, c in ipairs({ 13, 25, 37, 49, 61, 73, 85 }) do
    windows[#windows + 1] = { face = "s", c = c, w2 = 4, y0 = 10, y1 = 21, arch = true }
  end
  windows[#windows + 1] = { face = "s", c = 119, w2 = 3, y0 = 10, y1 = 21, arch = true }
  for _, c in ipairs({ 18, 32, 46 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 4, y0 = 10, y1 = 21, arch = true }
    windows[#windows + 1] = { face = "w", c = c, w2 = 4, y0 = 10, y1 = 21, arch = true }
  end
  for _, c in ipairs({ 22, 50, 78, 106 }) do
    windows[#windows + 1] = { face = "n", c = c, w2 = 4, y0 = 10, y1 = 21, arch = true }
  end
  return Lib.house({
    R = R, W = 128, D = 64, x0 = 4, x1 = 123, z0 = 8, z1 = Z1, wall = 36, plinth = 5,
    salt = 6, ytop = 66, doorX0 = 97, doorX1 = 110,
    skin = skin, quoin = R.WHITE,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.BLUE, porch = true,
    windows = windows,
    extra = function(x, y, z)
      -- GYM twice on the fascia in white, as the drawing hangs it
      if z == Z1 + 1 and y >= 26 and y <= 32 then
        for _, x0 in ipairs({ 31, 63 }) do
          if x >= x0 and x <= x0 + 16 and Lib.glyph(GYM, x0, 32, x, y) then
            return true, sw(R.WHITE, 6 + (y % 2))
          end
        end
      end
      return false
    end,
  })
end

-- ---------------------------------------------------- Bill's sea cottage
-- The Pokemaniac who built the storage system lives at the cape: white
-- weatherboard under blue slate, a round porthole window up in the gable,
-- a lattice radio mast on the roof for his network, a rain barrel by the
-- door, a weather vane.
local function bills()
  local Z1 = 38
  local roof = Lib.gableEW(2, 61, 4, 42, 37, 0.95)
  return Lib.house({
    R = R, W = 64, D = 48, x0 = 5, x1 = 58, z0 = 8, z1 = Z1, wall = 36, plinth = 4,
    salt = 11, ytop = 74,
    skin = function() return M.clapboard(R.WEATHER) end, quoin = R.WHITE,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.BLUE, porch = true,
    chimney = { x = 12, z = 12, top = 58 },
    windows = { { face = "s", c = 44, w2 = 6, y0 = 8, y1 = 18, shut = R.BLUE, box = R.FLOWER },
                { face = "s", c = 44, w2 = 5, y0 = 24, y1 = 33, shut = R.BLUE },
                { face = "e", c = 23, w2 = 5, y0 = 8, y1 = 18 },
                { face = "w", c = 23, w2 = 5, y0 = 8, y1 = 18 },
                { face = "e", c = 23, w2 = 3, y0 = 38, y1 = 44, arch = true },
                { face = "w", c = 23, w2 = 3, y0 = 38, y1 = 44, arch = true },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
    extra = function(x, y, z)
      -- the radio mast: a lattice tower astride the ridge at x 46, a dish
      local mx, mz = 46, 23
      local top = select(1, roof(mx, mz))
      if top and abs(x - mx) <= 1.5 and abs(z - mz) <= 1.5 and y > top and y <= top + 16 then
        local hy = y - top
        local corner = abs(x - mx) >= 1 and abs(z - mz) >= 1
        if corner then return true, sw(R.IRON, 3 + hy % 2) end
        if hy % 4 == 0 then return true, sw(R.IRON, 4) end
        return false
      end
      if top and y >= top + 12 and y <= top + 15 and z == mz + 2 and abs(x - mx) <= 2.5 then
        return true, sw(R.WHITE, 5)                                     -- the dish
      end
      -- a rain barrel right of the door
      local bx, bz = 36.5, Z1 + 3
      local d = (x - bx) ^ 2 + (z - bz) ^ 2
      if d <= 5.5 and y >= 1 and y <= 9 then
        if y == 9 and d <= 2.5 then return true, sw(R.SHADOW, 2) end
        if y == 3 or y == 7 then return true, sw(R.IRON, 3) end
        return true, sw(R.WOOD, 3 + (x + y) % 2)
      end
      return false
    end,
  })
end

-- Which building stands on the placement whose top-left TILE is (tx, ty).
Kit.PLACES = { ["16:20"] = badge, ["24:28"] = trade, ["52:20"] = trashed,
               ["28:20"] = STREET[1], ["68:20"] = STREET[2],
               ["36:48"] = STREET[3], ["56:48"] = STREET[4],
               ["24:44"] = bikes, ["48:32"] = gym,
               ["88:2"] = bills }                                     -- ROUTE_25

function Kit.model(sp, t, tx, ty)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local make = Kit.PLACES[tostring(tx) .. ":" .. tostring(ty)]
  if not make then return nil, "no building of Cerulean's stands at " .. tostring(tx) .. ":" .. tostring(ty) end
  return make()
end

return Kit
