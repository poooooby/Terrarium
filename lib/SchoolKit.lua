-- Voxel world mode: the Trainer School in Viridian INSIDE (and the plan it
-- shares with the house on Celadon Mansion's roof).
--
-- The homes' contract (lib/HomeLib.lua) on the schoolroom plan
-- (tools/interior_plan.py: VIRIDIAN_SCHOOL_HOUSE and CELADON_MANSION_ROOF_HOUSE
-- hash identically), from the town's own home sheet (tools/town_homes.py),
-- so a classroom in Viridian is painted with Viridian's colours. The plan
-- is the collision, so nothing moves:
--
--   x 16..31   wall       the window (36 over 52)
--   x 48..79   wall       the blackboard (72-75 over 88-91), its chalk
--                         ledge, a lesson on it
--   x112..127  z 10..30   the bookcase of textbooks (38/41, 48/49, 30/31)
--   x 48..79   z 48..79   the pupil's desk: an exercise book open on it, a
--                         pencil (70/71, 86/87 the drawing's book)
--   x 48..63   z 80..95   the stool she sits on (2/3 over 18/19): its own
--                         template, with the sitter's height
--   x 0..15, 112..127  z 96..127   a potted palm each side of the door
--   x 32..63   z112..127  the doormat, left drawn
--
-- Who is here: the teacher at the board and one girl at her desk, copying
-- the lesson -- what beats what, in arrows.
--
-- Coordinates: x east 0..127, z south 0..127, y up. Nothing here is
-- extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/home_viridian.png", SHEET_W = 8, SHEET_H = 32,
              SEAT_H = Lib.SEAT_H }

-- the room on Celadon Mansion's roof is drawn from the same plan, board and
-- all: built the same, in Celadon's colours
Kit.MAPS = { VIRIDIAN_SCHOOL_HOUSE = 1, CELADON_MANSION_ROOF_HOUSE = 2 }
local TOWN = { [1] = "viridian", [2] = "celadon" }
function Kit.sheetFor(mapId)
  local v = Kit.MAPS[mapId]
  return v and ("assets/buildings/home_" .. TOWN[v] .. ".png") or nil
end

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, hash, sideH = Lib.sw, Lib.hash, Lib.sideH

-- the town homes' rows (tools/town_homes.py)
local PLASTER, PLASTER_B, WAINS, OAK, WALNUT, DARK, TRIM, SKY,
      CURT, RUG_A, RUG_B, RUG_EDGE, CUSH_A, CUSH_B, CUSH_C, CUSH_D,
      BOOK_R, BOOK_G, BOOK_B, BOOK_Y, PAPER, CHINA, CLAY, LEAF,
      FLOWER, BRASS, IRON, LIGHT, SOIL, ACC_1, ACC_2, ACC_3 =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

-- ------------------------------------------------------------ the walls --
-- a schoolroom's wall: dark skirting, boards five wide to the rail, cream
-- plaster above, a three-course cornice
local SKIN = {
  skirt = { 2, function(u, y) return sw(WALNUT, 3) end },
  dado = { 10, function(u, y)
    if u % 5 == 0 then return sw(WAINS, 1) end
    if y == 10 then return sw(WAINS, 6) end
    return sw(WAINS, 3 + floor(u / 5) % 3)
  end },
  rail = { 11, sw(OAK, 5) },
  cornice = { 26, function(u, y) return sw(OAK, ({ 3, 4, 6 })[y - 25] or 6) end },
  field = function(u, y) return sw(PLASTER, 4 + hash(floor(u / 6), floor(y / 4), 5) % 3) end,
}
local wallSkin = Lib.wallSkin(SKIN)

-- the window, x 16..31 (the drawing's), the homes' numbers
local window = Lib.northWindow({
  x0 = 17, x1 = 30, y0 = 9, y1 = 24,
  frame = sw(OAK, 4), bar = sw(OAK, 4),
  mullion = function(lx, y) return lx == 6 or lx == 7 or y == 16 or y == 17 end,
  glass = function(lx, y) return sw(SKY, 6 - floor((24 - y) / 4)) end,
  sill = { 8, 12, sw(OAK, 6) },
})
-- tied-back curtains either side of it
local function curtains(x, y, z)
  if y == 25 and z == 11 and x >= 12 and x <= 35 then return sw(BRASS, 4) end
  if y >= 7 and y <= 24 and ((x >= 12 and x <= 16) or (x >= 31 and x <= 35)) then
    if y == 14 then return sw(TRIM, 4) end
    if y < 14 and (x == 12 or x == 35) then return nil end
    return sw(CURT, 3 + x % 2 * 3)
  end
  return nil
end

-- The blackboard, x 48..79: an oak frame round a dark green slate, a chalk
-- ledge a voxel proud under it with two sticks of chalk; on the board the
-- lesson -- three circles, an arrow from each to the next.
local LESSON = {
  "................................",
  "..XXX..........XXX..........XXX.",
  ".X...X..X.....X...X..X.....X...X",
  ".X...X.XXXX...X...X.XXXX...X...X",
  ".X...X..X.....X...X..X.....X...X",
  "..XXX..........XXX..........XXX.",
  "................................",
  "..XXXX.XX.XXXX.....XXX.XXXX.XX..",
}
local function blackboard(x, y, z)
  if x < 48 or x > 79 or y < 11 or y > 25 then return nil end
  local bx = x - 48
  if z == 11 and y == 11 then                                 -- the chalk ledge
    if bx == 9 or bx == 10 or bx == 20 then return sw(TRIM, 6) end
    return sw(OAK, 5)
  end
  if z ~= 10 then return nil end
  if bx == 0 or bx == 31 or y == 12 or y == 25 then return sw(OAK, 3) end
  -- the slate, its chalk
  local row = LESSON[24 - y + 1]
  if row and row:sub(bx + 1, bx + 1) == "X" then return sw(TRIM, 5) end
  return sw(LEAF, (hash(bx, y, 3) % 11 == 0) and 1 or 0)
end

-- a poster beside the board, x 88..99: a chart of what grows from what
local function poster(x, y)
  if x < 88 or x > 99 or y < 13 or y > 23 then return nil end
  if x == 88 or x == 99 or y == 13 or y == 23 then return sw(WALNUT, 4) end
  if y == 21 and x >= 90 and x <= 97 then return sw(DARK, 4) end   -- a title
  for i, c in ipairs({ 91, 94, 97 }) do
    local dx, dy = x - c, y - 17
    if dx * dx + dy * dy <= 1.6 then return sw(({ CUSH_C, CUSH_D, CUSH_A })[i], 4) end
  end
  if y == 17 and (x == 92 or x == 95) then return sw(DARK, 5) end
  return sw(PAPER, 6)
end

local function northWall(x, y, z)
  local handled, tex = window(x, y, z)
  if handled then return tex end
  if z == 10 or z == 11 then
    local c = curtains(x, y, z)
    if c then return c end
    local b = blackboard(x, y, z)
    if b then return b end
    if z == 10 then
      if Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
      return poster(x, y)
    end
    return nil
  end
  if z <= 9 then return wallSkin(x + 5, y) end
  return nil
end

-- the bookcase of textbooks, x 112..127, full height (H 26): its spines in
-- sets of one colour, a globe on top
local function textbooks(ux, s, hy, dz)
  if dz < 4 or dz > 17 then return nil end
  local set = floor((ux - 1) / 7)
  local bid = floor((ux - 1) / 2) + s * 7
  local h = hash(bid, s, 9)
  if h % 13 == 0 then return nil end
  if hy >= 4 + (h % 2) then return nil end
  if hy == 2 and dz == 17 and ux % 2 == 1 then return sw(PAPER, 5) end   -- labels
  return sw(({ BOOK_R, BOOK_B, BOOK_G, BOOK_Y })[(set + s) % 4 + 1], 3 + ux % 2)
end
local function bookcase(x, y, z)
  if x < 112 or z < 10 or z > 30 then return nil end
  local ux, dz = x - 112, z - 10
  if y <= 26 then return Lib.case(ux, y, dz, 26, OAK, DARK, textbooks) end
  -- on top, under the cornice (the room ends at y 28): two books lying
  -- flat, the upper one turned a little
  local hy = y - 27
  if hy == 0 and ux >= 3 and ux <= 12 and dz >= 6 and dz <= 14 then return sw(BOOK_R, 4) end
  if hy == 1 and ux >= 4 and ux <= 11 and dz >= 7 and dz <= 13 then return sw(BOOK_G, 5) end
  return nil
end

-- the pupil's desk, x 48..79, z 48..79: the tea table's frame, a lid of
-- oak; on it her exercise book open, a pencil, a rubber, a ruler
local function desk(tx, y, tz)
  if y <= 5 then
    local lx = (tx >= 3 and tx <= 5) or (tx >= 26 and tx <= 28)
    local lz = (tz >= 3 and tz <= 5) or (tz >= 26 and tz <= 28)
    return (lx and lz) and sw(OAK, 2) or nil
  end
  if y <= 7 then
    if tx >= 2 and tx <= 29 and tz >= 2 and tz <= 29
       and (tx == 2 or tx == 29 or tz == 2 or tz == 29) then return sw(OAK, 1) end
    return nil
  end
  if y <= 9 then
    if Lib.cornerCut(tx, tz, 32, 32, 2) then return nil end
    return sw(OAK, tz % 4 == 0 and 3 or 5)
  end
  if y ~= 10 then return nil end
  -- the exercise book, open, the drawing's place (south-west quarter)
  if tx >= 3 and tx <= 16 and tz >= 13 and tz <= 25 then
    if tx == 9 or tx == 10 then return sw(PAPER, 2) end                  -- the spine
    if (tz - 13) % 3 == 1 and tx ~= 3 and tx ~= 16 then return sw(BOOK_B, 6) end   -- ruled lines
    return sw(PAPER, 6)
  end
  if tz == 9 and tx >= 4 and tx <= 12 then return sw(tx == 12 and DARK or BOOK_Y, 4) end   -- the pencil
  if tx >= 20 and tx <= 22 and tz >= 18 and tz <= 19 then return sw(CUSH_A, 6) end      -- a rubber
  if tz == 6 and tx >= 18 and tx <= 28 then return sw(tx % 2 == 0 and DARK or ACC_3, 5) end   -- a ruler
  return nil
end

-- the stool, at x 48..63, z 80..95 (centre 55.5, 87.5): square, a cushion
local function stool(x, y, z)
  local dx, dz = x - 55.5, z - 87.5
  local ax, az = abs(dx), abs(dz)
  if ax > 5.5 or az > 5.5 or y > 7 then return nil end
  if y <= 4 then
    if ax >= 4 and az >= 4 then return sw(WALNUT, 3) end
    if y == 2 and (ax >= 4 or az >= 4) then return sw(WALNUT, 2) end
    return nil
  end
  if y == 5 then return sw(OAK, 4) end
  if ax > 4.5 or az > 4.5 then return nil end
  return sw(CUSH_D, y == 7 and 5 or 3)
end

-- a potted palm each side of the door, in clay
local function palm(px, y, pz)
  local d2 = px * px + pz * pz
  if y <= 7 then
    local r = 3 + floor(y / 3)
    if d2 > r * r + 1 then return nil end
    if y == 7 and d2 <= (r - 1) * (r - 1) then return sw(SOIL, 2) end
    return sw(CLAY, y == 6 and 6 or 2 + hash(px, 0, pz) % 3)
  end
  if y <= 16 then
    if d2 <= 0.9 then return sw(WALNUT, (y % 3 == 0) and 2 or 4) end
  end
  -- fronds out of the crown: seven, each rising and drooping at the tip
  local r = sqrt(d2)
  if r < 1 then return y <= 18 and sw(LEAF, 2) or nil end
  if r > 9 then return nil end
  local a = math.atan2(pz, px)
  local step = 2 * math.pi / 7
  local k = floor((a + math.pi) / step + 0.5)
  local fa = k * step - math.pi
  local off = abs(math.sin(a - fa)) * r
  local t = r / 9
  if off > 0.4 + 0.8 * math.sin(t * math.pi) * (1 - t * 0.4) then return nil end
  local function fy(rr) return 17 + floor(rr * 0.7 - rr * rr * 0.17) end
  local y1, y2 = fy(r), fy(min(9, r + 0.9))
  if y < min(y1, y2) or y > max(y1, y2) then return nil end
  return sw(LEAF, off < 0.45 and 6 or 3)
end

-- honey boards running north-south, five wide (the town's house's); a
-- schoolroom floor is mostly open, so four shades a plank and a grain
-- streak along it (three measured as one swatch)
local function boards(x, z)
  local col = floor(x / 5)
  local run = z + col * 11
  if x % 5 == 0 or run % 26 == 0 then return sw(OAK, 3) end
  local s = 4 + hash(floor(run / 26), col, 2) % 4
  if (z * 7 + col * 13) % 17 == 0 and x % 5 == 2 then s = s - 1 end
  return sw(OAK, s)
end

-- ------------------------------------------------------------- the room --

local function furniture(x, y, z)
  if z <= 11 then
    local w = northWall(x, y, z)
    if w or z <= 9 then return w end
  end
  if z >= 10 and z <= 30 and x >= 112 then return bookcase(x, y, z) end
  if x >= 48 and x <= 79 and z >= 48 and z <= 79 then return desk(x - 48, y, z - 48) end
  if z >= 108 and (x <= 15 or x >= 112) then
    local east = x >= 112
    return palm(x - (east and 120 or 8), y, z - 120)
  end
  return nil
end

local function room(x, y, z)
  if x < 0 or x > 127 then                         -- side walls, outside
    if y > sideH(z) or z < 0 then return nil end
    return wallSkin(z + 5, y)
  end
  local hit = furniture(x, y, z)
  if hit or y > 0 or z <= 9 then return hit end
  if z >= 112 and x >= 32 and x <= 63 then return nil end           -- the mat, drawn
  return boards(x, z)
end

local OPEN = { [1] = true, [4] = true, [20] = true,
               [2] = true, [3] = true, [18] = true, [19] = true }

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not the school: " .. tostring(mapId) end
  if t.home == "stool" then
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      return stool(x + 48, y, z + 80)
    end, {})
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 15, 8
    m.standH = Kit.SEAT_H
    return m
  end
  return Lib.model(Kit, sp, t, room, OPEN)
end

Kit.room = room   -- for a headless preview

return Kit
