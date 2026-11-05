-- Voxel world mode: Red's house downstairs (REDS_HOUSE_1F), Mom's living
-- room, and the Copycat's ground floor on the same plan.
--
-- Same contract as lib/RedsRoomKit.lua upstairs, and built from the same
-- parts (lib/HomeLib.lua): an authored sheet (tools/reds_house.py, whose
-- first eight rows are the room upstairs' colour for colour, so one house
-- reads as one house), the room one function of position, a person sixteen
-- voxels, the homes' fixed dollhouse shot, nothing tall to the south.
--
-- The plan (16x16 tiles, tools/interior_plan.py; REDS_HOUSE_1F and
-- COPYCATS_HOUSE_1F are tile for tile the same) is the collision, so
-- nothing moves. In voxels, x east and z south:
--
--   x  0..31   z  0..31   two bookcases         (38/41 48/49 34/35 50/51)
--   x 48..63, 80..95, 112..127   three windows  (36/37 over 52/53)
--   x 48..63   z 16..31   the television        (6/7 over 22/23)
--   x112..127  z 16..31   the stairs up, climbing east (12/13 over 28/29)
--   x 48..79   z 64..95   the dining table, a pot of flowers in the
--                         middle                (38-44, 54-60)
--   x 32..47, 80..95  z 64..95   four stools    (2/3 over 18/19)
--   x 32..63   z112..127  the doormat, left drawn (4/20)
--
-- Who lives here: Mom. She keeps the house the way it was when Red was
-- small -- his photo on the shelf, the good china behind glass, flowers on
-- the table, the paper folded at her place, the set on for the afternoon
-- film. The Copycat's mother downstairs keeps the same room in rose.
--
-- `v` is picked by MAP ID: 1 Red's, 2 the Copycat's. Coordinates: x east
-- 0..127, z south 0..127, y up. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/reds_house.png", SHEET_W = 8, SHEET_H = 32 }

Kit.MAPS = { REDS_HOUSE_1F = 1, COPYCATS_HOUSE_1F = 2 }
Kit.SEAT_H = Lib.SEAT_H

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, hash, sideH = Lib.sw, Lib.hash, Lib.sideH

-- rows of the sheet; tools/reds_house.py is the mirror of this list
local PLASTER, WAINSCOT, OAK, WALNUT, DARK, TRIM, SKY, BLIND,
      CURTAIN, CURTAIN_C, BOOK_R, BOOK_G, BOOK_B, BOOK_Y, PAPER, CHINA,
      CHINA_B, TVBODY, SCREEN, GLOW, CLAY, SOIL, LEAF, FLOWER,
      FLOWER_Y, CUSHION, CLOTH, RUG, RUG_EDGE, BRASS, LIGHT, IRON =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

-- the accent that is hers, not Mom's
local function curtainRow(v) return v == 2 and CURTAIN_C or CURTAIN end
local function cushionRow(v) return v == 2 and CURTAIN_C or CUSHION end

-- ------------------------------------------------------------ the walls --
-- Upstairs' skin, band for band: a dark skirting three courses tall, oak
-- panelling to the white rail at 1 m, plaster, a three-course cornice.
local SKIN = {
  skirt = { 2, function(u, y) return sw(DARK, y == 2 and 4 or 3) end },
  dado = { 9, function(u, y)
    if u % 12 == 0 then return sw(WAINSCOT, 2) end
    if y == 9 then return sw(WAINSCOT, 6) end
    return sw(WAINSCOT, 4 + hash(floor(u / 12), 0, 1) % 2)
  end },
  rail = { 10, sw(TRIM, 4) },
  cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
  field = function(u, y) return sw(PLASTER, hash(u, y, 2) % 13 == 0 and 4 or 5) end,
}
local wallSkin = Lib.wallSkin(SKIN)

