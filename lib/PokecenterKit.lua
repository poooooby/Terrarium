-- Voxel world mode: the Pokemon Centre INSIDE -- every town's, one room.
--
-- Eleven Centres share one 28x16 tile plan (tools/interior_plan.py: they
-- hash identically; Yellow's differs in two blocks), so the room is
-- authored once as one function of position, the way the Mart is
-- (lib/ShopKit.lua), on the homes' shell (lib/HomeLib.lua): the wall 28
-- tall and 5 thick outside the box, the side walls cut down toward the
-- camera, no south wall, no ceiling. The room is 224 x 128 voxels, x east
-- and z south. It is the inside of the Centre the developer built outside
-- (lib/LavenderCivicKit.lua): warm white walls, the Centre's red, the
-- white heart -- no ball, no logotype.
--
-- The plan is the collision, so nothing moves:
--
--   x 0..15, 80..95, 160..175  z 10..47   three piers ending in a round
--                         column with a capital (the drawing's pillars,
--                         16/41 over the base 4/5, 20/21; the developer
--                         read them round in lib/RoomKit.lua `pillar`)
--   x 16..79   z 10..31   the healing machine against the wall: a grill
--                         (72), its console with the screen and buttons
--                         (76/77, 6/22), an edge cabinet (7/13), the tray
--                         the balls are set in on top (58/59 over 74/75)
--   x 16..79   z 32..47   the nurse's counter, a desk bell where the
--                         drawing puts the tray (10)
--   x 96..159  z 10..47   the same for the Cable Club: the link machine
--                         and its counter
--   x 56..71   wall       Red/Blue: the poster (2/3 over 18/19) is the
--                         Centre's heart on a white roundel
--   x 48..63   wall       Yellow: a television on a wall shelf (76/77 over
--                         90/91)
--   x208..223  z 16..31   the stairs up, climbing east (98/99 over 102/103)
--   x208..223  z 48..79   the public PC on its desk (66/70, 82/86, 9/88)
--   x  0..15   z 64..95   the lounge couch with the man the drawing seats on
--                         it -- its own template (`couch`): the figure pass
--                         stands him on the seat (data/voxel_heights.lua,
--                         POKECENTER `figures`)
--   x  0..15   z 48..63   Yellow: a low table of magazines by the couch
--   x 0..31, 96..127, 192..223  z 96..127   three pairs of potted plants
--   x 48..79   z112..127  the doormat, left drawn
--
-- Coordinates: x east 0..223, z south 0..127, y up. Nothing here is
-- extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/pokecenter.png", SHEET_W = 8, SHEET_H = 32,
              SEAT_H = Lib.SEAT_H }

Kit.MAPS = { VIRIDIAN_POKECENTER = 1, PEWTER_POKECENTER = 1, CERULEAN_POKECENTER = 1,
             VERMILION_POKECENTER = 1, LAVENDER_POKECENTER = 1, CELADON_POKECENTER = 1,
             FUCHSIA_POKECENTER = 1, SAFFRON_POKECENTER = 1, CINNABAR_POKECENTER = 1,
             MT_MOON_POKECENTER = 1, ROCK_TUNNEL_POKECENTER = 1,
             -- on the same tileset, built from the same pieces (roomHotel,
             -- roomUpstairs below)
             CELADON_HOTEL = "hotel", POKECENTER_2F = "upstairs",
             INDIGO_PLATEAU_LOBBY = "lobby" }

local floor, abs, max, min, sqrt, atan2 = math.floor, math.abs, math.max, math.min,
                                          math.sqrt, math.atan2
local sw, hash, sideH = Lib.sw, Lib.hash, Lib.sideH
local WALL_H, WALL_D = Lib.WALL_H, Lib.WALL_D
local W, D = 224, 128

-- rows of the sheet; tools/pokecenter.py is the mirror of this list
local PLASTER, TILE, RED, RED_DK, TRIM, DARK, OAK, WALNUT,
      STEEL, STEEL_D, BEIGE, SCREEN, GLOW, PINK, CUSHION, FLOOR,
      FLOOR_B, GROUT, LEAF, LEAF_DK, POT, SOIL, BRASS, GLASS,
      LIGHT, PAPER, BLUE, BLUE_DK, IRON, BOOK_Y, BOOK_G, LAMINATE =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

