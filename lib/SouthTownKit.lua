-- Voxel world mode: the buildings OUTSIDE of Saffron, Celadon, Fuchsia and
-- Cinnabar, and the houses on the routes between them.
--
-- These towns are drawn from a dozen shared drawings (data/voxel_heights.lua:
-- `gabled_house`, `gabled_block_4x3`/`4x2`/`6x2`, `gabled_cottage`, the flat
-- blocks `flat_commercial`, `flat_block_4x4`/`4x6`/`6x4`/`6x6`, the gyms, the
-- Game Corner's hall, Celadon's Mansion and store, Silph Co.'s tower), so one
-- kit reads them all and lets each town give them its own hand:
--
--   the plot     the template's own size (cols x rows x 8), the walls four
--                in from its edges, the front ten voxels short of it
--   the door     where the drawing draws it (its 11/12 pair); no door, a
--                building of the street that is not entered
--   the roof     by drawing: a gable along x on the gabled ones, a hip cut
--                flat in lead on the flat blocks; the storeys by its depth
--   the skin     the town's: Saffron brick and buff stone, Celadon white
--                render, Fuchsia timber over pink render, Cinnabar white
--                walls on lava stone -- picked per placement from the
--                town's few, so a street is not one house stamped
--
-- and the landmarks by their placement: Silph Co.'s tower (a glass curtain
-- wall in a steel frame, banded floors, a rooftop crown), Celadon's store
-- (six floors, an awning, a rooftop garden rail), Celadon's Mansion, the
-- Game Corner (a lit marquee of bulbs), the gyms (GYM on the fascia),
-- Cinnabar's Mansion (burnt, its windows dark, soot over them) and lab.
-- No company name or Nintendo mark is drawn.
--
-- Built from lib/HouseLib.lua. Chosen only for these maps (lib/HouseKits.lua),
-- each painted from its town's sheet (tools/town_houses.py). Coordinates are
-- the plot's: x east, z south, y up. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/saffron_houses.png",
              SHEET_W = Lib.SHEET_W, SHEET_H = Lib.SHEET_H }
local TOWN = { SAFFRON_CITY = "saffron", CELADON_CITY = "celadon", FUCHSIA_CITY = "fuchsia",
               CINNABAR_ISLAND = "cinnabar", ROUTE_16 = "celadon",
               -- the Safari Zone's rest houses: Fuchsia's park, its cottages
               SAFARI_ZONE_CENTER = "fuchsia", SAFARI_ZONE_EAST = "fuchsia",
               SAFARI_ZONE_NORTH = "fuchsia", SAFARI_ZONE_WEST = "fuchsia" }
Kit.MAPS = {}
for k in pairs(TOWN) do Kit.MAPS[k] = true end
Kit.SHEETS = { "assets/buildings/saffron_houses.png", "assets/buildings/celadon_houses.png",
               "assets/buildings/fuchsia_houses.png", "assets/buildings/cinnabar_houses.png" }
function Kit.sheetFor(mapId)
  local t = TOWN[mapId]
  return t and ("assets/buildings/" .. t .. "_houses.png") or nil
end
Kit.TEMPLATES = { gabled_house = true, gabled_block_4x3 = true, gabled_block_4x2 = true,
                  gabled_block_6x2 = true, gabled_cottage = true, flat_commercial = true,
                  flat_block_4x4 = true, flat_block_4x6 = true, flat_block_6x4 = true,
                  flat_block_6x6 = true, gym = true, gym_large = true, fuchsia_gym = true,
                  game_corner = true, celadon_mansion = true, celadon_mart = true,
                  silph_co = true, safari_rest_house = true }

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

local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