-- ---------------------------------------------------------- the windows --
-- Three, as the drawing has them, each the room upstairs' window: a white
-- frame, the glass three voxels back, a cross bar, the blind half let down.
-- Mom has hung curtains either side of the first two; the third stands
-- over the stairs, where a curtain would hang into the flight.
local WINDOWS = {}
for i, x0 in ipairs({ 48, 80, 112 }) do
  WINDOWS[i] = Lib.northWindow({
    x0 = x0 + 1, x1 = x0 + 14, y0 = 11, y1 = 24,
    frame = sw(TRIM, 5), bar = sw(TRIM, 5),
    mullion = function(lx, y) return lx == 6 or lx == 7 or y == 18 end,
    glass = function(lx, y) return sw(SKY, 4 + floor((y - 11) / 4)) end,
    dress = function(lx, y, z)
      if z ~= 7 or y < 17 then return nil end
      if y % 2 == 0 or lx == 6 then return sw(BLIND, y % 2 == 0 and 5 or 2) end
      return nil
    end,
    sill = { 10, 10, sw(TRIM, 6) },
  })
end

-- tied-back curtains on the z 10/11 planes either side of windows 1 and 2:
-- two drops five wide from the rod down to the sill, gathered at a tie-back
-- (below it the outer column is cut away), folds in alternating shades
local function curtains(x, y, z, v)
  if y < 7 or y > 25 or z < 10 or z > 11 then return nil end
  for _, x0 in ipairs({ 48, 80 }) do
    local a0, a1 = x0 - 4, x0 + 19           -- outer columns of the two drops
    if x >= a0 and x <= a1 then
      if y == 25 then return z == 11 and sw(BRASS, 4) or nil end      -- the rod
      local inL = x <= x0
      local inR = x >= x0 + 15
      if not (inL or inR) then return nil end
      if y == 14 then return sw(curtainRow(v), 2) end                -- the tie
      if y < 14 and (x == a0 or x == a1) then return nil end         -- gathered
      if z == 10 and y < 14 then return nil end
      return sw(curtainRow(v), 3 + (x % 2) * 2)
    end
  end
  return nil
end

-- between windows 1 and 2: a round wall clock on a whole-voxel centre (x 71,
-- y 20) so its hands can be one voxel thin: walnut rim, a paper face, the
-- four quarter ticks, the minute hand at twelve and the hour hand at nine
-- (two wide, the hands merged into a black wedge)
local function clock(x, y)
  local dx, dy = x - 71, y - 20
  local d2 = dx * dx + dy * dy
  if d2 > 17 then return nil end
  if d2 > 11 then return sw(WALNUT, 4) end
  if dx == 0 and dy >= 0 and dy <= 2 then return sw(IRON, 3) end        -- minute
  if dy == 0 and dx >= -2 and dx <= 0 then return sw(IRON, 3) end       -- hour
  if d2 >= 8 and (dx == 0 or dy == 0) then return sw(IRON, 5) end       -- ticks
  return sw(PAPER, 6)
end

-- between windows 2 and 3: a framed picture of the bay south of town
local function picture(x, y, v)
  if x < 100 or x > 107 or y < 13 or y > 22 then return nil end
  if x == 100 or x == 107 or y == 13 or y == 22 then return sw(WALNUT, 3) end
  if y >= 19 then return sw(SKY, 5 + (y == 21 and 1 or 0)) end
  if y >= 17 then return sw(CHINA_B, 4 + (x + y) % 2) end              -- the sea
  return sw(LEAF, 3 + (x % 3 == 0 and 1 or 0))                           -- the shore
end

local function northWall(x, y, z, v)
  for _, w in ipairs(WINDOWS) do
    local handled, tex = w(x, y, z)
    if handled then return tex end
  end
  local c = curtains(x, y, z, v)
  if c then return c end
  if z <= 9 then return wallSkin(x + 5, y) end
  if z == 10 then
    if Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
    return clock(x, y) or picture(x, y, v)
  end
  return nil
end