-- ------------------------------------------------------------ the walls --
-- A dark skirting, a dado of glazed square tiles to a red band at 1.2 m (a
-- clinic's washable wall), warm white plaster, a three-course cornice.
local SKIN = {
  skirt = { 2, function(u, y) return sw(RED_DK, y == 2 and 4 or 3) end },
  dado = { 11, function(u, y)
    if u % 6 == 0 or (y - 3) % 6 == 5 then return sw(TILE, 3) end    -- joints
    return sw(TILE, 5 + hash(floor(u / 6), floor((y - 3) / 6), 3) % 2)
  end },
  rail = { 12, sw(RED, 4) },
  cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
  field = function(u, y) return sw(PLASTER, hash(u, y, 4) % 17 == 0 and 4 or 5) end,
}
local wallSkin = Lib.wallSkin(SKIN)

-- the Centre's heart on a white roundel in a red ring, centred (x0+7.5, 19)
local HEART = { ".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..." }
local function roundel(x, y, x0)
  local dx, dy = x - (x0 + 7.5), y - 19
  local d2 = dx * dx + dy * dy
  if d2 > 49 then return nil end
  if d2 > 36 then return sw(RED, 4) end
  local gx, gy = floor(dx + 3.5) + 1, floor(21.5 - y) + 1
  local row = HEART[gy]
  if row and gx >= 1 and gx <= 7 and row:sub(gx, gx) == "X" then return sw(RED, 5) end
  return sw(TRIM, 6)
end

-- Yellow's television on its wall shelf, x 48..63: a shelf on two
-- brackets at y 12, the set on it, the picture on
local function television(x, y, z)
  if x < 48 or x > 63 or z > 17 then return nil end
  local tx = x - 48
  if y == 12 and z <= 15 then return sw(WALNUT, 5) end                 -- the shelf
  if y <= 11 and y >= 9 and (tx == 2 or tx == 13) and z <= 9 + (12 - y) * 2 then
    return sw(IRON, 4)                                                  -- brackets
  end
  -- the set is a shallow one, four deep (z 10..13): any deeper and its
  -- top, seen from the camera, was a black slab over the picture
  if y < 13 or y > 23 or tx < 1 or tx > 14 or z < 10 or z > 13 then return nil end
  if y == 23 then return sw(STEEL_D, 4) end                            -- its top
  if z == 13 then
    if tx >= 2 and tx <= 12 and y >= 14 and y <= 22 then
      -- a cartoon on: sky over grass, a yellow figure in the middle
      if tx >= 6 and tx <= 8 and y >= 16 and y <= 18 then return sw(BOOK_Y, 6) end
      if y <= 16 then return sw(LEAF, 5) end
      return sw(GLASS, 6)
    end
    if tx == 13 and (y == 16 or y == 19) then return sw(STEEL, 5) end   -- knobs
    return sw(DARK, 4)
  end
  return sw(DARK, 3)
end

-- a notice board in bay three: health tips pinned up, x 184..199
local function noticeBoard(x, y)
  if x < 184 or x > 199 or y < 13 or y > 23 then return nil end
  if x == 184 or x == 199 or y == 13 or y == 23 then return sw(OAK, 3) end
  for _, p in ipairs({ { 186, 15, 190, 21 }, { 192, 16, 197, 22 } }) do
    if x >= p[1] and x <= p[3] and y >= p[2] and y <= p[4] then
      if x == p[1] + 1 and y == p[4] then return sw(RED, 5) end          -- the pin
      if y == p[4] - 1 and x > p[1] and x < p[3] then return sw(PINK, 4) end
      if (y - p[2]) % 2 == 0 and x > p[1] and x < p[3] then return sw(PAPER, 3) end
      return sw(PAPER, 6)
    end
  end
  return sw(OAK, 5 + (x + y) % 2)
end

-- two sconces either side of the notice board
local function sconce(x, y)
  if (x == 180 or x == 181 or x == 202 or x == 203) and y >= 16 and y <= 21 then
    if y == 16 then return sw(IRON, 3) end
    if y == 21 then return sw(BRASS, 3) end
    return sw(LIGHT, 5)
  end
  return nil
end

local function northWall(x, y, z, yellow)
  if z <= 9 then return wallSkin(x + 5, y) end
  if z == 10 then
    if not yellow then
      local r = roundel(x, y, 56)
      if r then return r end
    end
    if Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
    return noticeBoard(x, y) or sconce(x, y)
  end
  return nil
end

-- --------------------------------------------------- piers and columns --
-- Each pier stands from the wall out to z 31 in the wall's own skin, and
-- ends in a round column standing in the drawing's base cell (z 32..47):
-- a square plinth, a torus, a fluted shaft, a capital and its abacus under
-- the cornice.
local PIERS = { 0, 80, 160 }
local function pier(x, y, z, x0)
  local lx = x - x0                                  -- 0..15
  if z <= 31 then
    if lx < 2 or lx > 13 or y > WALL_H - 1 then return nil end
    if Lib.proudCourse(SKIN, y) and (lx == 2 or lx == 13) then return wallSkin(z + 3, y) end
    if lx == 2 or lx == 13 then return wallSkin(z + 3, y) end
    if y >= WALL_H - 1 then return sw(TRIM, 5) end                       -- its top
    return sw(PLASTER, 4)                                                -- (inside)
  end
  if z > 47 or y > WALL_H - 1 then return nil end
  local dx, dz = lx - 7.5, z - 39.5
  local r = sqrt(dx * dx + dz * dz)
  if y <= 2 then                                                        -- plinth
    if abs(dx) <= 6.5 and abs(dz) <= 6.5 then return sw(RED_DK, y == 2 and 4 or 3) end
    return nil
  end
  if y == 3 then return r <= 6.4 and sw(TRIM, 4) or nil end             -- torus
  if y >= 26 then                                                       -- abacus
    if abs(dx) <= 6.5 and abs(dz) <= 6.5 then return sw(TRIM, y == 27 and 6 or 5) end
    return nil
  end
  if y >= 24 then return r <= 6.4 - (25 - y) * 0.6 and sw(TRIM, 5) or nil end   -- capital
  if r > 5.4 then return nil end
  -- the shaft: twelve flutes, a shadowed groove between each pair
  local a = atan2(dz, dx)
  local flute = floor((a + math.pi) / (math.pi / 6)) % 2
  return sw(PLASTER, flute == 0 and 5 or 3)
end

-- ------------------------------------------------------------ counters --
-- 10 tall (CTOP, as the Mart's): a dark kick set back two, a panelled red
-- front with white stiles every sixteen, an oak edge band, a laminate top
-- two voxels thick nosed on its room edge. x0..x1, front at z 45.
local CTOP = 10
local function counter(x, y, z, x0, x1)
  if z < 33 or z > 46 or y > CTOP - 1 then return nil end
  if y <= 1 then return z <= 43 and sw(DARK, 3) or nil end
  if y >= 8 then
    if y == 9 and z == 46 then return nil end                           -- the nose
    return sw(LAMINATE, y == 9 and 5 or 4)
  end
  if z == 46 then return nil end
  if y == 7 then return sw(OAK, 5) end                                   -- edge band
  if z == 45 then
    local m = (x - x0) % 16
    if m == 0 or m == 15 then return sw(TRIM, 4) end                   -- stiles
    if y == 2 then return sw(TRIM, 3) end
    return sw(RED, 4 + (y == 6 and 1 or 0))
  end
  return sw(RED_DK, 3)
end

-- what stands on the nurse's counter: a brass desk bell where the drawing
-- puts the tray, a leaflet stand at the west end
local function onNurseCounter(x, y, z)
  local hy = y - CTOP
  if hy < 0 or hy > 5 then return nil end
  local bx, bz = x - 59.5, z - 39.5
  local bd = bx * bx + bz * bz
  if hy == 0 and bd <= 4.5 then return sw(WALNUT, 4) end                -- its base
  if hy >= 1 and hy <= 2 and bd <= 3.2 - (hy - 1) * 1.5 then return sw(BRASS, 4 + hy) end
  if hy == 3 and bd <= 0.6 then return sw(BRASS, 6) end                 -- the button
  if x >= 22 and x <= 29 and z >= 36 and z <= 39 then                    -- leaflets
    if hy <= 4 and z == 36 then return sw(STEEL, 5) end
    if hy <= 3 and z >= 37 then
      return sw(({ PINK, BOOK_Y, GLASS, BOOK_G })[(x - 22) % 4 + 1], 4 + hy % 2)
    end
  end
  return nil
end

-- on the Cable Club's: a stand with two arrows, this way and that, and a
-- coiled link cable
local ARROWS = { "..X.....", ".XXXXXXX", "..X.....", "........", ".....X..", "XXXXXXX.", ".....X.." }
local function onLinkCounter(x, y, z)
  local hy = y - CTOP
  if hy < 0 or hy > 9 then return nil end
  if z == 40 and x >= 122 and x <= 131 then
    if hy == 0 then return sw(STEEL_D, 4) end
    if x == 122 or x == 131 or hy == 1 or hy == 9 then return sw(BLUE, 4) end
    local gx, gy = x - 122, 9 - hy
    local row = ARROWS[gy]
    if row and row:sub(gx, gx) == "X" then return sw(BLUE_DK, 4) end
    return sw(TRIM, 6)
  end
  -- the cable, coiled flat: one loop, a voxel thick, its plug at the end
  local cx, cz = x - 108.5, z - 39.5
  local r = sqrt(cx * cx + cz * cz)
  if hy == 0 and r >= 2.4 and r <= 3.4 then return sw(STEEL_D, 4) end
  if hy == 0 and x >= 111 and x <= 113 and z == 42 then return sw(BLUE, 4) end
  return nil
end

-- ------------------------------------------------------------ machines --
-- Against the wall behind each counter, x m0..m0+31: a grill cabinet
-- (x m0+1..m0+7), the console with its screen and buttons (m0+8..m0+23),
-- an edge cabinet (m0+24..m0+30), 14 tall, front at z 28; on the
-- console's top at the back the tray the balls are set in -- six round
-- cups lit from within (no ball is drawn).
local function machine(x, y, z, m0, link)
  if z < 10 or z > 29 then return nil end
  local lx = x - m0                                   -- 0..31
  if lx < 1 or lx > 30 then return nil end
  local accent = link and BLUE or RED
  local TOPY = 13
  if y <= TOPY then
    if z == 29 then return nil end
    if y <= 1 then return z <= 26 and sw(DARK, 3) or nil end            -- kick
    if y == TOPY then return sw(BEIGE, z == 28 and 6 or 5) end
    if z < 28 then return sw(BEIGE, 3) end
    -- the front
    if lx <= 7 then                                                     -- the grill
      if lx == 1 or lx == 7 then return sw(BEIGE, 4) end
      return sw(y % 2 == 0 and STEEL_D or STEEL, 4)
    end
    if lx >= 24 then                                                    -- the edge cabinet
      if lx == 24 or lx == 30 or y == 2 then return sw(BEIGE, 4) end
      if y == 7 then return sw(BEIGE, 2) end                            -- drawer line
      if lx == 27 and (y == 5 or y == 10) then return sw(STEEL, 6) end  -- pulls
      return sw(BEIGE, 5)
    end
    -- the console: the screen y 7..11, the buttons y 3..5
    if y >= 7 and y <= 11 and lx >= 10 and lx <= 21 then
      if y == 7 or y == 11 or lx == 10 or lx == 21 then return sw(DARK, 4) end
      if link then
        -- two arrows passing each other: east along the top, west along
        -- the bottom, each with its head turned down or up
        if y == 10 and lx >= 12 and lx <= 18 then return sw(GLOW, 6) end
        if y == 9 and lx == 17 then return sw(GLOW, 5) end
        if y == 8 and lx >= 13 and lx <= 19 then return sw(GLOW, 6) end
        if y == 9 and lx == 14 then return sw(GLOW, 5) end
        return sw(SCREEN, 4)
      end
      -- a heartbeat across it
      local beat = { [11] = 9, [12] = 9, [13] = 9, [14] = 10, [15] = 8, [16] = 10, [17] = 9,
                     [18] = 9, [19] = 9, [20] = 9 }
      if beat[lx] == y then return sw(GLOW, 6) end
      return sw(SCREEN, 4)
    end
    if y >= 3 and y <= 5 and lx >= 11 and lx <= 20 and (lx - 11) % 3 ~= 2 then
      return sw(({ accent, BOOK_Y, GLOW, accent })[floor((lx - 11) / 3) + 1], y == 5 and 6 or 4)
    end
    if y == 6 then return sw(accent, 4) end                              -- a band
    return sw(BEIGE, 5)
  end
  -- the tray on top, at the back: x m0+9..m0+22, z 11..19, y 14..17
  if lx < 9 or lx > 22 or z < 11 or z > 19 or y > 17 then return nil end
  local hy = y - TOPY - 1                                               -- 0..3
  if link then
    -- the cable panel: two sockets, a cable from each down to the counter
    if z == 19 and hy <= 3 then
      if (lx == 12 or lx == 19) and hy == 2 then return sw(DARK, 2) end
      return sw(STEEL, 5)
    end
    if z >= 11 and z <= 18 and hy == 0 then return sw(STEEL_D, 4) end
    return nil
  end
  -- a plate two voxels thick, its top a cream face with six round cups
  -- sunk in it, two rows of three, each lit soft rose from within (raised
  -- rims round them read as six little posts)
  if hy >= 2 then return nil end
  if hy == 0 then return sw(BEIGE, 4) end
  for _, c in ipairs({ { 11.5, 13.5 }, { 15.5, 13.5 }, { 19.5, 13.5 },
                       { 11.5, 17 }, { 15.5, 17 }, { 19.5, 17 } }) do
    local dx, dz = lx - c[1] + 0.5, z - c[2]
    if dx * dx + dz * dz <= 2.2 then return sw(PINK, 5) end
  end
  if lx == 9 or lx == 22 or z == 11 or z == 19 then return sw(BEIGE, 4) end
  return sw(BEIGE, 6)
end

-- --------------------------------------------------------- the stairs --
-- up to the floor above, climbing east, x 208..223, z 16..31: eight steps
-- two voxels deep, oak treads with a lighter nose, a panelled stringer on
-- the south side, a handrail on balusters over it
local function stairs(x, y, z)
  if x < 208 or x > 223 or z < 16 or z > 31 then return nil end
  local i = floor((x - 208) / 2)
  local top = 3 + floor(i * 25 / 7)
  if z <= 30 then
    if y > top then return nil end
    if y == top then return sw(OAK, (x - 208) % 2 == 0 and 6 or 5) end
    if (x - 208) % 2 == 0 and y > top - 3 then return sw(OAK, 3) end
    return sw(WALNUT, 2)
  end
  if y <= top + 1 then
    if y >= top then return sw(WALNUT, 4) end
    if y <= 2 then return sw(RED_DK, 3) end
    return wallSkin(x + 7, min(y, 11))
  end
  local rail = 11 + floor((x - 208) * 25 / 14)
  if y == rail or (y == rail + 1 and (x - 208) % 2 == 1) then return sw(WALNUT, 5) end
  if y < rail and (x - 208) % 4 == 1 then return sw(TRIM, 4) end
  return nil
end

-- ------------------------------------------------------------- the PC --
-- the public PC against the east wall, x 208..223: a desk in the south
-- cell (z 64..79), the terminal on it, its screen on, a keyboard in front
local function pc(x, y, z)
  if x < 208 or x > 223 or z < 48 or z > 79 then return nil end
  local tx, tz = x - 208, z - 64
  if tz < 0 then return nil end
  if y <= 8 then
    if y <= 1 then return (tz >= 2 and tz <= 13 and tx >= 1 and tx <= 14) and sw(DARK, 3) or nil end
    if tz == 14 and tx >= 1 and tx <= 14 then
      if tx == 7 or tx == 8 then return sw(WALNUT, 3) end
      if y == 5 and (tx == 5 or tx == 10) then return sw(BRASS, 5) end
      return sw(WALNUT, 5)
    end
    if tx == 0 or tx == 15 or tz > 14 then return nil end
    if y == 8 then return sw(OAK, 6) end
    return sw(WALNUT, 4)
  end
  if y == 9 and tz <= 15 and tx >= 0 and tx <= 15 then
    return (tz == 15 or tx == 0 or tx == 15) and sw(OAK, 4) or sw(OAK, 6)         -- the top
  end
  local mx = tx - 7.5
  -- the terminal: a beige cabinet, its back narrowing, the screen facing south
  if y >= 10 and y <= 20 then
    if tz >= 6 and tz <= 10 and abs(mx) <= 6.5 then
      if tz == 10 and y >= 12 and y <= 19 and abs(mx) <= 5 then
        if (y == 17 or y == 15 or y == 13) and (tx + y) % 3 ~= 0 then return sw(GLOW, 6) end
        return sw(SCREEN, 4)
      end
      if y == 10 then return sw(BEIGE, 3) end
      return sw(BEIGE, 5)
    end
    if tz >= 1 and tz <= 5 and abs(mx) <= 4.5 - (5 - tz) * 0.4 and y <= 19 then return sw(BEIGE, 4) end
  end
  if y == 10 and tz >= 12 and tz <= 14 and tx >= 3 and tx <= 12 then
    return sw((tx + tz) % 2 == 0 and BEIGE or PAPER, 5)
  end
  return nil
end

-- ---------------------------------------------------------- the couch --
-- one cell wide, two long, against the west wall: a walnut frame, red
-- cushions, its back against the wall, arms at both ends; the seat's top
-- is y 7, so the man the drawing seats here sits ON it (standH 8)
local function couch(x, y, z)
  if x > 15 or z < 64 or z > 95 then return nil end
  local lz = z - 64                                   -- 0..31
  if y <= 1 then
    if (x <= 2 or x >= 12) and (lz <= 2 or lz >= 29) then return sw(WALNUT, 3) end   -- feet
    return nil
  end
  local arm = lz <= 1 or lz >= 30
  local back = x <= 2
  if arm then
    if y > 10 then return nil end
    if y == 10 then return sw(WALNUT, 5) end
    return sw(CUSHION, 3)
  end
  if back then
    if y > 14 then return nil end
    if y == 14 then return sw(WALNUT, 5) end
    return sw(CUSHION, 3 + (lz % 8 == 0 and 0 or 1))
  end
  if y > 7 then return nil end
  if y <= 3 then return sw(x == 15 and WALNUT or CUSHION, x == 15 and 4 or 2) end
  if y == 7 then
    if lz == 15 or lz == 16 then return sw(CUSHION, 3) end            -- between the cushions
    return sw(CUSHION, 5 + hash(x, 0, z) % 2)
  end
  return sw(CUSHION, 4)
end

-- Yellow's low table of magazines by the couch, x 1..14, z 49..62
local function magazineTable(x, y, z)
  if x < 1 or x > 14 or z < 49 or z > 62 or y > 10 then return nil end
  if y <= 7 then
    local leg = (x <= 2 or x >= 13) and (z <= 50 or z >= 61)
    return leg and sw(WALNUT, 3) or nil
  end
  if y <= 9 then return sw(OAK, y == 9 and 6 or 4) end
  -- the magazines, fanned
  for i, m in ipairs({ { 3, 52, 8, 57 }, { 6, 55, 11, 60 }, { 9, 51, 12, 54 } }) do
    if x >= m[1] and x <= m[3] and z >= m[2] and z <= m[4] then
      return sw(({ PINK, BOOK_Y, GLASS })[i], 4 + (x + z) % 2)
    end
  end
  return nil
end

-- ---------------------------------------------------------- the plants --
-- in olive pots, as the drawing pots them: a round pot (z 112..127), a
-- crown of leaves over it, two to a pair, x centres +7.5 and +23.5
local PLANTS = { 0, 96, 192 }
local function plant(x, y, z, x0)
  local lx = x - x0
  if lx < 0 or lx > 31 or z < 104 then return nil end
  local cx = (lx < 16) and 7.5 or 23.5
  local px, pz = lx - cx, z - 119.5
  local d2 = px * px + pz * pz
  if y <= 8 then
    local r = 4.6 + y * 0.12
    if d2 > r * r then return nil end
    if y == 8 then return d2 <= (r - 1) * (r - 1) and sw(SOIL, 3) or sw(POT, 6) end
    if y == 0 then return sw(POT, 2) end
    if y == 7 then return sw(POT, 5) end                                -- its rim
    return sw(POT, 3 + hash(floor(px + 8), y, floor(pz + 8)) % 2)
  end
  -- the crown: a leafy ball, holes in it, the lit leaves on top; kept to
  -- y 21 or so, so a player standing north of the pair still shows over it
  local cy = 15
  local e = d2 / 46 + (y - cy) * (y - cy) / 30
  if e > 1 then
    if d2 <= 1 and y <= 12 then return sw(WALNUT, 3) end               -- the stem
    return nil
  end
  local hsh = hash(floor(px + 10), y, floor(pz + 10))
  if hsh % 7 == 0 then return nil end
  if y >= cy + 3 then return sw(LEAF, 5 + hsh % 2) end
  return sw((hsh % 3 == 0) and LEAF_DK or LEAF, 3 + hsh % 3)
end

-- ----------------------------------------------------------- the floor --
-- cream tiles eight square, grout between, and where four meet on the
-- drawing's sixteen grid a small rose diamond -- the drawing's pattern
local function floorAt(x, z)
  local gx, gz = x % 16, z % 16
  local dx, dz = abs(gx - 7.5) , abs(gz - 7.5)
  if dx + dz <= 2 then return sw(PINK, 4) end
  if x % 8 == 0 or z % 8 == 0 then return sw(GROUT, 4) end
  local alt = (floor(x / 8) + floor(z / 8)) % 2
  return sw(alt == 0 and FLOOR or FLOOR_B, 4 + hash(floor(x / 8), 0, floor(z / 8)) % 3)
end

-- -------------------------------------------------------------- the room --

local function furniture(x, y, z, yellow)
  if yellow and z >= 10 and z <= 17 then
    local t = television(x, y, z)
    if t then return t end
  end
  if z <= 10 then
    local w = northWall(x, y, z, yellow)
    if w or z <= 9 then return w end
  end
  for _, p0 in ipairs(PIERS) do
    if x >= p0 and x <= p0 + 15 and z <= 47 then return pier(x, y, z, p0) end
  end
  if z >= 32 and z <= 47 then
    if x >= 16 and x <= 79 then
      return counter(x, y, z, 16, 79) or onNurseCounter(x, y, z)
    end
    if x >= 96 and x <= 159 then
      return counter(x, y, z, 96, 159) or onLinkCounter(x, y, z)
    end
  end
  if z >= 10 and z <= 31 then
    if x >= 16 and x <= 47 then return machine(x, y, z, 16, false) end
    if x >= 96 and x <= 127 then return machine(x, y, z, 96, true) end
    if x >= 208 then return stairs(x, y, z) end
  end
  if x >= 208 and z >= 48 and z <= 79 then return pc(x, y, z) end
  if yellow and x <= 15 and z >= 48 and z <= 63 then return magazineTable(x, y, z) end
  if z >= 104 then
    for _, p0 in ipairs(PLANTS) do
      if x >= p0 and x <= p0 + 31 then return plant(x, y, z, p0) end
    end
  end
  return nil
end

-- ------------------------------------------- the hotel, the floor above --
-- Celadon's hotel is the Centre's room without the machines: the wall, a
-- reception counter the whole width (the drawing's row 8s, its bell where
-- the drawing puts the tray, 10), a pair of plants behind it in the north
-- east, the couch, the plants by the door, the mat. Yellow's adds a bell
-- on the counter (10) and a magazine table by the couch.
local function bell(x, y, z, bx)
  local hy = y - CTOP
  if hy < 0 or hy > 3 then return nil end
  local dx, dz = x - bx, z - 39.5
  local bd = dx * dx + dz * dz
  if hy == 0 and bd <= 4.5 then return sw(WALNUT, 4) end
  if hy >= 1 and hy <= 2 and bd <= 3.2 - (hy - 1) * 1.5 then return sw(BRASS, 4 + hy) end
  if hy == 3 and bd <= 0.6 then return sw(BRASS, 6) end
  return nil
end

local function hotelRoom(yellow)
  local bx = yellow and 59.5 or -100
  return function(x, y, z)
    if x < 0 or x > W - 1 then
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y)
    end
    if z <= 9 then return wallSkin(x + 5, y) end
    if z == 10 and x < 192 then
      if Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
      local nb = noticeBoard(x, y) or sconce(x, y)
      if nb then return nb end
    end
    if z <= 31 and x >= 192 then
      -- the corner pair, before the wall
      local v = plant(x, y, z + 96, 192)
      if v then return v end
    end
    if z >= 32 and z <= 47 then
      local v = counter(x, y, z, 0, W - 1) or bell(x, y, z, bx)
      if v or y > 0 then return v end
    end
    if yellow and x <= 15 and z >= 48 and z <= 63 then
      local v = magazineTable(x, y, z)
      if v then return v end
    end
    if z >= 104 then
      for _, p0 in ipairs(PLANTS) do
        if x >= p0 and x <= p0 + 31 then
          local v = plant(x, y, z, p0)
          if v then return v end
        end
      end
    end
    if y > 0 then return nil end
    if z >= 112 and x >= 48 and x <= 79 then return nil end          -- the mat, drawn
    if x <= 15 and z >= 64 and z <= 95 then return nil end            -- the couch's own
    return floorAt(x, z)
  end
end

-- The floor above: the Cable Club's. Two doors in the north wall (the
-- drawing's 92..95 at x 96..111 and 160..175) into the link rooms, a
-- counter before them the length of the room with a lifting flap before
-- each door (90/91), a pier at its east end (x 192..207), the stairs down
-- in the corner beyond it (96/97 over 100/101: a well with its rail), two
-- pairs of plants by the south wall.
local DOORS2F = { 96, 160 }
local function doorway(x, y, z, d0)
  local lx = x - d0                                     -- 0..15
  if y > WALL_H - 1 then return nil end
  if lx <= 1 or lx >= 14 or y >= 22 then
    if y >= 22 and y <= 23 or lx == 1 or lx == 14 then return sw(TRIM, 5) end   -- the frame
    return wallSkin(x + 5, y)
  end
  if z <= 5 then return sw(DARK, 2 + (y <= 1 and 0 or 1)) end         -- the dark beyond
  if y == 0 then return sw(LAMINATE, 3) end                           -- its threshold
  return nil
end

local function upstairsRoom()
  return function(x, y, z)
    if x < 0 or x > W - 1 then
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y)
    end
    if z <= 9 then
      for _, d0 in ipairs(DOORS2F) do
        if x >= d0 and x <= d0 + 15 then return doorway(x, y, z, d0) end
      end
      if x >= 208 and z >= 0 then return wallSkin(x + 5, y) end
      if x >= 192 and x <= 207 then return pier(x, y, max(z, 10), 192) end
      return wallSkin(x + 5, y)
    end
    if z == 10 and x < 192 then
      local inDoor = false
      for _, d0 in ipairs(DOORS2F) do if x >= d0 and x <= d0 + 15 then inDoor = true end end
      if not inDoor and Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
    end
    if x >= 192 and x <= 207 and z <= 47 then return pier(x, y, z, 192) end
    if x >= 208 and z >= 16 and z <= 31 then
      -- the stairwell: a rail round its west and south, the well dark
      local lx, lz = x - 208, z - 16
      if (lz == 15 or (lx == 0 and lz > 0)) and y <= 10 then
        if y == 10 then return sw(WALNUT, 5) end
        if (lx + lz) % 4 == 0 then return sw(TRIM, 4) end
        return nil
      end
      if y == 0 and lz < 15 then
        local step = floor(lx / 4)
        return sw(DARK, 3 - min(3, step))
      end
      return nil
    end
    if z >= 32 and z <= 47 and x < 192 then
      for _, d0 in ipairs(DOORS2F) do
        if x >= d0 and x <= d0 + 15 then
          -- the flap: the counter's height, a hinge line, a lighter top
          if y < CTOP and z >= 33 and z <= 45 then
            if y >= 8 then return sw(LAMINATE, (x - d0 == 0 or x - d0 == 15) and 3 or 6) end
            if z == 45 then return sw(RED, 3 + ((x - d0) % 5 == 0 and 2 or 0)) end
            return sw(RED_DK, 3)
          end
          if y > 0 then return nil end
          return floorAt(x, z)
        end
      end
      local v = counter(x, y, z, 0, 191)
      if v or y > 0 then return v end
    end
    if z >= 104 then
      for _, p0 in ipairs({ 0, 192 }) do
        if x >= p0 and x <= p0 + 31 then
          local v = plant(x, y, z, p0)
          if v then return v end
        end
      end
    end
    if y > 0 then return nil end
    return floorAt(x, z)
  end
