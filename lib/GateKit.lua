-- Voxel world mode: the GATEHOUSES inside -- the route gates, the League's
-- front gate -- read off their own plans.
--
-- Twenty-five maps share the GATE tileset in ten plans (tools/interior_plan.py),
-- and every one is made of the same few things: a wall band along the
-- north, a checker floor, potted palms, the guards' long tables, a counter,
-- statues on plinths, a runner, binoculars at the upstairs window. So this
-- kit does not author ten rooms: it reads the plan (the template is the
-- whole map, data/voxel_heights.lua) and stands each of those things where
-- the drawing puts it, in one hand, on the homes' shell (lib/HomeLib.lua) --
-- the wall 28 tall and 5 thick outside the box, the side walls cut down
-- toward the camera, no south wall, no ceiling. A room is cols*8 x rows*8
-- voxels, x east and z south.
--
-- What the drawing draws, and what stands for it:
--
--   0, 72/74          the north band        a wall: ashlar to the dado,
--                                           cream plaster, a cornice
--   43/41 over 59/42  a door in the band    an arched doorway into the dark
--   32/33 over 50/51  a block of wall       a pier of the same wall
--   17/1              the checker floor     stone flags in two tones
--   55/56             a runner              a red runner, a gold border
--   5/6 ... 53/54     a potted palm         a palm in a clay pot
--   14/15 30/31 50/51 a statue on a plinth  a marble plinth and a bronze urn
--                                           (no figure is redrawn here)
--   7/8 23/24 50/51   the guards' table     an oak table, the watch's
--                                           papers and a lamp on it
--   7/9..9/8 over 50  a counter             a counter, its front in blue
--   36/52/57          binoculars            a pair on a post at the window
--   45/58/61/62       the upstairs window   a long window over the route
--   12/13 over 28/29  the stairs up         an oak flight climbing east
--   10/11 over 26/27  the stairs down       left to the profile's stairwell
--   4/20              the doormat           left drawn
--
-- Pewter's museum (MUSEUM_1F/2F) is drawn in this tileset too, so it is
-- built here on the same wall, floor and palms, with what only it has:
--
--   7/8/9 23/24 (+50) the partitions        a marble-topped oak counter
--                                           (the ticket desk's L)
--   39..25 / .. / 50  a vitrine             an oak plinth, a brass frame;
--                                           ammonites laid on sand (70/71,
--                                           the developer's reading), or
--                                           meteorites on felt (46)
--   7/8 over 34/35    specimen cabinets     open cases of stones, shells, jars
--   2/3 over 18/19    a chair               oak, a green seat, back north
--   76/77 over 92/93  the amber's stand     a low marble drum, a plaque
--   78/79             a picture             a mountain in a walnut frame
--   64..69 / .. / 50  the space shuttle     the orbiter on a marble dais
--
-- Coordinates: x east, z south, y up. A person is sixteen voxels. Nothing
-- here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/gate_room.png", SHEET_W = 8, SHEET_H = 32,
              SEAT_H = Lib.SEAT_H }

-- the maps this kit builds so far (each also needs its plan's template)
Kit.MAPS = { ROUTE_22_GATE = 1, ROUTE_2_GATE = 1,
             VIRIDIAN_FOREST_SOUTH_GATE = 1, VIRIDIAN_FOREST_NORTH_GATE = 1,
             MUSEUM_1F = 1, MUSEUM_2F = 1,
             ROUTE_5_GATE = 1, ROUTE_6_GATE = 1,
             UNDERGROUND_PATH_ROUTE_5 = 1, UNDERGROUND_PATH_ROUTE_6 = 1,
             ROUTE_11_GATE_1F = 1, ROUTE_11_GATE_2F = 1,
             ROUTE_8_GATE = 1,
             ROUTE_7_GATE = 1,
             UNDERGROUND_PATH_ROUTE_7 = 1,
             UNDERGROUND_PATH_ROUTE_8 = 1,
             ROUTE_12_GATE_1F = 1,
             ROUTE_12_GATE_2F = 1,
             ROUTE_15_GATE_1F = 1,
             ROUTE_15_GATE_2F = 1,
             ROUTE_16_GATE_1F = 1,
             ROUTE_16_GATE_2F = 1,
             ROUTE_18_GATE_1F = 1,
             ROUTE_18_GATE_2F = 1,
             SAFARI_ZONE_GATE = 1,
             SAFARI_ZONE_CENTER_REST_HOUSE = 1,
             SAFARI_ZONE_EAST_REST_HOUSE = 1,
             SAFARI_ZONE_NORTH_REST_HOUSE = 1,
             SAFARI_ZONE_WEST_REST_HOUSE = 1,
           }
Kit.MUSEUM = { MUSEUM_1F = true, MUSEUM_2F = true }
Kit.COUNTERS = { UNDERGROUND_PATH_ROUTE_5 = true, UNDERGROUND_PATH_ROUTE_6 = true,
                 UNDERGROUND_PATH_ROUTE_7 = true, UNDERGROUND_PATH_ROUTE_8 = true }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, hash = Lib.sw, Lib.hash
local WALL_H, WALL_D = Lib.WALL_H, Lib.WALL_D

-- rows of the sheet; tools/gatehouse_sheet.py is the mirror of this list
local PLASTER, ASHLAR, ASHLAR_D, FLAG_A, FLAG_B, GROUT, TRIM, DARK,
      OAK, WALNUT, BRASS, IRON, GLASS, SKY, LIGHT, RUNNER,
      GOLD, LEAF, LEAF_DK, CLAY, SOIL, PAPER, STEEL, BLUE,
      BOOK_R, BOOK_B, BOOK_G, BOOK_Y, MARBLE, BRONZE, SHADOW, GREEN =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

-- ------------------------------------------------------------- the wall --
local SKIN = {
  skirt = { 2, function(u, y) return sw(ASHLAR_D, y == 2 and 4 or 3) end },
  -- coursed ashlar to the dado: courses four tall, joints staggered
  dado = { 11, function(u, y)
    local course = floor((y - 3) / 4)
    if (y - 3) % 4 == 3 or (u + course % 2 * 6) % 12 == 0 then return sw(ASHLAR_D, 4) end
    return sw(ASHLAR, 4 + hash(floor((u + course % 2 * 6) / 12), course, 3) % 3)
  end },
  rail = { 12, sw(TRIM, 5) },
  cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
  field = function(u, y) return sw(PLASTER, 4 + hash(floor(u / 6), floor(y / 4), 4) % 2) end,
}
local wallSkin = Lib.wallSkin(SKIN)
local function sideH(z) return Lib.sideH(z) end

-- ======================================================= reading the plan ==

-- The plan as found: tile(c, r), 0-based; nil off the plan.
local function reader(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  return tile, cols, rows
end

-- Find every placement of a pattern (rows of tile ids; 0 = any) in the plan.
local function find(tile, cols, rows, pat)
  local out = {}
  local ph, pw = #pat, #pat[1]
  for r = 0, rows - ph do
    for c = 0, cols - pw do
      local ok = true
      for i = 1, ph do
        for j = 1, pw do
          local want = pat[i][j]
          if want ~= 0 and tile(c + j - 1, r + i - 1) ~= want then ok = false break end
        end
        if not ok then break end
      end
      if ok then out[#out + 1] = { c = c, r = r } end
    end
  end
  return out
end

local function inBox(x, z, b) return x >= b[1] and x <= b[2] and z >= b[3] and z <= b[4] end

-- ============================================================= the things ==

-- a palm in a clay pot: pot centre (cx, cz), fronds out of the crown
local function palm(x, y, z, cx, cz)
  local px, pz = x - cx, z - cz
  local d2 = px * px + pz * pz
  if y <= 7 then
    local r = 3.4 + floor(y / 3) * 0.9
    if d2 > r * r then return nil end
    if y == 7 and d2 <= (r - 1) * (r - 1) then return sw(SOIL, 2) end
    return sw(CLAY, y == 6 and 6 or 2 + hash(floor(px + 9), y, floor(pz + 9)) % 3)
  end
  if y <= 18 and d2 <= 0.9 then return sw(WALNUT, (y % 3 == 0) and 2 or 4) end
  local r = sqrt(d2)
  if r < 1 then return (y <= 20) and sw(LEAF, 2) or nil end
  if r > 10 then return nil end
  local a = math.atan2(pz, px)
  local step = 2 * math.pi / 7
  local k = floor((a + math.pi) / step + 0.5)
  local fa = k * step - math.pi + (cx + cz) * 0.13
  local off = abs(math.sin(a - fa)) * r
  local t = r / 10
  if off > 0.4 + 0.9 * math.sin(t * math.pi) * (1 - t * 0.4) then return nil end
  local function fy(rr) return 19 + floor(rr * 0.7 - rr * rr * 0.15) end
  local y1, y2 = fy(r), fy(min(10, r + 0.9))
  if y < min(y1, y2) or y > max(y1, y2) then return nil end
  return sw(off < 0.45 and LEAF or LEAF_DK, off < 0.45 and 6 or 4)
end

-- a marble plinth and a bronze urn on it (where the drawing stands a
-- statue -- the developer's rule: no Nintendo design is redrawn)
local function urn(x, y, z, cx, cz)
  local dx, dz = x - cx, z - cz
  local ax, az = abs(dx), abs(dz)
  if y <= 1 then return (ax <= 6.5 and az <= 6.5) and sw(MARBLE, 3) or nil end      -- the base
  if y <= 10 then
    if ax > 5.5 or az > 5.5 then return nil end
    if y == 10 then return sw(MARBLE, 6) end
    if (ax >= 4.5 or az >= 4.5) and y >= 3 and y <= 8 then return sw(MARBLE, 4) end   -- a panel
    return sw(MARBLE, 5)
  end
  if y == 11 then return (ax <= 6.5 and az <= 6.5) and sw(MARBLE, 6) or nil end      -- the cap
  -- the urn: a foot, a belly, a neck, a lip
  local r2 = dx * dx + dz * dz
  local hy = y - 12
  local prof = { 2.0, 1.6, 2.6, 3.6, 4.0, 3.8, 3.2, 2.2, 1.8, 2.6 }
  local r = prof[hy + 1]
  if not r then return nil end
  if r2 > r * r then return nil end
  if hy == 9 and r2 <= (r - 1) * (r - 1) then return sw(SOIL, 2) end
  if hy == 4 then return sw(GOLD, 5) end                                   -- a band
  return sw(BRONZE, 3 + (hy % 3) + (dx > 0 and 0 or 1))
end

-- the guards' table: an oak table b = {x0, x1, z0, z1}, its top at y 10,
-- a log book open, a lamp, a mug
local function guardTable(x, y, z, b)
  local tx, tz = x - b[1], z - b[3]
  local w, d = b[2] - b[1] + 1, b[4] - b[3] + 1
  if y <= 7 then
    local lx = tx >= 2 and tx <= 3 or tx >= w - 4 and tx <= w - 3
    local lz = tz >= 2 and tz <= 3 or tz >= d - 4 and tz <= d - 3
    if lx and lz then return sw(WALNUT, 3) end
    if y >= 6 and (tx == 2 or tx == w - 3 or tz == 2 or tz == d - 3)
       and tx >= 2 and tx <= w - 3 and tz >= 2 and tz <= d - 3 then return sw(WALNUT, 2) end
    return nil
  end
  if y <= 9 then
    if Lib.cornerCut(tx, tz, w, d, 1) then return nil end
    return sw(OAK, (y == 9) and (tz % 4 == 0 and 4 or 6) or 3)
  end
  if y ~= 10 and y > 15 then return nil end
  local seed = b[1] + b[3]
  -- the log book, open
  local lz0 = floor(d / 2) - 4
  if y == 10 and tx >= 3 and tx <= 12 and tz >= lz0 and tz <= lz0 + 7 then
    if tx == 7 or tx == 8 then return sw(PAPER, 2) end
    if (tz - lz0) % 2 == 1 and tx ~= 3 and tx ~= 12 then return sw(PAPER, 3) end
    return sw(PAPER, 6)
  end
  -- a lamp at the far end: a brass foot, a stem, a green shade lit under
  local fx, fz = tx - 7.5, tz - 4.5
  local fd = fx * fx + fz * fz
  if y == 10 and fd <= 2.5 then return sw(BRASS, 3) end
  if y >= 11 and y <= 13 and fd <= 0.6 then return sw(BRASS, 5) end
  if y == 14 and fd <= 4.5 then return sw(GREEN, 4) end
  if y == 15 and fd <= 2.5 then return sw(GREEN, 5) end
  if y == 13 and fd <= 2.0 and fd > 0.6 then return sw(LIGHT, 7) end
  -- a mug near the south end
  local mx, mz = tx - 10.5, tz - (d - 6.5)
  local md = mx * mx + mz * mz
  if y >= 10 and y <= 12 and md <= 1.6 then return sw(md <= 0.6 and y == 12 and SOIL or BLUE, 5) end
  return nil
end

-- a counter b = {x0, x1, z0, z1}: kick set back two, a blue panelled
-- front with stiles every sixteen, an oak edge, a laminate top nosed
local function counter(x, y, z, b)
  if y > 9 then return nil end
  local front = b[4]
  if y <= 1 then return (z <= front - 2) and sw(DARK, 3) or nil end
  if y >= 8 then
    if y == 9 and z == front then return nil end
    return sw(PAPER, y == 9 and 5 or 4)
  end
  if z == front then return nil end
  if y == 7 then return sw(OAK, 5) end
  if z == front - 1 then
    local m = (x - b[1]) % 16
    if m == 0 or m == 15 then return sw(TRIM, 4) end
    return sw(BLUE, 4 + (y == 6 and 1 or 0))
  end
  return sw(BLUE, 2)
end

-- binoculars on a post: centre (cx, cz) -- a cast foot, an iron post, the
-- pair on a yoke at eye height, pointing north at the window
local function binoculars(x, y, z, cx, cz)
  local dx, dz = x - cx, z - cz
  if y <= 1 then return (dx * dx + dz * dz <= 5) and sw(IRON, 3) or nil end
  if y <= 11 then return (abs(dx) < 1 and abs(dz) < 1) and sw(IRON, 4) or nil end
  if y == 12 and abs(dx) <= 2 and abs(dz) < 1 then return sw(IRON, 3) end          -- the yoke
  if y >= 13 and y <= 15 and (abs(dx - 1.5) < 1 or abs(dx + 1.5) < 1) and dz >= -3 and dz <= 1 then
    if dz == -3 then return sw(GLASS, 6) end                                        -- lenses
    return sw(GREEN, 4 + (y == 15 and 1 or 0))
  end
  return nil
end

-- the stairs up, climbing east over b = {x0, x1, z0, z1}
local function stairsUp(x, y, z, b)
  local i = floor((x - b[1]) / 2)
  local n = floor((b[2] - b[1] + 1) / 2)
  local top = 3 + floor(i * 25 / max(1, n - 1))
  if z < b[4] then
    if y > top then return nil end
    if y == top then return sw(OAK, (x - b[1]) % 2 == 0 and 6 or 5) end
    if (x - b[1]) % 2 == 0 and y > top - 3 then return sw(OAK, 3) end
    return sw(WALNUT, 2)
  end
  if y <= top + 1 then
    if y >= top then return sw(WALNUT, 4) end
    if y <= 2 then return sw(ASHLAR_D, 3) end
    return wallSkin(x + 7, min(y, 11))
  end
  local rail = 11 + floor((x - b[1]) * 25 / max(1, b[2] - b[1]))
  if y == rail or (y == rail + 1 and (x - b[1]) % 2 == 1) then return sw(WALNUT, 5) end
  if y < rail and (x - b[1]) % 4 == 1 then return sw(TRIM, 4) end
  return nil
end

-- the floor: stone flags eight square in the drawing's two tones, grout
local function flags(x, z)
  if x % 8 == 0 or z % 8 == 0 then return sw(GROUT, 4) end
  local alt = (floor(x / 8) + floor(z / 8)) % 2
  return sw(alt == 0 and FLAG_A or FLAG_B, 4 + hash(floor(x / 8), 0, floor(z / 8)) % 3)
end

-- the runner over a box: red, a gold border, a diamond every sixteen
local function runner(x, z, b)
  local bx = min(x - b[1], b[2] - x)
  if bx == 0 then return sw(GOLD, 4) end
  if bx == 1 then return sw(RUNNER, 3) end
  local cx = (b[1] + b[2]) / 2
  if abs(x - cx) + abs((z % 16) - 7.5) <= 3 then return sw(GOLD, 5) end
  return sw(RUNNER, 4 + hash(x, 0, floor(z / 3)) % 2)
end

-- ============================================================ the museum ==
-- Pewter's museum is drawn in the same tileset, so it stands on the same
-- wall, floor and palms; what only it has is below.

-- a vitrine b = {x0, x1, z0, z1}: an oak plinth to y 7 with a brass plaque
-- on its front, the case over it a brass frame (the glass is clear, so
-- the frame is all that shows), the exhibits on a sand bed inside --
-- `what` "fossil" or "stone", at the two places the drawing shows them
local function vitrine(x, y, z, b, what, spots)
  local x0, x1, z0, z1 = b[1] + 1, b[2] - 1, b[3] + 6, b[4] - 1
  if x < x0 or x > x1 or z < z0 or z > z1 then return nil end
  local edgeX, edgeZ = x == x0 or x == x1, z == z0 or z == z1
  if y <= 1 then
    if x == x0 or x == x1 or z == z0 or z == z1 then return nil end
    return sw(DARK, 3)
  end
  if y <= 7 then
    if z == z1 then
      local cx = (x0 + x1) / 2
      if abs(x - cx) <= 6 and y >= 3 and y <= 5 then
        if y == 4 and abs(x - cx) <= 4 and x % 2 == 0 then return sw(DARK, 4) end
        return sw(BRASS, 5)
      end
      if (x - x0) % 16 == 0 then return sw(WALNUT, 2) end
    end
    return sw(y == 7 and OAK or WALNUT, y == 7 and 5 or 3)
  end
  if y > 21 then return nil end
  -- the frame: corner posts, a rail round the foot and the top, a post
  -- halfway along the front and the back
  local mid = abs(x - (x0 + x1) / 2) < 1
  if (edgeX and edgeZ) or ((y == 8 or y == 21) and (edgeX or edgeZ)) or (mid and edgeZ) then
    return sw(BRASS, y == 21 and 6 or 4)
  end
  if edgeX or edgeZ or y == 21 then return nil end
  if y == 8 then return sw(what == "fossil" and FLAG_B or GREEN, what == "fossil" and 5 or 3) end
  for _, s in ipairs(spots) do
    local u, w = x - s[1], z - s[2]
    if what == "fossil" then
      -- an ammonite (the developer's reading of the drawing): a spiral
      -- shell laid flat on the sand, so the eye over the room reads its
      -- coil -- ribbed, the suture darker, domed a little to the middle
      local r = sqrt(u * u + w * w)
      if r <= 7.2 then
        local top = r <= 6.4 and 10 or 9
        if y <= top then
          -- an even coil, a whorl every 2.4 voxels out from the middle
          local th = (math.atan2(w, u) + math.pi) / (2 * math.pi)
          local f = (r / 2.4 - th) % 1
          if y < top then return sw(CLAY, 3) end
          if f < 0.34 then return sw(WALNUT, 3) end                        -- the suture
          return sw(OAK, (r > 5) and 6 or 5)
        end
      end
    else
      -- a meteorite on a felt cushion: a lumpy grey stone, pale where it
      -- catches the light
      local d2 = u * u + w * w
      local r = 5.6 - (y - 9) * 0.8 + ((hash(x, y, z) % 3) - 1) * 0.35
      if y >= 9 and y <= 15 and d2 <= r * r then
        if y >= 13 or (u < 0 and w < 0 and y >= 11) then return sw(STEEL, 5) end
        return sw(hash(x, y, z) % 4 == 0 and IRON or STEEL, 2 + hash(x, 0, z) % 2)
      end
    end
  end
  return nil
end

-- a specimen cabinet against the north wall (the developer's "glass
-- cabinets"): the homes' open case, 26 tall, every shelf set out with
-- finds -- stones, a small ammonite, a stoppered jar -- one to a bay
-- (in a gatehouse the same cabinet holds the guards' files and books)
local function bookcase(x, y, z, b, museum)
  local dz = z - (b[4] - 20)
  return Lib.case(x - b[1], y, dz, 26, WALNUT, DARK, function(ux, s, hy, d)
    if hy < 1 then return nil end
    if not museum then
      if d < 4 or d > 16 or ux == 0 or ux == 15 then return nil end
      local bk = floor((ux + s * 5) / 2)
      local h = 3 + hash(bk, s, b[1]) % 3
      if hy > h then return nil end
      local row = ({ BOOK_R, BOOK_B, BOOK_G, BOOK_Y, PAPER, BOOK_B })[hash(bk, s, 7) % 6 + 1]
      return sw(row, (ux % 2 == 0) and 3 or 4)
    end
    local bay = floor((ux - 1) / 7)                  -- two bays a shelf
    local cx, cz = 1 + bay * 7 + 3, 14
    local u, w = ux - cx, d - cz
    local kind = hash(b[1] + bay, s, 3) % 3
    if kind == 0 then                                -- a stone
      local r = 3.2 - (hy - 1) * 0.6
      if hy <= 4 and u * u + w * w <= r * r then
        return sw(hash(b[1], s, bay) % 2 == 0 and STEEL or CLAY, 3 + hy)
      end
    elseif kind == 1 then                            -- an ammonite on edge
      local dy = hy - 2.5
      if w >= 0 and w <= 1 and u * u + dy * dy <= 7.5 then
        return sw((u * u + dy * dy <= 1.5) and WALNUT or OAK, 5)
      end
    else                                             -- a jar
      if abs(u) <= 1.5 and abs(w) <= 1.5 and hy <= 4 then
        return sw(hy == 4 and DARK or GLASS, hy == 4 and 3 or 5 + (u < 0 and 1 or 0))
      end
    end
    return nil
  end)
end

-- a chair (the drawing's 2/3 over 18/19): oak legs, a green seat, the back
-- to the north as drawn
local function chair(x, y, z, b)
  local tx, tz = x - b[1], z - b[3]
  if tx < 3 or tx > 12 or tz < 3 or tz > 13 then return nil end
  local legX, legZ = tx == 3 or tx == 12, tz == 3 or tz == 13
  if y <= 5 then return (legX and legZ) and sw(WALNUT, 3) or nil end
  if y <= 7 then return sw(y == 7 and GREEN or OAK, y == 7 and 4 or 4) end
  if tz <= 4 and y <= 17 then
    if y == 17 or legX or (y >= 13 and y <= 15) then return sw(OAK, y == 17 and 6 or 4) end
  end
  return nil
end

-- the pedestal the old amber is shown on: a low marble drum, a brass
-- plaque on its front (the amber itself is the game's own object, set on it)
local function pedestal(x, y, z, cx, cz)
  local dx, dz = x - cx, z - cz
  local d2 = dx * dx + dz * dz
  if y > 5 then return nil end
  if y <= 0 then return d2 <= 6.8 * 6.8 and sw(MARBLE, 3) or nil end
  if y == 5 then return d2 <= 6.6 * 6.6 and sw(MARBLE, 6) or nil end
  if d2 > 5.8 * 5.8 then return nil end
  if dz > 4.5 and abs(dx) <= 2 and y >= 2 and y <= 3 then return sw(BRASS, 5) end
  return sw(MARBLE, 4 + (dx < 0 and 1 or 0))
end

-- a picture in the band (78/79): a walnut frame a voxel proud, the canvas
-- a mountain under a pale sky -- the drawing's dark peak, Mt. Moon
local function picture(x, y, z, b, face)
  local x0, x1, y0, y1 = b[1] + 1, b[2] - 1, 13, 24
  if x < x0 or x > x1 or y < y0 or y > y1 then return nil end
  local ring = x == x0 or x == x1 or y == y0 or y == y1
  if z == face + 2 then return ring and sw(WALNUT, 4) or nil end
  if z ~= face + 1 then return nil end
  if ring then return sw(WALNUT, 3) end
  local u = x - x0
  local peak = y0 + 2 + max(0, 7 - floor(abs(u - 9) * 1.1))
  if y <= y0 + 2 then return sw(GREEN, 3) end
  if y <= peak then return sw(y >= peak - 1 and u > 7 and STEEL or IRON, y >= peak - 1 and 5 or 4) end
  return sw(SKY, 4 + (y > y1 - 4 and 1 or 0))
end

-- the space shuttle on its dais (2F): a marble step, two iron posts, the
-- orbiter nose east -- white over black tiles, delta wings, the fin aft
local function shuttle(x, y, z, b)
  local x0, x1, z0, z1 = b[1] + 1, b[2] - 1, b[3] + 6, b[4] - 1
  if x < x0 or x > x1 or z < z0 or z > z1 then return nil end
  if y <= 2 then
    if y == 2 and (x == x0 or x == x1 or z == z0 or z == z1) then return sw(MARBLE, 6) end
    if z == z1 and y == 1 and abs(x - (x0 + x1) / 2) <= 5 then return sw(BRASS, 5) end
    return sw(MARBLE, 4)
  end
  local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
  local u, w = x - cx, z - cz
  if y <= 10 and (abs(u + 9) < 1 or abs(u - 7) < 1) and abs(w) < 1 then return sw(IRON, 4) end
  if abs(u) > 21 then return nil end
  local cy = 14
  -- the fuselage, tapering to the nose
  local r = 3.6
  if u > 12 then r = 3.6 * (21 - u) / 9 end
  local dy, aw = y - cy, abs(w)
  if dy * dy + w * w <= r * r + 0.3 then
    if u >= 19 then return sw(DARK, 3) end
    if u >= 13 and u <= 15 and dy >= 1 and dy <= 2 and aw <= 2 then return sw(DARK, 2) end
    if dy <= -2 then return sw(DARK, 3) end
    return sw(TRIM, 5 + (dy >= 2 and 1 or 0))
  end
  -- delta wings, flat at the belly
  if (y == 11 or y == 12) and u >= -17 and u <= 8 then
    local span = min(13, (8 - u) * 0.62)
    if aw > 3 and aw <= span then
      if y == 11 then return sw(DARK, 3) end
      return sw((aw >= span - 1) and DARK or TRIM, (aw >= span - 1) and 3 or 4)
    end
  end
  -- the fin: a swept leading edge, the rudder upright
  if aw < 1 and u <= -12 and u >= -20 and y > cy + 3 then
    local top = 25 - max(0, u + 16) * 2
    if y <= top then return sw((u >= -13 or y == top) and DARK or TRIM, 4) end
  end
  -- three engine bells at the tail
  if u <= -20 and ((abs(w) == 2 and (y == 13 or y == 15)) or (w == 0 and y == 16)) then
    return sw(STEEL, 2)
  end
  return nil
end

-- a museum counter over the plan's counter tiles: a marble top a voxel
-- proud, oak panelling with walnut stiles every sixteen, a dark kick set in
local function museumCounter(y, d, x, z)
  if y > 11 then return nil end
  if y >= 10 then
    if y == 11 and d > 0 then
      -- the slab's veining: soft grey drifts across the polish
      local v = (x * 3 + z * 5 + floor(math.sin(x * 0.31 + z * 0.17) * 4)) % 11
      return sw(MARBLE, v == 0 and 2 or (v <= 3 and 3 or 4 + hash(floor(x / 3), 0, floor(z / 3)) % 2))
    end
    return sw(MARBLE, (y == 11) and 3 or 3)
  end
  if d == 0 then return nil end
  if y <= 1 then return d >= 2 and sw(DARK, 3) or nil end
  if d == 1 then
    if (x + z) % 16 == 0 then return sw(WALNUT, 3) end
    if y == 9 or y == 2 then return sw(WALNUT, 4) end
    return sw(OAK, 4 + (y >= 5 and y <= 6 and 1 or 0))
  end
  return sw(WALNUT, 2)
end

-- ============================================================== the room ==

local function build(t, mapId)
  local tile, cols, rows = reader(t)
  local museum = Kit.MUSEUM[mapId] or false
  -- partitions read as one counter tile by tile (the museum's, and the
  -- Underground entrances' L-shaped barriers)
  local counters = museum or Kit.COUNTERS[mapId] or false
  local W, D = cols * 8, rows * 8

  -- the north band: rows 0-1 (wall tiles), or rows 0-3 upstairs
  local BAND = { [0] = true, [72] = true, [74] = true, [32] = true, [33] = true,
                 [50] = true, [51] = true, [45] = true, [58] = true, [61] = true,
                 [62] = true, [47] = true, [60] = true, [46] = true, [43] = true,
                 [41] = true, [59] = true, [42] = true }
  local bandRows = 0
  for r = 0, rows - 1 do
    local all = true
    for c = 0, cols - 1 do
      local v = tile(c, r)
      if not (BAND[v] or v == 14 or v == 15) then all = false break end
    end
    if not all then break end
    bandRows = r + 1
  end
  bandRows = max(2, bandRows)
  local FZ = bandRows * 8 - 6            -- the wall's face: z 0..FZ-1 the body
  local upstairs = tile(2, 0) == 45 or tile(0, 0) == 58

  -- doorways in the band: 43/41 over 59/42 (each a cell wide)
  local doors = {}
  for _, p in ipairs(find(tile, cols, rows, { { 43, 41 }, { 59, 42 } })) do
    doors[#doors + 1] = { p.c * 8 + 1, p.c * 8 + 14 }
  end

  local things = {}
  local function add(kind, box, extra)
    things[#things + 1] = { kind = kind, box = box, extra = extra }
  end
  for _, p in ipairs(find(tile, cols, rows, { { 5, 6 }, { 21, 22 }, { 37, 38 }, { 53, 54 } })) do
    add("palm", { p.c * 8 - 4, p.c * 8 + 19, p.r * 8 + 2, p.r * 8 + 31 },
        { p.c * 8 + 8, p.r * 8 + 26 })
  end
  for _, p in ipairs(find(tile, cols, rows, { { 14, 15 }, { 30, 31 }, { 50, 51 } })) do
    add("urn", { p.c * 8, p.c * 8 + 15, p.r * 8 + 4, p.r * 8 + 23 },
        { p.c * 8 + 7.5, p.r * 8 + 15.5 })
  end
  -- the guards' tables: 7/8 over n rows of 23/24 over 50/51 (in the
  -- museum the same tiles are the ticket counter, read below)
  for _, p in ipairs(museum and {} or find(tile, cols, rows, { { 7, 8 }, { 23, 24 } })) do
    local r1 = p.r + 1
    while tile(p.c, r1) == 23 do r1 = r1 + 1 end
    if tile(p.c, r1) == 50 then
      add("table", { p.c * 8, p.c * 8 + 15, p.r * 8 + 2, r1 * 8 + 7 })
    end
  end
  -- counters: a row 7 9 .. 9 8 over 50 51 ..
  for r = 0, counters and -1 or rows - 2 do
    local c = 0
    while c < cols do
      if tile(c, r) == 7 and tile(c + 1, r) == 9 then
        local c1 = c + 1
        while tile(c1, r) == 9 do c1 = c1 + 1 end
        if tile(c1, r) == 8 then
          add("counter", { c * 8, c1 * 8 + 7, r * 8 + 4, r * 8 + 15 })
          c = c1
        end
      end
      c = c + 1
    end
  end
  -- binoculars: 36 over 52 over 57, one column each
  for _, p in ipairs(find(tile, cols, rows, { { 36 }, { 52 }, { 57 } })) do
    add("binoculars", { p.c * 8 - 2, p.c * 8 + 9, p.r * 8, p.r * 8 + 23 },
        { p.c * 8 + 3.5, p.r * 8 + 12 })
  end
  for _, p in ipairs(find(tile, cols, rows, { { 12, 13 }, { 28, 29 } })) do
    add("stairs", { p.c * 8, p.c * 8 + 15, p.r * 8, p.r * 8 + 15 })
  end
  -- blocks of wall below the band: piers
  for _, p in ipairs(find(tile, cols, rows, { { 32, 33 }, { 50, 51 } })) do
    if p.r >= bandRows then add("pier", { p.c * 8, p.c * 8 + 15, p.r * 8, p.r * 8 + 15 }) end
  end
  -- runners: columns of 55 56 56 55
  local runners = {}
  for _, p in ipairs(find(tile, cols, rows, { { 55, 56, 56, 55 } })) do
    local key = p.c
    local rb = runners[key]
    if not rb then rb = { p.c * 8, p.c * 8 + 31, p.r * 8, p.r * 8 + 7 }; runners[key] = rb end
    rb[3] = min(rb[3], p.r * 8)
    rb[4] = max(rb[4], p.r * 8 + 7)
  end
  -- a runner that runs into the north band is a doorway through it (the
  -- passage gates to Saffron: open north and south)
  for _, rb in pairs(runners) do
    if rb[3] < bandRows * 8 then doors[#doors + 1] = { rb[1] + 2, rb[2] - 2 } end
  end
  -- chairs: 2/3 over 18/19 (the museum's, a gate's upstairs)
  for _, p in ipairs(find(tile, cols, rows, { { 2, 3 }, { 18, 19 } })) do
    add("chair", { p.c * 8, p.c * 8 + 15, p.r * 8, p.r * 8 + 15 })
  end
  -- cabinets: 7/8 over three rows of 34/35
  for _, p in ipairs(find(tile, cols, rows, { { 34, 35 }, { 34, 35 }, { 34, 35 } })) do
    if tile(p.c, p.r - 1) == 7 then
      add("bookcase", { p.c * 8, p.c * 8 + 15, p.r * 8, p.r * 8 + 23 })
    end
  end
  -- the museum's own pieces
  local CTOP = { [7] = true, [8] = true, [9] = true, [23] = true, [24] = true }
  local ctr = {}                       -- counter tiles, by c + r * cols
  if museum then
    for _, p in ipairs(find(tile, cols, rows, {
        { 39, 40, 40, 40, 40, 40, 40, 25 }, { 48, 0, 0, 0, 0, 0, 0, 44 },
        { 49, 0, 0, 0, 0, 0, 0, 44 }, { 50, 51, 50, 51, 50, 51, 50, 51 } })) do
      local what = tile(p.c + 1, p.r + 1) == 70 and "fossil" or "stone"
      local zc = p.r * 8 + 21
      add("vitrine", { p.c * 8, p.c * 8 + 63, p.r * 8, p.r * 8 + 31 },
          { what, { { p.c * 8 + 17, zc }, { p.c * 8 + 46, zc } } })
    end
    for _, p in ipairs(find(tile, cols, rows, { { 76, 77 }, { 92, 93 } })) do
      add("pedestal", { p.c * 8, p.c * 8 + 15, p.r * 8, p.r * 8 + 15 },
          { p.c * 8 + 7.5, p.r * 8 + 9.5 })
    end
    for _, p in ipairs(find(tile, cols, rows, { { 78, 79 } })) do
      add("picture", { p.c * 8, p.c * 8 + 15, FZ + 1, FZ + 2 })
    end
    for _, p in ipairs(find(tile, cols, rows, { { 64, 65, 66, 67, 68, 69 } })) do
      add("shuttle", { p.c * 8, p.c * 8 + 47, p.r * 8, p.r * 8 + 31 })
    end
  end
  if counters then
    for r = 1, rows - 1 do
      for c = 0, cols - 1 do
        local v = tile(c, r)
        if CTOP[v] or ((v == 50 or v == 51) and ctr[c + (r - 1) * cols]) then
          ctr[c + r * cols] = true
        end
      end
    end
  end
  local function isC(x, z)
    if x < 0 or z < 0 or x >= W or z >= D then return false end
    return ctr[floor(x / 8) + floor(z / 8) * cols] or false
  end
  -- how far in from the counter's edge: 0 on the edge, 1, then 2 for inside
  local function cdepth(x, z)
    for k = 1, 2 do
      if not (isC(x + k, z) and isC(x - k, z) and isC(x, z + k) and isC(x, z - k)) then return k - 1 end
    end
    return 2
  end

  -- the mat and the stairwell stay drawn
  local openTiles = { [4] = true, [20] = true, [10] = true, [11] = true, [26] = true, [27] = true }

  local function northWall(x, y, z)
    -- a doorway: an arch into the dark, a white frame, a step
    for _, d in ipairs(doors) do
      if x >= d[1] - 1 and x <= d[2] + 1 then
        local dc = (d[1] + d[2]) / 2
        local head = 21 - floor(((x - dc) / ((d[2] - d[1]) / 2 + 0.5)) ^ 2 * 4)
        if y <= head + 1 then
          if x == d[1] - 1 or x == d[2] + 1 or y >= head then
            if z <= FZ then return sw(TRIM, 5) end
            return nil
          end
          if y <= head then
            if z >= FZ - 4 then return nil end
            return sw(SHADOW, 2)
          end
        end
      end
    end
    -- upstairs: a long window across the band, glass three back, mullions
    if upstairs and y >= 9 and y <= 24 and x >= 6 and x <= W - 7 then
      local ring = y == 9 or y == 24 or (x - 6) % 20 == 0 or x == W - 7
      if ring then
        if z <= FZ then return sw(TRIM, 5) end
      elseif z >= FZ - 3 then
        if z <= FZ then return nil end
      elseif z == FZ - 4 then
        if y == 16 then return sw(TRIM, 4) end
        return sw(SKY, 4 + floor((y - 9) / 4))
      end
      if y == 8 and z >= FZ and z <= FZ + 2 then return sw(TRIM, 6) end
    end
    if z < FZ then return wallSkin(x + 5, y) end
    if z == FZ and Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
    return nil
  end

  local function thingAt(x, y, z)
    for _, th in ipairs(things) do
      if inBox(x, z, th.box) then
        local v
        if th.kind == "palm" then v = palm(x, y, z, th.extra[1], th.extra[2])
        elseif th.kind == "urn" then v = urn(x, y, z, th.extra[1], th.extra[2])
        elseif th.kind == "table" then v = guardTable(x, y, z, th.box)
        elseif th.kind == "counter" then v = counter(x, y, z, th.box)
        elseif th.kind == "binoculars" then v = binoculars(x, y, z, th.extra[1], th.extra[2])
        elseif th.kind == "stairs" then v = stairsUp(x, y, z, th.box)
        elseif th.kind == "vitrine" then v = vitrine(x, y, z, th.box, th.extra[1], th.extra[2])
        elseif th.kind == "bookcase" then v = bookcase(x, y, z, th.box, museum)
        elseif th.kind == "chair" then v = chair(x, y, z, th.box)
        elseif th.kind == "pedestal" then v = pedestal(x, y, z, th.extra[1], th.extra[2])
        elseif th.kind == "picture" then v = picture(x, y, z, th.box, FZ)
        elseif th.kind == "shuttle" then v = shuttle(x, y, z, th.box)
        elseif th.kind == "pier" then
          local top = sideH(z)
          if y < top then v = wallSkin(x + z, min(y, 25))
          elseif y == top then
            -- the coping seen from above: dressed blocks, joints a shade under
            local course = floor(z / 6)
            local u = x + course % 2 * 6
            if z % 6 == 0 or u % 12 == 0 then v = sw(ASHLAR_D, 4)
            else v = sw(ASHLAR, 3 + hash(floor(u / 12), course, 5) % 3) end
          end
        end
        if v then return v end
      end
    end
    return nil
  end

  return function(x, y, z)
    if x < 0 or x > W - 1 then                         -- side walls, outside
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y)
    end
    if z <= FZ then
      local w = northWall(x, y, z)
      if w or z < FZ then return w end
    end
    local hit = thingAt(x, y, z)
    if hit then return hit end
    if counters and isC(x, z) then
      local v = museumCounter(y, cdepth(x, z), x, z)
      if v or y > 0 then return v end
    end
    if y > 0 then return nil end
    local tl = tile(floor(x / 8), floor(z / 8))
    if openTiles[tl] then return nil end
    for _, rb in pairs(runners) do
      if inBox(x, z, rb) then return runner(x, z, rb) end
    end
    return flags(x, z)
  end, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not a gate room: " .. tostring(mapId) end
  local at, W, D = build(t, mapId)
  -- the kit lays the whole floor itself, so it claims it too: a floor
  -- half-tile in a cell the plan makes unwalkable (beside a statue) was
  -- otherwise stood up by the mesher as a block of wall. Only the mat and
  -- the stairwell stay the drawing's.
  local open = { [4] = true, [20] = true, [10] = true, [11] = true, [26] = true, [27] = true }
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmax, m.zmax = W, W - 1 + WALL_D, D - 1
  return m
end

return Kit