-- -------------------------------------------------------- the bookcases --
-- Two units, sixteen wide, from the wall out to z 30: closed cupboards
-- below with a door split and two brass knobs, open shelves above, the top
-- under the cornice. What is on them is Mom's: the left one books and his
-- photo, the right one her good china, stood on edge behind its rail.
local CASE_TOP = 25
local function bookcase(x, y, z, v)
  if x > 31 or z < 10 or z > 30 then return nil end
  local unit = floor(x / 16)
  local ux, dz = x % 16, z - 10                         -- 0..15, 0..20
  if y > CASE_TOP then
    -- on top, the things that live up there: a lidded sewing basket on
    -- the left, two hat boxes on the right
    if y > CASE_TOP + 3 then return nil end
    local hy = y - CASE_TOP - 1                         -- 0..2
    if unit == 0 and ux >= 3 and ux <= 10 and dz >= 6 and dz <= 15 then
      if hy == 2 then return sw(OAK, 5) end             -- the lid
      return sw(RUG_EDGE, ((ux + dz + hy) % 2 == 0) and 3 or 5)   -- the weave
    end
    if unit == 1 then
      local r1 = (ux - 5.5) ^ 2 + (dz - 11.5) ^ 2
      if r1 <= 12 and hy <= 1 then return sw(hy == 1 and CHINA_B or CLOTH, 4) end
      local r2 = (ux - 10.5) ^ 2 + (dz - 9.5) ^ 2
      if r2 <= 6 and hy <= 2 then return sw(hy == 2 and CURTAIN or CLOTH, 5) end
    end
    return nil
  end
  -- the plinth, set back two
  if y <= 1 then return dz <= 18 and sw(DARK, 2) or nil end
  -- carcass: sides, top, back
  if ux == 0 or ux == 15 or y == CASE_TOP or dz <= 1 then
    if y == CASE_TOP and dz == 20 then return sw(WALNUT, 5) end     -- the top's edge
    return sw(WALNUT, 3)
  end
  -- the cupboard: a closed front at dz 20, y 2..9
  if y <= 9 then
    if dz < 20 then return dz >= 19 and sw(WALNUT, 2) or nil end
    if ux == 7 or ux == 8 then return sw(WALNUT, 2) end              -- the split
    if y == 6 and (ux == 6 or ux == 9) then return sw(BRASS, 5) end  -- the knobs
    if ux == 1 or ux == 14 or y == 2 or y == 9 then return sw(WALNUT, 3) end
    return sw(WALNUT, 4 + (ux >= 8 and 1 or 0))
  end
  -- shelf boards: the cupboard's top, then every five
  if y == 10 or y == 15 or y == 20 then return sw(WALNUT, dz == 20 and 6 or 5) end
  if dz >= 18 then return nil end                       -- the front left clear
  local s = (y < 15) and 0 or (y < 20 and 1 or 2)
  local hy = y - (s == 0 and 11 or (s == 1 and 16 or 21))   -- 0..3
  if unit == 0 then
    if s == 1 and ux >= 4 and ux <= 9 then
      -- Red's photo, in a walnut frame, leaning back on its stand
      if dz == 15 and hy <= 3 then
        if ux == 4 or ux == 9 or hy == 3 then return sw(WALNUT, 5) end
        if hy == 0 then return sw(WALNUT, 4) end
        return sw(hy == 1 and CUSHION or SKY, 5)       -- a red cap, a blue sky
      end
      return nil
    end
    if s == 1 and ux >= 11 and ux <= 13 and dz >= 13 and dz <= 15 then
      return sw(v == 2 and CURTAIN_C or CHINA_B, 3 + hy)                 -- a vase
    end
    -- books, two wide, their heights and colours by hash, one gap a shelf
    local bid = floor((ux - 1) / 2) + s * 7 + unit * 31
    local h = hash(bid, s, v)
    if dz < 6 or dz > 17 or h % 9 == 0 or s == 1 then return nil end
    if hy > 1 + h % 3 then return nil end
    return sw(({ BOOK_R, BOOK_G, BOOK_B, BOOK_Y })[h % 4 + 1], 3 + (ux % 2))
  end
  -- the china: bowls stacked on the lowest shelf, plates stood on edge on
  -- the two above, a hand back from the front
  if s == 0 then
    local cx = (ux - 1) % 5
    if cx <= 2 and dz >= 12 and dz <= 16 and hy <= 1 then
      if hy == 1 then return sw(CHINA_B, 4) end
      return sw(CHINA, 5)
    end
    return nil
  end
  if dz == 15 or dz == 16 then
    local px = (ux - 1) % 4
    local r2 = (px - 1.5) * (px - 1.5) + (hy - 1.5) * (hy - 1.5)
    if r2 <= 2.6 then return sw(r2 > 1.6 and CHINA_B or CHINA, 4 + dz % 2) end
  end
  return nil