end

-- --------------------------------------------- the Plateau's lobby --
-- The Indigo Plateau's lobby is two rooms in one plan (MART tiles, the
-- Centre's drawing): the Centre on the east, the Centre's own plan with
-- its last four columns cut out (lobby x 64..191 is the Centre's 0..127,
-- lobby x 192..255 its 160..223; lobby z 64.. its 0..), its back wall
-- drawn four rows deep (z 48..79); a shop in the west -- coolers and a
-- sale case on the north wall, the clerk's corner behind an L counter
-- with the till on it and a shelf behind, two gondolas -- and the door to
-- the League in the north wall (x 128..143). North-east of the Centre's
-- wall is the dark outside (x >= 160, z < 48). In the shop's blue.
local GOODS = { RED, BOOK_Y, BOOK_G, BLUE, PINK, GLASS, BEIGE }
local function goods(x, y, z, seed)
  local k = hash(floor(x / 3), floor(y / 3), seed + floor(z / 3)) % #GOODS + 1
  return sw(GOODS[k], 4 + (y % 3 == 2 and 1 or 0))
end

-- a reach-in cooler, x0..x0+15, its glass door at z 28..29
local function cooler(x, y, z, x0)
  local lx = x - x0
  if z > 29 or y > 25 then return nil end
  if y == 25 or y <= 1 then return sw(STEEL_D, y == 25 and 5 or 3) end
  if z < 28 then
    -- inside: shelves of bottles, lit
    if z >= 20 and lx >= 2 and lx <= 13 then
      if (y - 2) % 6 == 0 then return sw(STEEL, 5) end
      if z >= 24 and lx % 2 == 0 then return goods(x, y, z, 7) end
      return sw(LIGHT, 4)
    end
    return sw(STEEL, 3)
  end
  if lx <= 1 or lx >= 14 or y >= 22 then
    if y >= 22 and z == 29 then return sw(BLUE, 5) end                   -- its sign band
    return sw(STEEL, 4)
  end
  if z == 29 then return nil end                                         -- the glass, open
  if lx == 12 and y >= 9 and y <= 14 then return sw(STEEL_D, 6) end      -- the handle
  return nil
