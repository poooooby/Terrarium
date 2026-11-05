-- Voxel world mode: the beach house on Route 19 INSIDE (Yellow only) --
-- the surfing Pikachu's house.
--
-- The plan (BEACH_HOUSE tileset, 28x16): the wall band (0) with three
-- windows (6/7 over 22/23), the surf game's cabinet in the north-east
-- corner (64/65, 32/33, 66/67, 50/51), sand on the west (17) and boards on
-- the east (1), two tables (38..41 over 54..57, 44/42/43, 60/58/59) with
-- four stools down each side (2/3 over 18/19), two palms in pots on the
-- west wall (68/69, 8/9, 70/71, 24/25), the mat (4 over 20). What stands:
--
--   the wall     whitewashed boards between driftwood posts, 28 tall; the
--                windows framed in timber, the sea and the sky through them
--   the floor    sand tracked in on the west, whitewashed boards on the east
--   the tables   white tops on timber legs, a tray of drinks on each
--   the stools   rattan, round, at sitting height -- each its own
--                template (the cells are walkable: a sitter stands on one)
--   the palms    a crown of leaves on a stem, a clay pot
--   the cabinet  the surf game: a yellow cabinet, its screen showing a wave,
--                a red stripe, a board on the floor before it
--
-- On the homes' shell (lib/HomeLib.lua): no south wall, no ceiling, the
-- side walls outside the box, cut toward the camera. 224 x 128 voxels.
-- Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/beach_house.png", SHEET_W = 8, SHEET_H = 16 }
Kit.MAPS = { SUMMER_BEACH_HOUSE = 1 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, sideH = Lib.sw, Lib.sideH
local WHITE, BOARD, BOARD_DK, TIMBER, SAND, SAND_DK, SEA, SKY, RATTAN, LEAF, CLAY, YELLOW,
      RED, DARK, SCREEN, TABLE = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end
local W, D, WALL_H = 224, 128, Lib.WALL_H

local function wallSkin(u, y)
  if y >= WALL_H - 1 then return sw(TIMBER, 5) end
  if u % 32 <= 1 then return sw(TIMBER, 3 + (u % 32)) end              -- the posts
  if y <= 1 then return sw(TIMBER, 2) end
  if y % 4 == 0 then return sw(WHITE, 3) end                            -- the board seams
  return sw(WHITE, 5 + hash(floor(u / 32), floor(y / 4), 2) % 2)
end

-- a window, x0..x0+15 in the north wall's face (z 8..9)
local function window(x, y, z, x0)
  local lx = x - x0
  if lx < 1 or lx > 14 or y < 9 or y > 23 then return nil end
  if lx == 1 or lx == 14 or y == 9 or y == 23 then
    return sw(TIMBER, (y == 9 and z == 9) and 6 or 4)
  end
  if z < 7 then return nil end
  if z == 7 then
    -- the view: sky over the sea, a white crest along the horizon
    if y >= 17 then return sw(SKY, 5 + (y >= 21 and 1 or 0)) end
    if y == 16 and (lx + floor(x0 / 16)) % 3 ~= 0 then return sw(WHITE, 6) end
    return sw(SEA, 3 + (y >= 13 and 1 or 0) + ((lx + y) % 5 == 0 and 1 or 0))
  end
  if lx == 7 or lx == 8 or y == 16 then return sw(TIMBER, 5) end         -- the glazing bars
  return nil                                                             -- the glass
end
local WINDOWS = { 48, 112, 176 }

local function northWall(x, y, z)
  if z > 9 or y > WALL_H then return nil end
  for _, x0 in ipairs(WINDOWS) do
    if x >= x0 and x <= x0 + 15 and z >= 6 then
      local v = window(x, y, z, x0)
      if v ~= nil or (y >= 10 and y <= 22 and x > x0 and x < x0 + 15) then return v end
    end
  end
  return wallSkin(x, y)
end

-- the surf game's cabinet, x 208..222, z 4..30
local function cabinet(x, y, z)
  if x < 208 or x > 222 or z < 4 or z > 30 or y > 24 then return nil end
  local lx = x - 208
  if y == 24 then return sw(YELLOW, 6) end
  if z == 30 then
    if y >= 13 and y <= 22 and lx >= 2 and lx <= 12 then
      -- the screen: a wave curling over a board
      if y == 13 or y == 22 or lx == 2 or lx == 12 then return sw(DARK, 3) end
      local crest = 15 + floor(3 * math.sin((lx - 2) * 0.6))
      if y <= crest then return sw(SEA, 4 + (y == crest and 2 or 0)) end
      if y == crest + 1 and lx >= 6 and lx <= 8 then return sw(YELLOW, 6) end
      return sw(SCREEN, 5)
    end
    if y >= 9 and y <= 10 then return sw(RED, 5) end                     -- the stripe
    if y == 7 and (lx == 5 or lx == 9) then return sw(RED, 6) end       -- two buttons
    if y <= 1 then return sw(DARK, 3) end
    return sw(YELLOW, 4 + (y >= 12 and 1 or 0))
  end
  if lx == 0 or lx == 14 then return sw(YELLOW, 3) end
  return sw(YELLOW, 4)
end
-- the board before it, lying flat, x 209..221, z 34..39
local function surfboard(x, y, z)
  if y ~= 0 then return nil end
  local dx, dz = (x - 215) / 6.5, (z - 36.5) / 2.6
  if dx * dx + dz * dz > 1 then return nil end
  if abs(z - 36.5) < 0.6 then return sw(RED, 5) end
  return sw(WHITE, 6)
end

-- a table, x 144..175, z z0..z0+31: the top at 10 over the drawing's first
-- three rows, legs at the corners
local function tableAt(x, y, z, z0)
  local tx, tz = x - 144, z - z0
  if tx < 1 or tx > 30 or tz < 2 or tz > 27 then return nil end
  if y <= 8 then
    if (tx <= 2 or tx >= 29) and (tz <= 4 or tz >= 25) then return sw(TIMBER, 3) end
    return nil
  end
  if y <= 10 then
    if y == 9 then return sw(TIMBER, 4) end
    return sw(TABLE, (tx == 1 or tx == 30 or tz == 2 or tz == 27) and 4 or 6)
  end
  -- the tray in the middle, two glasses and a jug on it
  local hy = y - 11
  if tx >= 9 and tx <= 22 and tz >= 10 and tz <= 19 and hy == 0 then return sw(RATTAN, 4) end
  for i, g in ipairs({ { 12, 14, YELLOW }, { 19, 14, RED }, { 15.5, 15, SKY } }) do
    local d = (tx - g[1]) ^ 2 + (tz - g[2]) ^ 2
    local tall = (i == 3) and 6 or 4
    if hy >= 1 and hy <= tall and d <= ((i == 3) and 3.2 or 1.6) then
      if hy == tall then return sw(WHITE, 6) end
      return sw(g[3], 4 + (hy % 2))
    end
  end
  return nil
end

-- a stool in its cell, round, rattan, its seat at 7
local function stool(x, y, z, cx, cz)
  local d = (x - cx) ^ 2 + (z - cz) ^ 2
  if y > 7 then return nil end
  if y >= 6 then return (d <= 20) and sw(RATTAN, y == 7 and 6 or 4) or nil end
  if d <= 20 and d >= 13 and ((x + z + y) % 3 ~= 0) then return sw(RATTAN, 3) end   -- the weave
  if y == 0 and d <= 20 then return sw(RATTAN, 2) end
  return nil
end

-- a palm in its pot, x 0..15, z z0..z0+31
local function palm(x, y, z, z0)
  local px, pz = x - 7.5, z - (z0 + 24)
  local d2 = px * px + pz * pz
  if y <= 7 then
    local r = 4.5 + y * 0.15
    if d2 > r * r then return nil end
    if y == 7 then return d2 <= (r - 1) ^ 2 and sw(SAND_DK, 3) or sw(CLAY, 6) end
    return sw(CLAY, 3 + (y == 6 and 2 or 0) + hash(floor(px + 8), y, 1) % 2)
  end
  if y <= 18 then
    local sx = 7.5 + (y - 8) * 0.12
    if (x - sx) ^ 2 + pz * pz <= 1.2 then return sw(TIMBER, 3 + y % 2) end   -- the stem
  end
  -- the crown: fronds radiating out and drooping from the stem's top
  local cy = 19
  if y < 14 or y > 22 then return nil end
  local ax, az = x - 8.7, z - (z0 + 24)
  local r = sqrt(ax * ax + az * az)
  if r > 12 then return nil end
  local a = math.atan2(az, ax)
  local frond = (a / (2 * math.pi) * 7 + 7) % 1
  local droop = cy + 2 - floor(r * r / 24)
  if abs(frond - 0.5) < 0.22 - r * 0.012 and abs(y - droop) <= 0 then
    return sw(LEAF, 3 + (r < 5 and 2 or 0) + hash(floor(a * 3), y, 4) % 2)
  end
  return nil
end

local function floorAt(x, z)
  if x < 96 then
    -- sand, rippled
    local n = hash(floor(x / 2), 0, floor(z / 2)) % 9
    if (z + floor(x / 5)) % 7 == 0 then return sw(SAND_DK, 4) end
    return sw(SAND, 3 + (n < 3 and 1 or 0) + (n == 0 and 1 or 0))
  end
  -- boards running north-south, whitewashed, a voxel seam
  local plank = floor((x - 96) / 6)
  if (x - 96) % 6 == 0 then return sw(BOARD, 3) end
  if (z + plank * 13) % 40 == 0 then return sw(BOARD, 4) end
  return sw(WHITE, 3 + hash(plank, floor((z + plank * 13) / 40), 5) % 2)
end


local function room(x, y, z)
  if x < 0 or x >= W then
    if x < -Lib.WALL_D or x > W - 1 + Lib.WALL_D or z < 0 or z >= D or y > sideH(z) then return nil end
    return wallSkin(z + 5, y)
  end
  if z < 0 or z >= D or y < 0 then return nil end
  local v = northWall(x, y, z)
  if v or z <= 9 then return v end
  v = cabinet(x, y, z)
  if v then return v end
  if x <= 15 and z >= 32 and z <= 63 then v = palm(x, y, z, 32) end
  if not v and x <= 15 and z >= 96 then v = palm(x, y, z, 96) end
  if not v and x >= 144 and x <= 175 and z >= 32 and z <= 95 then
    v = tableAt(x, y, z, z < 64 and 32 or 64)
  end
  if v or y > 0 then return v end
  v = surfboard(x, y, z)
  if v then return v end
  if z >= 112 and x >= 32 and x <= 63 then
    -- the mat, laid: a woven rope mat
    if x == 32 or x == 63 or z == 112 or z == 127 then return sw(TIMBER, 4) end
    return sw(RATTAN, 3 + ((x + z) % 3 == 0 and 1 or 0))
  end
  return floorAt(x, z)
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not the beach house: " .. tostring(mapId) end
  if t.home == "seat" then
    -- a stool alone, its own template: the cell is walkable, and whoever
    -- stands on it stands at the seat's height
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      return stool(x, y, z, 7.5, 7.5) or ((y == 0) and floorAt(x + 128, z) or nil)
    end, {})
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 15, 9
    m.standH = Lib.SEAT_H
    return m
  end
  -- the stools' cells are their own templates (`seat`)
  local m, why = Lib.model(Kit, sp, t, room, { [2] = true, [3] = true, [18] = true, [19] = true })
  if not m then return nil, why end
  m.W, m.xmax, m.zmax = W, W - 1 + Lib.WALL_D, D - 1
  return m
end

return Kit