end

-- ------------------------------------------------------- the television --
-- The family set, against the wall under the first window: a cabinet with
-- two doors, the CRT on it facing the room, its back tapering, and the
-- picture on: the afternoon film Mom leaves running.
local function television(x, y, z, v)
  if x < 48 or x > 63 or z < 16 or z > 31 then return nil end
  local tx, tz = x - 48, z - 16
  if y <= 5 then
    if tx < 1 or tx > 14 or tz < 3 or tz > 14 then return nil end
    if y <= 1 then return tz <= 12 and sw(DARK, 2) or nil end          -- plinth
    if tz == 14 then
      if tx == 7 or tx == 8 then return sw(WALNUT, 2) end
      if (tx == 6 or tx == 9) and y == 3 then return sw(BRASS, 5) end
      return sw(WALNUT, 4)
    end
    if y == 5 then return sw(WALNUT, 5) end
    return sw(WALNUT, 3)
  end
  if y > 15 then return nil end
  local front = tz >= 10 and tz <= 13 and tx >= 2 and tx <= 13
  local back = tz >= 4 and tz <= 9 and abs(tx - 7.5) <= 3.5 + (tz - 4) * 0.4
  if front then
    if tz == 13 then
      if tx >= 3 and tx <= 12 and y >= 7 and y <= 14 then
        if tx == 12 and (y == 8 or y == 10) then return sw(IRON, 5) end    -- knobs
        if tx <= 10 then
          -- the picture: a bright sky over a long low horizon (two dark
          -- figures on it read as a pair of eyes)
          if y >= 12 then return sw(GLOW, 7 - (y - 12)) end
          if y == 11 then return sw(GLOW, 4) end
          return sw(GLOW, (y == 10 and 3 or 2) - (tx % 3 == 0 and 1 or 0))
        end
      end
      return sw(TVBODY, 4)
    end
    return sw(TVBODY, 3)
  end
  if back and y <= 14 then return sw(TVBODY, 2) end
  return nil
end

-- --------------------------------------------------------- the stairs --
-- The flight up to Red's room, climbing east against the north wall: eight
-- steps two voxels deep, rising to the floor above (the room upstairs
-- arrives at its east lip, lib/RedsRoomKit.lua). Oak treads with a lighter
-- nosing; the south side closed by a panelled stringer, a walnut handrail
-- on balusters over it.
local function stairs(x, y, z, v)
  if x < 112 or x > 127 or z < 16 or z > 31 then return nil end
  local i = floor((x - 112) / 2)                          -- step 0..7
  local top = 3 + floor(i * 25 / 7)                       -- 3 .. 28
  if z <= 30 then
    if y > top then return nil end
    if y == top then
      return sw(OAK, (x - 112) % 2 == 0 and 6 or 5)       -- tread, nosed
    end
    if (x - 112) % 2 == 0 and y > top - 3 then return sw(OAK, 3) end   -- riser
    return sw(WALNUT, 2)                                   -- the body (hidden)
  end
  -- z 31: the stringer, a voxel above the treads, panelled under them
  local lineTop = top + 1
  if y <= lineTop then
    if y >= lineTop - 1 then return sw(WALNUT, 4) end
    if y <= 2 then return sw(DARK, 3) end                  -- the skirting carried on
    return wallSkin(x * 1 + 7, min(y, 9))
  end
  -- the handrail, one straight slope over the nosings (stepped with the
  -- treads it read as a row of loose blocks), and a baluster on every
  -- other step up to it
  local rail = 11 + floor((x - 112) * 25 / 14)
  if y == rail or y == rail + 1 and (x - 112) % 2 == 1 then return sw(WALNUT, 5) end
  if y < rail and (x - 112) % 4 == 1 then return sw(TRIM, 4) end
  return nil