end

-- the sale case, x 32..63: a sign band over a dark niche, goods on a
-- stepped base
local function saleCase(x, y, z)
  if z > 29 or y > 25 then return nil end
  local lx = x - 32
  if z < 26 then return sw(BLUE_DK, 3) end
  if y >= 20 then
    if z == 29 then
      -- a red sale card on white, one a cell
      local u = lx % 16
      if y == 20 or y == 25 or u == 0 then return sw(BLUE, 4) end
      if y >= 21 and y <= 24 and u >= 2 and u <= 13 and (u % 3 ~= 1) then return sw(RED, 5) end
      return sw(TRIM, 6)
    end
    return sw(BLUE, 4)
  end
  if y >= 10 then
    if z == 29 then return nil end
    if z >= 27 and y <= 13 and lx % 4 ~= 0 then return goods(x, y, z, 3) end
    return sw(DARK, 3)                                                    -- the niche
  end
  if y == 9 then return sw(LAMINATE, 5) end
  if z == 29 and y >= 2 then return sw(BLUE, 4 + (lx % 16 == 0 and -1 or 0)) end
  return sw(BLUE_DK, 3)
end

-- a gondola, x0..x0+31, z 128..159: shelves of goods both sides, a cap
local function gondola(x, y, z, x0)
  local lx, lz = x - x0, z - 128
  if lx < 1 or lx > 30 or lz < 1 or lz > 30 or y > 14 then return nil end
  if y == 14 then return sw(BLUE, 5) end
  if y <= 1 then return sw(BLUE_DK, 3) end
  local face = lz <= 3 or lz >= 28
  if lx <= 2 or lx >= 29 then return sw(BLUE, 4) end                      -- the end panels
  if not face then return sw(BLUE_DK, 2) end
  if (y - 2) % 4 == 0 then return sw(STEEL, 5) end                       -- the shelves
  if (lz == 1 or lz == 30) then return nil end
  return goods(x, y, z, 11)
