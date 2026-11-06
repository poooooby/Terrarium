-- Voxel world mode: Pewter City's buildings OUTSIDE -- the museum and its
-- east wing, Brock's Gym, and the two stone cottages. (Its Centre and Mart
-- are Lavender's, in Pewter's colours: lib/LavenderCivicKit.lua, TOWNS.)
--
-- Five drawings, each already a template (data/voxel_heights.lua): the
-- museum's hall (`museum`, 128 x 96, the only sloped roof drawn twice
-- over), its east wing (`route_2_gate`, 96 x 64, the flat block it shares
-- with the Route 2 gate), the Gym (`gym`, 96 x 64) and the 4x2 cottage
-- (`gabled_cottage`, 64 x 32). Built from lib/HouseLib.lua in the village's
-- language -- a stone plinth, white trim, a roof told apart by its form --
-- in Pewter's colours: the city of stone, grey granite and pale limestone,
-- blue-grey slate.
--
--   MUSEUM   the hall of science: limestone ashlar with pilasters, a
--            portico of four columns under a pediment at the door, a hipped
--            slate roof whose flat top carries a clerestory -- a second,
--            narrower hall of windows with its own roof (the drawing's roof
--            band twice over)
--   WING     its east entrance: the same limestone, a hipped roof cut off
--            flat in lead, tall arched windows, a stone porch
--   GYM      Brock's Gym, a rock trainer's: rusticated granite in big
--            rough blocks, a slate roof cut flat, a dark fascia with GYM in
--            bronze, a boulder either side of the door
--   NIDORAN  the cottage where the boy keeps his Nidoran: rubble granite
--            under slate, lilac shutters, a little kennel by the door with
--            a water bowl
--   MINER    the cottage of the man who talks of the mountain: rubble
--            granite under slate, a mine cart of ore by the door, a pick
--            leaning on it
--
-- Each is the outside of its inside (lib/TownHomeKit.lua, the Pewter
-- sheet's limewashed stone). Chosen ONLY for these placements on
-- PEWTER_CITY (lib/HouseKits.lua). The plot, the door (the drawing's door
-- columns) and the warp lane are the template's: nothing below head
-- height stands in the door's cell.
--
-- Coordinates are the plot's: x east, z south, y up. A person is sixteen
-- voxels. Nothing here is extracted from the ROM; no Nintendo mark.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/pewter_houses.png",
              SHEET_W = Lib.SHEET_W, SHEET_H = Lib.SHEET_H }
Kit.MAP = "PEWTER_CITY"
Kit.TEMPLATES = { museum = true, route_2_gate = true, gym = true, gabled_cottage = true }

local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
local sw = Lib.sw
local R = Lib.ROWS
Kit.GLASS_UV = { 0, R.GLASS / Kit.SHEET_H, 1, (R.LIGHT + 1) / Kit.SHEET_H }

local M = Lib.materials(R)
local SLATES = M.shingle(R.SLATE)

-- limestone ashlar: courses four tall, blocks twelve long, staggered
local function ashlar(u, y, salt)
  local course = floor(y / 4)
  local uu = u + course % 2 * 6
  if y % 4 == 3 or uu % 12 == 0 then return sw(R.CREAM, 1) end
  return sw(R.CREAM, 3 + Lib.noise(floor(uu / 12), course, salt) % 4)
end
-- rusticated granite: big rough blocks, the joints sunk dark
local function rustic(u, y, salt)
  local course = floor(y / 6)
  local uu = u + course % 2 * 8
  if y % 6 == 5 or uu % 16 == 0 then return sw(R.MORTAR, 1) end
  local n = Lib.noise(floor(uu / 16), course, salt)
  return sw(R.STONE, 2 + (n + floor(uu / 3) % 2) % 5)