end

-- --------------------------------------------------- the dining table --
-- 32 x 32 at x 48..79, z 64..95: legs 3x3 set in from the corners, an
-- apron, a top two voxels thick with its corners rounded, a runner laid
-- east-west and hanging over both ends. On it: the pot of flowers the
-- drawing puts in the middle, two cups on saucers, the paper folded at
-- Mom's place.
local function diningTable(x, y, z, v)
  if x < 48 or x > 79 or z < 64 or z > 95 then return nil end
  local tx, tz = x - 48, z - 64
  local runner = tz >= 12 and tz <= 19
  if y <= 5 then
    if (tx >= 3 and tx <= 5 or tx >= 26 and tx <= 28)
       and (tz >= 3 and tz <= 5 or tz >= 26 and tz <= 28) then
      return sw(WALNUT, y == 0 and 2 or 3)
    end
    if runner and (tx == 0 or tx == 31) and y >= 4 then return sw(cushionRow(v), 4) end
    return nil
  end
  if y <= 7 then
    if runner and (tx == 0 or tx == 31) then return sw(cushionRow(v), 4) end
    local ring = (tx == 3 or tx == 28) and tz >= 3 and tz <= 28
              or (tz == 3 or tz == 28) and tx >= 3 and tx <= 28
    return ring and sw(WALNUT, 3) or nil
  end
  if y <= 9 then
    if runner and (tx == 0 or tx == 31) then return sw(cushionRow(v), 4) end
    if Lib.cornerCut(tx, tz, 32, 32, 3) then return nil end
    if y == 9 and runner then return sw(CLOTH, (tx % 4 == 0) and 4 or 6) end
    if y == 8 then return sw(OAK, 3) end
    return sw(OAK, tz % 4 == 0 and 4 or 6)
  end
  -- the pot of flowers, centred
  local px, pz = tx - 15.5, tz - 15.5
  local d2 = px * px + pz * pz
  if y <= 13 and d2 <= (2.2 + (y - 10) * 0.25) ^ 2 then
    if y == 13 then return d2 <= 3 and sw(SOIL, 3) or sw(CLAY, 6) end
    return sw(CLAY, 4 + (y % 2))
  end
  if y >= 14 and y <= 18 then
    local r = 3.6 - abs(y - 15.5) * 0.7
    if d2 <= r * r and hash(tx, y, tz) % 5 ~= 0 then
      if y >= 15 and hash(tx, y, tz) % 3 == 0 then
        return sw((tx + tz) % 2 == 0 and FLOWER or FLOWER_Y, 5)
      end
      return sw(LEAF, 3 + y % 3)
    end
  end
  -- two cups on saucers, either side of the pot along the runner
  for _, c in ipairs({ { 7.5, 15.5 }, { 23.5, 15.5 } }) do
    local cx, cz = tx - c[1], tz - c[2]
    local cd = cx * cx + cz * cz
    if y == 10 and cd <= 4.5 then return sw(CHINA, 6) end             -- saucer
    if y >= 11 and y <= 12 and cd <= 1.6 then
      if y == 12 and cd <= 0.6 then return sw(SOIL, 4) end            -- tea
      return sw(y == 12 and CHINA_B or CHINA, 5)
    end
  end
  -- the paper, folded at her place (the west side, south of the runner)
  if y == 10 and tx >= 6 and tx <= 12 and tz >= 22 and tz <= 26 then
    if tz == 24 then return sw(PAPER, 2) end                          -- the fold
    if tx >= 7 and tx <= 11 and tz ~= 22 and tz % 2 == 1 then return sw(PAPER, 3) end
    return sw(PAPER, 6)
  end
  return nil
end