end

-- the shop counter: blue front, laminate top
local function shopCounter(x, y, z, x0, x1, z0, z1)
  if x < x0 or x > x1 or z < z0 or z > z1 or y > CTOP - 1 then return nil end
  if y >= 8 then return sw(LAMINATE, y == 9 and 5 or 4) end
  if y <= 1 then return sw(DARK, 3) end
  local edge = x == x0 or x == x1 or z == z0 or z == z1
  if edge then
    if y == 7 then return sw(OAK, 5) end
    return sw(BLUE, 4 + (y == 6 and 1 or 0))
  end
  return sw(BLUE_DK, 3)
end

-- the till on the counter, x 18..29, z 82..93
local function till(x, y, z)
  local hy = y - CTOP
  if hy < 0 or hy > 7 or x < 18 or x > 29 or z < 82 or z > 93 then return nil end
  if hy <= 2 then return sw(BEIGE, 3 + hy) end
  if hy <= 6 and z <= 86 and x >= 20 and x <= 27 then
    if x == 21 and hy >= 4 and hy <= 5 then return sw(GLOW, 6) end
    if z == 86 and hy >= 4 then return sw(SCREEN, 4) end
    return sw(BEIGE, 4)
  end
  if hy == 3 and z >= 88 and (x + z) % 2 == 0 then return sw(DARK, 4) end -- the keys
  return nil