-- the door: the drawing's 11/12 pair in the plan's lower rows -> the alcove's
-- columns in the plot, or nil
local function doorOf(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  -- (the Safari's rest house, on the FOREST sheet: its door 42/43 over 58/59)
  local a, b = 11, 12
  if t.id == "safari_rest_house" then a, b = 42, 43 end
  for r = rows, max(1, rows - 3), -1 do
    for c = 1, cols - 1 do
      if t.tiles[r][c] == a and t.tiles[r][c + 1] == b then return (c - 1) * 8 + 1 end
    end
  end
  return nil
end

-- the town's skins, picked per placement
local SKINS = {
  saffron = { function() return M.brick end, function() return M.stone end,
              function() return M.brick end },
  celadon = { function() return M.stucco(R.WEATHER) end, function() return M.stucco(R.CREAM) end,
              function() return M.brick end },
  fuchsia = { function() return M.halftimber(4, 20, R.CREAM) end, function() return M.stucco(R.CREAM) end,
              function() return M.clapboard(R.WEATHER) end },
  cinnabar = { function() return M.stucco(R.WEATHER) end, function() return M.stucco(R.CREAM) end },
}
local TILES = {
  saffron = function() return M.shingle(R.SLATE) end,
  celadon = function() return M.shingle(R.SLATE) end,
  fuchsia = function() return M.shingle(R.SLATE) end,
  cinnabar = function() return M.pantile end,
}

-- the generic building for a drawing on a plot W x D: walls, storeys of
-- windows on every face, the door if the drawing has one, the roof by kind
local function building(o)
  local W, D, town = o.W, o.D, o.town
  local Z1 = D - 10
  local X0, X1 = 4, W - 5
  local wall = o.wall
  local roof
  if o.flat then
    roof = Lib.hip(1, W - 2, 5, D - 6, wall + 1, Lib.pitchOf(0.6), wall + 4)
  else
    roof = Lib.gableEW(2, W - 3, 4, D - 6, wall + 1, 0.9)
  end
  local skins = SKINS[town]
  local skin = o.skin or skins[(o.salt % #skins) + 1]()
  local windows = {}
  local storey = 14
  local DX0 = o.door
  for y0 = 8, wall - 10, storey do
    for c = 12, W - 10, 12 do
      local clear = not DX0 or y0 > 20 or c < DX0 - 5 or c > DX0 + 18
      if clear then
        windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = y0, y1 = y0 + 8,
                                  shut = o.shut, box = (y0 == 8 and o.box) or nil }
      end
    end
    for c = 14, D - 14, 14 do
      windows[#windows + 1] = { face = "e", c = c, w2 = 3, y0 = y0, y1 = y0 + 8 }
      windows[#windows + 1] = { face = "w", c = c, w2 = 3, y0 = y0, y1 = y0 + 8 }
    end
    for c = 16, W - 14, 16 do
      windows[#windows + 1] = { face = "n", c = c, w2 = 3, y0 = y0, y1 = y0 + 8 }
    end
  end
  return Lib.house({
    R = R, W = W, D = D, x0 = X0, x1 = X1, z0 = 8, z1 = Z1, wall = wall, plinth = 4,
    salt = o.salt, ytop = wall + (o.flat and 8 or 34) + (o.ytopExtra or 0),
    doorX0 = DX0 or -100, doorX1 = (DX0 or -100) + 13,
    skin = function(y)
      if o.band and y >= o.band[1] and y <= o.band[2] then return function() return sw(o.bandRow, 3) end end
      return skin
    end,
    quoin = R.STONE,
    roof = roof, tile = TILES[town](), ridgeRow = R.SLATE_DK,
    door = DX0 and (o.doorRow or R.GREEN) or nil, porch = DX0 and not o.flat and true or false,
    chimney = (not o.flat) and { x = W - 18, z = 12, top = wall + 26 } or nil,
    windows = windows,
    extra = function(x, y, z)
      if o.extra then
        local h, v = o.extra(x, y, z)
        if h then return h, v end
      end
      -- on a flat roof: a vent or two and a skylight, by the plot's hash
      if o.flat and y > wall + 4 and y <= wall + 10 then
        local top = wall + 4
        for i = 0, 2 do
          local vx = 12 + (hash(o.salt, i, 4) % max(1, W - 30))
          local vz = 14 + (hash(o.salt, i, 5) % max(1, D - 34))
          local kind = hash(o.salt, i, 6) % 3
          if kind == 0 and abs(x - vx) <= 2 and abs(z - vz) <= 2 and y <= top + 4 then
            return true, sw(R.LEAD, (y == top + 4) and 6 or 3)                  -- a vent box
          elseif kind == 1 and abs(x - vx) <= 4 and abs(z - vz) <= 3 and y == top + 1 then
            if abs(x - vx) == 4 or abs(z - vz) == 3 then return true, sw(R.WHITE, 5) end
            return true, sw(R.GLASS, 3)                                         -- a skylight
          elseif kind == 2 and (x - vx) ^ 2 + (z - vz) ^ 2 <= 4 and y <= top + 6 then
            return true, sw(R.IRON, 3 + (y % 2))                                -- a flue
          end
        end
      end
      return false
    end,
  })
end

-- ------------------------------------------------------------ landmarks
-- Silph Co.'s tower: a glass curtain wall in a steel grid, a stone base, a
-- crown of fins on the roof
local function silph(o)
  local base = building({ W = o.W, D = o.D, town = o.town, salt = 3, door = o.door, flat = true,
                          wall = 130, skin = M.stone, ytopExtra = 16, doorRow = R.BLUE })
  local Z1 = o.D - 10
  local at0 = base.at
  base.at = function(x, y, z)
    if x >= 4 and x <= o.W - 5 and z >= 8 and z <= Z1 and y >= 14 and y <= 128 then
      local edge = x == 4 or x == o.W - 5 or z == 8 or z == Z1
      if edge then
        if y % 10 == 0 or (x + z) % 8 == 0 then return sw(R.LEAD, 4) end           -- the grid
        return sw(R.GLASS, 3 + floor(y / 30) % 3)
      end
    end
    -- the crown: fins standing on the roof's flat
    if y > 134 and y <= 150 and x % 12 < 2 and z >= 20 and z <= o.D - 22 then
      return sw(R.LEAD, 5)
    end
    return at0(x, y, z)
  end
  base.ytop = 150
  return base
end

-- the store: six floors of bands, an awning over the entrance, a rail round
-- the roof garden
local function store(o)
  local b = building({ W = o.W, D = o.D, town = o.town, salt = 5, door = o.door, flat = true,
                       wall = 84, skin = M.stucco(R.WEATHER), band = { 22, 24 }, bandRow = R.RED,
                       doorRow = R.BLUE, ytopExtra = 12 })
  local at0 = b.at
  local Z1 = o.D - 10
  b.at = function(x, y, z)
    if o.door and z > Z1 and z <= Z1 + 6 and x >= o.door - 8 and x <= o.door + 21 then
      local ay = 26 - floor((z - Z1) * 0.6)
      if y == ay then return sw(floor((x - o.door) / 4) % 2 == 0 and R.RED or R.WHITE, 5) end
    end
    if y >= 89 and y <= 92 and (x == 4 or x == o.W - 5 or z == 8 or z == Z1) then
      if y == 92 or x % 6 == 0 then return sw(R.IRON, 4) end                     -- the rail
      return nil
    end
    return at0(x, y, z)
  end
  b.ytop = 96
  return b
end

-- the Game Corner: a hall with a marquee of bulbs over its front
local function hall(o)
  local b = building({ W = o.W, D = o.D, town = o.town, salt = 7, door = o.door, flat = true,
                       wall = 34, skin = M.stucco(R.CREAM), band = { 26, 31 }, bandRow = R.SHADOW,
                       doorRow = R.RED })
  local at0 = b.at
  local Z1 = o.D - 10
  b.at = function(x, y, z)
    if z == Z1 + 1 and y >= 26 and y <= 31 then
      if (y == 26 or y == 31) and x % 3 == 0 then return sw(R.LIGHT, 6) end      -- the bulbs
      if x % 6 < 3 and y >= 27 and y <= 30 then return sw(o.neon or R.RED, 5) end
    end
    return at0(x, y, z)
  end
  return b
end

-- a gym: GYM on a fascia, once or twice
local function gym(o)
  local b = building({ W = o.W, D = o.D, town = o.town, salt = 6, door = o.door, flat = true,
                       wall = 36, band = { 25, 32 }, bandRow = R.SLATE_DK, doorRow = R.RED })
  local at0 = b.at
  local Z1 = o.D - 10
  local x0s = (o.W >= 128) and { 31, 63 } or { 31 }
  b.at = function(x, y, z)
    if z == Z1 + 1 and y >= 26 and y <= 32 then
      for _, x0 in ipairs(x0s) do
        if x >= x0 and x <= x0 + 16 and Lib.glyph(GYM, x0, 32, x, y) then return sw(R.GOLD, 5 + y % 2) end
      end
    end
    return at0(x, y, z)
  end
  return b
end

-- Cinnabar's burnt Mansion: its windows dark, soot over them, a gap in
-- the roof
local function burnt(o)
  local b = building({ W = o.W, D = o.D, town = o.town, salt = 8, door = o.door, flat = false,
                       wall = 36, skin = M.stone, doorRow = R.SHADOW })
  local at0 = b.at
  b.at = function(x, y, z)
    local v = at0(x, y, z)
    if v and v >= R.GLASS * 8 and v < (R.GLASS + 1) * 8 then return sw(R.SHADOW, 1) end
    if v and y >= 10 and y <= 34 and hash(floor(x / 3), floor(y / 3), floor(z / 3)) % 7 == 0 then
      return sw(R.SHADOW, 2)                                                  -- soot
    end
    if y > 38 and x >= o.W / 2 - 10 and x <= o.W / 2 + 6 and z >= 20 and z <= 40 then return nil end
    return v
  end
  return b
end

-- ------------------------------------------------------------- dispatch
local DEPTH = { gabled_cottage = 24, safari_rest_house = 24, gabled_block_4x2 = 24, gabled_block_6x2 = 24,
                gabled_house = 36, gabled_block_4x3 = 36, flat_commercial = 36,
                flat_block_4x4 = 36, flat_block_6x4 = 36, flat_block_4x6 = 50,
                flat_block_6x6 = 50, celadon_mansion = 62, game_corner = 34 }

-- the landmarks by (map, top-left tile)
local SPECIAL = {
  SAFFRON_CITY = { ["32:20"] = "silph" },
  CELADON_CITY = { ["12:12"] = "store", ["52:32"] = "hall" },
  CINNABAR_ISLAND = { ["8:0"] = "burnt", ["8:12"] = "lab" },
}

function Kit.model(sp, t, tx, ty, mapId)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local town = TOWN[mapId or ""]
  if not town then return nil, "not a southern town: " .. tostring(mapId) end
  local o = { W = #t.tiles[1] * 8, D = #t.tiles * 8, town = town, door = doorOf(t),
              salt = hash(tx, ty, 1) }
  if mapId == "ROUTE_16" and t.id ~= "gabled_cottage" then return nil, "the gate is GatehouseKit's" end
  local special = SPECIAL[mapId] and SPECIAL[mapId][tostring(tx) .. ":" .. tostring(ty)]
  if special == "silph" or t.id == "silph_co" then return silph(o) end
  if special == "store" or t.id == "celadon_mart" then return store(o) end
  if special == "burnt" then return burnt(o) end
  if special == "hall" then return hall(o) end
  if special == "lab" then
    -- the Pokemon Lab: a plain white block of the island's, a flat roof
    o.flat, o.wall, o.skin = true, 36, M.stucco(R.WEATHER)
    return building(o)
  end
  if t.id == "game_corner" then
    o.neon = (town == "fuchsia") and R.GREEN or R.BLUE
    return hall(o)
  end
  if t.id == "gym" or t.id == "gym_large" or t.id == "fuchsia_gym" then return gym(o) end
  o.flat = t.id:sub(1, 4) == "flat" or t.id == "celadon_mansion"
  o.wall = DEPTH[t.id] or 36
  o.shut = (hash(tx, ty, 2) % 2 == 0) and R.LILAC or nil
  o.box = (hash(tx, ty, 3) % 3 == 0) and R.FLOWER or nil
  return building(o)
end

return Kit