-- ------------------------------------------------------------ the stools --
-- Square stools, one cell each: four legs, a walnut seat frame, a cushion
-- whose top is y 7 so a sitter stands at the profile's 8 (Lib.SEAT_H). In
-- ROOM coordinates, so the room and the seat templates share them.
local STOOLS = { { 39.5, 71.5 }, { 39.5, 87.5 }, { 87.5, 71.5 }, { 87.5, 87.5 } }
local function stools(x, y, z, v)
  if y > 7 then return nil end
  for idx, c in ipairs(STOOLS) do
    local dx, dz = x - c[1], z - c[2]
    if abs(dx) <= 5.5 and abs(dz) <= 5.5 then
      if y <= 4 then
        if abs(dx) >= 4 and abs(dz) >= 4 then return sw(WALNUT, 3) end
        if y == 2 and (abs(dx) >= 4 or abs(dz) >= 4) then return sw(WALNUT, 2) end
        return nil
      end
      if y == 5 then return sw(WALNUT, 4) end
      if abs(dx) > 4.5 or abs(dz) > 4.5 then return nil end
      return sw(cushionRow(v), (y == 7 and 5 or 3) + hash(floor(x), idx, floor(z)) % 2)
    end
  end
  return nil
end

-- ------------------------------------------------------------- the rug --
-- One voxel, under the dining group: a border, a brass line, a field with
-- a diamond lattice. Unclaimed, so the floor keeps painting under it.
local function rug(x, z, v)
  if x < 28 or x > 99 or z < 60 or z > 99 then return nil end
  local b = min(x - 28, 99 - x, z - 60, 99 - z)
  if b <= 1 then return sw(RUG_EDGE, 4 + b) end
  if b == 3 then return sw(BRASS, 4) end
  local dx, dz = abs(x - 63.5), abs(z - 79.5)
  if (floor(dx) + floor(dz)) % 12 < 1 then return sw(RUG_EDGE, 3) end
  return sw(v == 2 and CURTAIN_C or RUG, 4 + hash(floor(x / 3), 0, floor(z / 3)) % 2)
end

-- ------------------------------------------------------------ the floor --
-- Upstairs' boards: four wide, joints every 28 staggered 13.
local planks = Lib.boards(4, 28, 13, sw(OAK, 2), function(i, row)
  return sw(OAK, 4 + hash(i, row, 1) % 3)
end)
-- ...round the doormat, which stays drawn, set into the boards
local function boards(x, z)
  if x >= 32 and x <= 63 and z >= 112 then return nil end
  return planks(x, z)
end

-- ------------------------------------------------------------- the room --

local function furniture(x, y, z, v)
  if z <= 11 then
    local w = northWall(x, y, z, v)
    if w then return w end
    if z <= 9 then return nil end
  end
  if x <= 31 and z <= 30 then return bookcase(x, y, z, v) end
  if x >= 48 and x <= 63 and z >= 16 and z <= 31 then return television(x, y, z, v) end
  if x >= 112 and z >= 16 and z <= 31 then return stairs(x, y, z, v) end
  if z >= 64 and z <= 95 then
    if x >= 48 and x <= 79 then return diningTable(x, y, z, v) end
    return stools(x, y, z, v)
  end
  return nil
end

local function roomFor(v)
  return function(x, y, z)
    if x < 0 or x > 127 then                         -- side walls, outside
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y)
    end
    local hit = furniture(x, y, z, v)
    if hit or y > 0 or z <= 9 then return hit end
    return rug(x, z, v) or boards(x, z)
  end
end

-- unclaimed by the room: the floor, the doormat (it shows drawn), and the
-- stools' cells (their own templates claim them, with the sitter's height)
local OPEN = { [1] = true, [4] = true, [20] = true,
               [2] = true, [3] = true, [18] = true, [19] = true }

function Kit.model(sp, t, mapId)
  local v = Kit.MAPS[mapId]
  if not v then return nil, "not Red's house: " .. tostring(mapId) end
  if t.home == "room" then
    return Lib.model(Kit, sp, t, roomFor(v), OPEN)
  end
  -- a pair of stools, one template a side: evaluated in room coordinates
  local x0 = (t.home == "stoolsW") and 32 or 80
  local m, why = Lib.model(Kit, sp, t, function(x, y, z)
    return stools(x + x0, y, z + 64, v)
  end, {})
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 31, 8
  m.standH = Kit.SEAT_H
  return m
end

Kit.room = roomFor   -- for a headless preview

return Kit