end

-- the shelf behind the clerk, x 0..w, z 48..79: goods on its south face
local function backShelf(x, y, z, w)
  if x > w or z < 48 or z > 79 or y > 22 then return nil end
  if y == 22 then return sw(BLUE, 5) end
  if z < 76 then return sw(BLUE_DK, 3) end
  if y <= 1 then return sw(BLUE_DK, 2) end
  if (y - 2) % 5 == 0 then return sw(STEEL, 5) end
  if z == 79 then return nil end
  return goods(x, y, z, 5)
end

local function lobbyRoom(yellow)
  local W2, D2 = 256, 192
  local shelfW = yellow and 15 or 31
  return function(x, y, z)
    -- the side walls outside the box
    if x < 0 then
      if x < -WALL_D or y > sideH(z) or z < 0 or z >= D2 then return nil end
      return wallSkin(z + 5, y)
    end
    if x >= W2 then
      if x > W2 - 1 + WALL_D or z < 48 or z >= D2 or y > sideH(z) then return nil end
      return wallSkin(z + 5, y)
    end
    if z < 0 or z >= D2 then return nil end
    if z < 48 and x >= 160 then
      -- the dark outside; the shop's east wall along its edge
      if x <= 160 + WALL_D - 1 and y <= WALL_H then return wallSkin(z + 5, y) end
      return nil
    end
    -- the shop's north wall, the League's door in it
    if z <= 9 then
      if x >= 128 and x <= 143 then
        local lx = x - 128
        if lx <= 1 or lx >= 14 or y >= 22 then
          if (y >= 22 and y <= 23) or lx == 1 or lx == 14 then return sw(TRIM, 5) end
          return wallSkin(x + 5, y)
        end
        if z <= 5 then return sw(DARK, 2) end
        return (y == 0) and sw(LAMINATE, 3) or nil
      end
      if x >= 64 then return wallSkin(x + 5, y) end
    end
    if z <= 31 and x <= 31 then
      local v = cooler(x, y, z, x < 16 and 0 or 16)
      if v or z <= 9 then return v or wallSkin(x + 5, y) end
    end
    if z <= 31 and x >= 32 and x <= 63 then
      local v = saleCase(x, y, z)
      if v or z <= 9 then return v or wallSkin(x + 5, y) end
    end
    -- the Centre's back wall, its north face toward the shop
    if x >= 64 and z >= 48 and z <= 63 then
      if y > WALL_H then return nil end
      if y == WALL_H then return sw(TRIM, 6) end
      if z == 48 or x == 64 then return wallSkin((z == 48) and x or z, y) end
      return sw(PLASTER, 4)
    end
    -- the shop
    if x < 64 then
      local v = backShelf(x, y, z, shelfW)
        or shopCounter(x, y, z, 16, 31, 72, 103)
        or shopCounter(x, y, z, 0, 15, 96, 111)
        or till(x, y, z)
        or ((z >= 128 and z <= 159) and gondola(x, y, z, x < 32 and 0 or 32) or nil)
      if v or y > 0 then return v end
      return floorAt(x, z)
    end
    -- the Centre, in its own coordinates
    local cx = (x < 192) and (x - 64) or (x - 32)
    local cz = z - 64
    local hit
    if yellow and cz >= 10 and cz <= 17 then hit = television(cx, y, cz) end
    if not hit and cz <= 10 then
      hit = northWall(cx, y, cz, yellow)
      if not hit and cz <= 9 then return nil end
    end
    if not hit then
      for _, p0 in ipairs(PIERS) do
        if cx >= p0 and cx <= p0 + 15 and cz <= 47 then return pier(cx, y, cz, p0) end
      end
      if cz >= 32 and cz <= 47 then
        if cx >= 16 and cx <= 79 then hit = counter(cx, y, cz, 16, 79) or onNurseCounter(cx, y, cz)
        elseif cx >= 96 and cx <= 127 then hit = counter(cx, y, cz, 96, 159) or onLinkCounter(cx, y, cz) end
      elseif cz >= 10 and cz <= 31 then
        if cx >= 16 and cx <= 47 then hit = machine(cx, y, cz, 16, false)
        elseif cx >= 96 and cx <= 127 then hit = machine(cx, y, cz, 96, true)
        elseif cx >= 208 then hit = stairs(cx, y, cz) end
      end
      if not hit and cx >= 208 and cz >= 48 and cz <= 79 then hit = pc(cx, y, cz) end
      if not hit and cz >= 104 and cx >= 160 then hit = plant(cx, y, cz, cx < 192 and 160 or 192) end
    end
    if hit or y > 0 then return hit end
    if z >= 176 and x >= 112 and x <= 143 then
      -- the mat, laid here: left unclaimed, the engine would spread its
      -- tile as the ground under the whole room
      if x == 112 or x == 143 or z == 176 or z == 191 then return sw(STEEL_D, 3) end
      return sw((z % 4 < 2) and STEEL_D or STEEL, 4)
    end
    return floorAt(x, z)
  end