end
-- rubble granite: small stones of mixed size, mortar between
local function rubble(u, y, salt)
  local course = floor(y / 3)
  local uu = u + (course * 3) % 5
  if y % 3 == 2 and (uu % 4 ~= 1) then return sw(R.MORTAR, 3) end
  if uu % 5 == 0 then return sw(R.MORTAR, 3) end
  return sw(R.STONE, 1 + Lib.noise(floor(uu / 5), course, salt) % 6)
end

-- a column: round shaft r 1.6, a square base and capital
local function column(x, y, z, cx, cz, y1)
  local dx, dz = x - cx, z - cz
  if y < 0 or y > y1 then return nil end
  if y <= 1 or y >= y1 - 1 then
    if abs(dx) <= 2 and abs(dz) <= 2 then return sw(R.WHITE, y <= 1 and 4 or 6) end
    return nil
  end
  if dx * dx + dz * dz <= 2.6 then
    return sw(R.WHITE, 3 + ((dx < 0) and 2 or 1) + (floor(y / 2) % 2 == 0 and 0 or 0))
  end
  return nil
end

-- ---------------------------------------------------------------- museum
local function museum()
  local X0, X1, Z0, Z1 = 4, 123, 10, 86
  local WALL = 34
  local DX0, DX1 = 65, 78
  local roof = Lib.hip(2, 125, 6, 90, WALL + 1, Lib.pitchOf(0.55), 46)
  -- the clerestory on the roof's flat: walls 46..58, its own hipped roof
  local C0, C1, CZ0, CZ1 = 26, 101, 28, 68
  local croof = Lib.hip(C0 - 2, C1 + 2, CZ0 - 2, CZ1 + 2, 58, Lib.pitchOf(0.6))
  local function skin(y)
    if y == WALL - 3 or y == WALL - 2 then return function() return sw(R.WHITE, 5) end end   -- the cornice
    return function(u, yy, salt)
      if u % 20 < 3 and yy > 5 then return sw(R.CREAM, 5 + floor(yy / 4) % 2) end    -- pilasters
      return ashlar(u, yy, salt)
    end
  end
  local windows = {}
  for _, c in ipairs({ 14, 34, 54, 92, 112 }) do
    windows[#windows + 1] = { face = "s", c = c + 0.5, w2 = 4, y0 = 9, y1 = 25, arch = true }
  end
  for _, c in ipairs({ 24, 44, 64 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 4, y0 = 9, y1 = 25, arch = true }
    windows[#windows + 1] = { face = "w", c = c, w2 = 4, y0 = 9, y1 = 25, arch = true }
  end
  for _, c in ipairs({ 24, 64, 104 }) do
    windows[#windows + 1] = { face = "n", c = c, w2 = 4, y0 = 9, y1 = 25, arch = true }
  end
  local PZ0, PZ1 = Z1 + 1, Z1 + 8          -- the portico's depth, before the door
  local PX0, PX1 = 52, 91
  local PC = (PX0 + PX1) / 2
  return Lib.house({
    R = R, W = 128, D = 96, x0 = X0, x1 = X1, z0 = Z0, z1 = Z1, wall = WALL, plinth = 5,
    salt = 7, ytop = 80, doorX0 = DX0, doorX1 = DX1,
    skin = skin, quoin = R.CREAM,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.GREEN, windows = windows,
    lights = { { x = 60, y = 16, z = Z1 + 2 } },
    extra = function(x, y, z)
      -- the clerestory: limestone walls, a band of arched windows all
      -- round, its hipped roof
      if x >= C0 - 2 and x <= C1 + 2 and z >= CZ0 - 2 and z <= CZ1 + 2 and y > 46 then
        local top, u, d, _, ridge = croof(x, z)
        if top and y <= top and y >= top - 2 and y > 57 then
          if ridge then return true, sw(R.SLATE_DK, 6) end
          return true, SLATES(u, d, 9)
        end
        if x >= C0 and x <= C1 and z >= CZ0 and z <= CZ1 and y <= 57 then
          local edge = x == C0 or x == C1 or z == CZ0 or z == CZ1
          local wu = (z == CZ0 or z == CZ1) and x or z
          local inset = (z == CZ1 - 1 or z == CZ0 + 1) and x > C0 + 1 and x < C1 - 1
          if y == 57 or y == 47 then return true, sw(R.WHITE, 5) end
          -- windows every twelve, arched, glass two back
          local wc = (wu - 2) % 12
          if y >= 49 and y <= 55 and wc >= 3 and wc <= 8 and not (wu < C0 + 4 or wu > C1 - 4) then
            local du = wc - 5.5
            local inside = y < 54 or du * du + (y - 53) ^ 2 <= 7.5
            if inside then
              if edge then return true, nil end
              if inset then return true, sw(R.GLASS, 2 + (wc + y) % 4) end
            end
          end
          if edge then return true, ashlar(wu, y, 8) end
          return true, sw(R.SHADOW, 2)
        end
      end
      -- the portico: a stone floor two steps up, four columns, an
      -- entablature, a pediment with a moulded rim
      if x >= PX0 and x <= PX1 and z >= PZ0 and z <= PZ1 + 2 then
        if y <= 1 then
          -- in the door's lane the floor is a single step, so the one who
          -- stands there to go in does not stand in stone
          if y == 1 and x >= DX0 - 1 and x <= DX1 + 1 then return false end
          if z > PZ1 then
            if y == 0 then return true, sw(R.WHITE, 4) end
            return false
          end
          return true, sw(R.WHITE, 4 + y)
        end
        if z <= PZ1 then
          for _, cx in ipairs({ 55.5, 62, 81, 87.5 }) do
            local v = column(x, y - 2, z, cx, PZ1 - 2, 27)
            if v then return true, v end
          end
          if y >= 29 and y <= 32 then
            if y == 29 then return true, sw(R.WHITE, 5) end
            if y == 32 then return true, sw(R.WHITE, 6) end
            return true, ashlar(x, y, 3)
          end
          local ph = 33 + floor((PX1 - PX0) / 2 * 0.42 - abs(x - PC) * 0.42)
          if y >= 33 and y <= ph then
            if y == ph or y == ph - 1 or z == PZ1 then
              if y >= ph - 1 then return true, sw(R.WHITE, 6) end
              -- the tympanum: plain limestone, a round window at its heart
              local dy = y - 37
              if (x - PC) ^ 2 + dy * dy <= 6.5 then
                if (x - PC) ^ 2 + dy * dy >= 3 then return true, sw(R.WHITE, 5) end
                return true, sw(R.GLASS, 3)
              end
              return true, sw(R.CREAM, 4)
            end
            return true, sw(R.SHADOW, 2)
          end
        end
      end
      return false
    end,
  })
end

-- ------------------------------------------------------------ the wing
local function wing()
  local Z1 = 54
  local roof = Lib.hip(1, 94, 4, 58, 31, Lib.pitchOf(0.6), 40)
  local function skin(y)
    if y == 27 or y == 28 then return function() return sw(R.WHITE, 5) end end
    return function(u, yy, salt)
      if u % 20 < 3 and yy > 5 then return sw(R.CREAM, 5 + floor(yy / 4) % 2) end
      return ashlar(u, yy, salt)
    end
  end
  local windows = {}
  for _, c in ipairs({ 44, 58, 72, 86 }) do
    windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = 8, y1 = 22, arch = true }
  end
  for _, c in ipairs({ 20, 40 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 3, y0 = 8, y1 = 22, arch = true }
    windows[#windows + 1] = { face = "w", c = c, w2 = 3, y0 = 8, y1 = 22, arch = true }
  end
  for _, c in ipairs({ 24, 48, 72 }) do
    windows[#windows + 1] = { face = "n", c = c, w2 = 3, y0 = 8, y1 = 22, arch = true }
  end
  return Lib.house({
    R = R, W = 96, D = 64, x0 = 4, x1 = 91, z0 = 8, z1 = Z1, wall = 30, plinth = 5,
    salt = 8, ytop = 50, doorX0 = 17, doorX1 = 30,
    skin = skin, quoin = R.CREAM,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.GREEN, porch = true,
    windows = windows,
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

-- a boulder, lumpy, granite: centre (cx, cz), radius r
local function boulder(x, y, z, cx, cz, r, salt)
  local dx, dz = x - cx, z - cz
  local h = r * 1.15
  local wob = ((x * 7 + z * 13 + y * 5 + salt) % 5 - 2) * 0.22
  local rr = r * sqrt(max(0, 1 - (y / h) ^ 2)) + wob
  if y > h or dx * dx + dz * dz > rr * rr then return nil end
  if y >= h - 2 then return sw(R.STONE, 6) end
  return sw(R.STONE, 2 + (floor(x / 2) + floor(y / 2) + floor(z / 2) + salt) % 4)
end

local function gym()
  local Z1 = 54
  local roof = Lib.hip(1, 94, 4, 58, 37, Lib.pitchOf(0.75), 50)
  local function skin(y)
    if y >= 25 and y <= 32 then return function() return sw(R.SHADOW, 3) end end
    if y == 24 or y == 33 then return function() return sw(R.STONE, 6) end end
    return rustic
  end
  local windows = {}
  for _, c in ipairs({ 13, 25, 37, 49 }) do
    windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = 10, y1 = 20 }
  end
  windows[#windows + 1] = { face = "s", c = 87, w2 = 3, y0 = 10, y1 = 20 }
  for _, c in ipairs({ 18, 32, 46 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 3, y0 = 10, y1 = 20 }
    windows[#windows + 1] = { face = "w", c = c, w2 = 3, y0 = 10, y1 = 20 }
  end
  for _, c in ipairs({ 20, 48, 76 }) do
    windows[#windows + 1] = { face = "n", c = c, w2 = 3, y0 = 10, y1 = 20 }
  end
  return Lib.house({
    R = R, W = 96, D = 64, x0 = 4, x1 = 91, z0 = 8, z1 = Z1, wall = 36, plinth = 6,
    salt = 6, ytop = 66, doorX0 = 65, doorX1 = 78,
    skin = skin, quoin = R.MORTAR,
    roof = roof, tile = SLATES, ridgeRow = R.SLATE_DK,
    door = R.RED,
    windows = windows,
    extra = function(x, y, z)
      -- the sign: GYM in bronze letters on the dark fascia, a voxel proud
      if z == Z1 + 1 and y >= 26 and y <= 32 and x >= 31 and x <= 47 then
        if Lib.glyph(GYM, 31, 32, x, y) then return true, sw(R.GOLD, 3 + (y % 2)) end
      end
      -- a boulder either side of the door, sat on the paving
      if z > Z1 and z <= Z1 + 9 and y >= 1 then
        for i, b in ipairs({ { 58, Z1 + 5 }, { 86, Z1 + 5 } }) do
          if abs(x - b[1]) <= 6 and abs(z - b[2]) <= 6 then
            local v = boulder(x, y - 1, z, b[1], b[2], 4.6, i * 3)
            if v then return true, v end
          end
        end
      end
      return false
    end,
  })
end

-- -------------------------------------------------------------- cottages
local function cottage(salt, door, shut, extra)
  local Z1 = 27
  return Lib.house({
    R = R, W = 64, D = 32, x0 = 5, x1 = 58, z0 = 4, z1 = Z1, wall = 24, plinth = 4,
    salt = salt, ytop = 50,
    skin = function() return rubble end, quoin = R.CREAM,
    roof = Lib.gableEW(2, 61, 1, 30, 25, 0.95), tile = SLATES, ridgeRow = R.SLATE_DK,
    door = door,
    chimney = { x = 46, z = 8, top = 46 },
    windows = { { face = "s", c = 41, w2 = 5, y0 = 8, y1 = 18, shut = shut },
                { face = "e", c = 16, w2 = 4, y0 = 8, y1 = 18, shut = shut },
                { face = "w", c = 16, w2 = 4, y0 = 8, y1 = 18, shut = shut },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
    extra = extra,
  })
end

-- the boy's cottage: a kennel for his Nidoran right of the window, a bowl
local function nidoran()
  local Z1 = 27
  return cottage(4, R.BLUE, R.LILAC, function(x, y, z)
    if x >= 49 and x <= 58 and z >= Z1 + 1 and z <= Z1 + 4 then
      local lx = x - 49
      -- the kennel: plank walls to y 7, a round door facing south, a
      -- pitched roof along x
      if y >= 1 and y <= 7 then
        if z == Z1 + 4 and lx >= 3 and lx <= 6 and y <= 5 and (y <= 4 or (lx >= 4 and lx <= 5)) then
          return true, sw(R.SHADOW, 0)
        end
        return true, sw(R.WOOD, 3 + (lx % 3 == 0 and 0 or 2))
      end
      local ry = 8 + floor(min(z - Z1 - 1, Z1 + 4 - z) * 1.2)
      if y >= 8 and y <= ry + 1 then return true, sw(R.LILAC, (y == ry + 1) and 5 or 3) end
      return false
    end
    -- a water bowl before it
    if z == Z1 + 3 and x >= 44 and x <= 46 and y == 1 then return true, sw(R.BLUE, 4) end
    return false
  end)
end

-- the miner's cottage: a mine cart of ore right of the window, a pick on it
local function miner()
  local Z1 = 27
  return cottage(5, R.RED, R.GREEN, function(x, y, z)
    if x >= 47 and x <= 58 and z >= Z1 + 1 and z <= Z1 + 4 then
      local lx = x - 47
      -- the wheels: two a side, iron
      if y >= 1 and y <= 3 and (z == Z1 + 1 or z == Z1 + 4) and (lx == 2 or lx == 3 or lx == 8 or lx == 9) then
        return true, sw(R.IRON, 2 + y % 2)
      end
      if y >= 3 and y <= 8 and lx >= 1 and lx <= 10 then
        local rim = lx == 1 or lx == 10 or z == Z1 + 1 or z == Z1 + 4
        if rim then
          if y == 8 then return true, sw(R.IRON, 4) end
          return true, sw(R.WOOD, 2 + (y % 2))
        end
        if y <= 7 then return true, sw(R.SHADOW, 2) end
        -- the ore heaped in it, grey with a glint
        if (x * 3 + z * 5) % 7 == 0 then return true, sw(R.GOLD, 4) end
        return true, sw(R.STONE, 2 + (x + z) % 3)
      end
      if y == 9 and lx >= 3 and lx <= 8 and z >= Z1 + 2 and z <= Z1 + 3 then
        return true, sw(R.STONE, 3 + (x % 2))
      end
      -- the pick: a haft leaning against the cart's west end, the head
      if lx == 0 and z == Z1 + 3 and y >= 1 and y <= 12 then return true, sw(R.WOOD, 4) end
      if y == 12 and z == Z1 + 3 and lx <= 0 then return true, sw(R.IRON, 4) end
      return false
    end
    if x >= 44 and x <= 46 and z == Z1 + 3 and y == 12 then return true, sw(R.IRON, 4) end
    return false
  end)
end

-- Which building stands on the placement whose top-left TILE is (tx, ty).
Kit.PLACES = { ["20:4"] = museum, ["36:4"] = wing, ["24:28"] = gym,
               ["56:24"] = nidoran, ["12:56"] = miner }

function Kit.model(sp, t, tx, ty)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local make = Kit.PLACES[tostring(tx) .. ":" .. tostring(ty)]
  if not make then return nil, "no building of Pewter's stands at " .. tostring(tx) .. ":" .. tostring(ty) end
  return make()
end

return Kit