end

local function roomFor(yellow)
  return function(x, y, z)
    if x < 0 or x > W - 1 then                         -- side walls, outside
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y)
    end
    local hit = furniture(x, y, z, yellow)
    if hit or y > 0 or z <= 9 then return hit end
    if z >= 112 and x >= 48 and x <= 79 then return nil end          -- the mat, drawn
    if x <= 15 and z >= 64 and z <= 95 then return nil end            -- the couch's own
    return floorAt(x, z)
  end
end

-- unclaimed by the room: the floor tiles (and their shaded variants by the
-- nurse and the couch), the mat, and the couch, which is its own template
local OPEN = { [1] = true, [11] = true, [17] = true, [27] = true, [54] = true,
               [26] = true, [57] = true, [60] = true, [12] = true, [28] = true,
               [36] = true, [37] = true, [52] = true, [53] = true, [38] = true,
               [39] = true, [42] = true, [43] = true }

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not a Pokemon Centre: " .. tostring(mapId) end
  if t.home == "couch" then
    -- the couch, in room coordinates (its template's corner is tile 0, 8);
    -- the man drawn on it keeps his figure: noFigure off
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      local v = couch(x, y, z + 64)
      if v then return v end
      if y == 0 and x <= 15 then return floorAt(x, z + 64) end
      return nil
    end, {})
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 31, 15
    m.standH, m.noFigure = Kit.SEAT_H, false
    return m
  end
  if Kit.MAPS[mapId] == "lobby" then
    -- Yellow's hangs a television where Red's has the poster (76 at 14, 8)
    local yellow = t.tiles[9] and t.tiles[9][15] == 76
    local m, why = Lib.model(Kit, sp, t, lobbyRoom(yellow), { [0] = true })
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmax = 256, -WALL_D, 255 + WALL_D, 191
    return m
  end
  if Kit.MAPS[mapId] == "hotel" or Kit.MAPS[mapId] == "upstairs" then
    local room = (Kit.MAPS[mapId] == "hotel")
      and hotelRoom(t.tiles[7] and t.tiles[7][1] == 90) or upstairsRoom()
    local m, why = Lib.model(Kit, sp, t, room, OPEN)
    if not m then return nil, why end
    m.W, m.xmax, m.zmax = W, W - 1 + WALL_D, D - 1
    return m
  end
  -- Yellow's plan hangs a television where Red's has its poster (tile 76
  -- at (6, 0))
  local yellow = t.tiles[1] and t.tiles[1][7] == 76
  local m, why = Lib.model(Kit, sp, t, roomFor(yellow), OPEN)
  if not m then return nil, why end
  m.W, m.xmax, m.zmax = W, W - 1 + WALL_D, D - 1
  return m
end

Kit.room = roomFor   -- for a headless preview

return Kit
