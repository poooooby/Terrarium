-- Voxel world mode: Red's room INSIDE (REDS_HOUSE_2F), the first room of
-- the game.
--
-- Same contract as lib/LavenderHomeKit.lua, to the letter: an AUTHORED
-- SHEET (one texel per voxel, tools/reds_room.py) through the spriteQuads
-- path, the room one function of position, a person sixteen voxels (one
-- voxel ~10 cm, assets/docs/shop/ART_DIRECTION.md 2.1), the homes' fixed
-- dollhouse shot (data/camera_shots.lua), so the side walls are cut down
-- toward the camera and nothing tall stands south.
--
-- The plan (16x16 tiles, tools/interior_plan.py; REDS_HOUSE_2F and
-- COPYCATS_HOUSE_2F hash identically) is also the collision, so nothing
-- moves. What every generation since has kept in this room is the PC, the
-- bed and the television with a console in front of it (Bulbapedia,
-- "Player's house"): those are the room. In voxels, x east and z south:
--
--   x  0..15  z  0..31   the PC on its desk           (64/65 32/33 66/67 50/51)
--   x 16..47  z  8..31   the long table               (38-44, 58-60)
--   x 80..95, 112..127   the two windows, north wall  (36/37 over 52/53)
--   x112..127 z 16..31   the stairs down              (left to the profile's
--                                                      stair_down_w)
--   x 48..63  z 64..79   the television                (6/7 over 22/23)
--   x 48..63  z 80..95   the console and its pad       (14/15 over 30/31)
--   x  0..15  z 96..127  the bed, head to the north    (45/46 61/62 63/47)
--   x 96..111 z 96..127  the potted palm               (68/69 8/9 70/71 24/25)
--
-- `v` is picked by MAP ID: 1 Red, 2 the Copycat (same room, her things).
-- Coordinates: x east 0..127, z south 0..127, y up. Side walls stand
-- outside the box. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/reds_room.png", SHEET_W = 8, SHEET_H = 32 }

Kit.MAPS = { REDS_HOUSE_2F = 1, COPYCATS_HOUSE_2F = 2 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt

-- rows of the sheet; tools/reds_room.py is the mirror of this list
local PLASTER, WAINSCOT, OAK, WALNUT, DARK, TRIM, SKY, BLIND,
      BEIGE, SCREEN, GLOW, TVBODY, CONSOLE, BUTTON, SHEET, BLANKET,
      PILLOW, CLAY, SOIL, LEAF, TRUNK, BOOK_R, BOOK_G, BOOK_B,
      BOOK_Y, PAPER, RUG, RUG_EDGE, CABLE, RED, BRASS, LIGHT =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

local sw, hash, sideH = Lib.sw, Lib.hash, Lib.sideH
local WALL_H, WALL_D = Lib.WALL_H, Lib.WALL_D

-- the wall's skin. `u` runs ALONG the wall, whichever wall it is: a dark
-- skirting three courses tall, oak wainscot to a white dado rail at 1 m,
-- plaster above, and a white cornice of three courses at the top -- the
-- bands every home in Kanto is built on (lib/HomeLib.lua).
local function skinFor(v)
  return {
    skirt = { 2, function(u, y) return sw(DARK, y == 2 and 4 or 3) end },
    dado = { 9, function(u, y)
      if u % 12 == 0 then return sw(WAINSCOT, 2) end
      if y == 9 then return sw(WAINSCOT, 6) end        -- the panel's top edge
      return sw(WAINSCOT, 4 + hash(floor(u / 12), 0, 1) % 2)
    end },
    rail = { 10, sw(TRIM, 4) },
    cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
    field = function(u, y)
      -- her wallpaper: a loose polka dot, rows offset (a diagonal rule of
      -- the same density read as candy stripes)
      if v == 2 and y % 4 == 1 and (u + (y % 8 == 1 and 0 or 4)) % 8 == 0 then
        return sw(BLANKET, 7)
      end
      -- plaster: one tone, a sparse speckle (blocks of two tones read as
      -- tiles)
      return sw(PLASTER, hash(u, y, 2) % 13 == 0 and 4 or 5)
    end,
  }
end
local SKIN = { skinFor(1), skinFor(2) }
local SKINFN = { Lib.wallSkin(SKIN[1]), Lib.wallSkin(SKIN[2]) }
local function wallSkin(u, y, v) return SKINFN[v](u, y) end

-- A map of Kanto pinned over the long table (x 22..41, y 14..23): a white
-- border, sea blue, the land green, the route Red is about to walk picked
-- out in red. Not in the Gen 1 drawing; a boy leaving home tomorrow has one.
local function kantoMap(x, y, v)
  if x < 22 or x > 41 or y < 14 or y > 23 then return nil end
  if x == 22 or x == 41 or y == 14 or y == 23 then return sw(TRIM, 6) end
  if v == 2 then                                   -- hers: a poster of a doll
    local d = (x - 31.5) * (x - 31.5) + (y - 19) * (y - 19) * 1.6
    if d <= 10 then return sw(BLANKET, 5) end
    if d <= 16 then return sw(PILLOW, 6) end
    return sw(RUG_EDGE, 6)
  end
  local land = (x >= 25 and x <= 37 and y >= 16 and y <= 22)
               and not (x >= 34 and y <= 17) and not (x <= 26 and y >= 21)
  if land and x == 30 and y >= 16 then return sw(RED, 5) end   -- Route 1 north
  if land then return sw(LEAF, 5 + (x + y) % 2) end
  return sw(SKY, 3)
end

-- A calendar between the two windows (x 99..108, y 12..22): a red header
-- with the month, a grid of days, and one of them ringed -- the day Oak
-- said to come by. Hers is the same calendar, its header the rose of her
-- wallpaper's dots.
local function calendar(x, y, v)
  if x < 99 or x > 108 or y < 12 or y > 22 then return nil end
  if y >= 20 then
    if y == 22 then return nil end
    if y == 21 and x == 103 then return sw(BRASS, 6) end                 -- the pin
    return sw(v == 2 and BLANKET or RED, (y == 21 and 5 or 4) + (v == 2 and 2 or 0))
  end
  if x == 99 or x == 108 or y == 12 then return sw(PAPER, 4) end
  -- the ringed day: second row, a little right of the middle
  if y == 17 and x == 105 then return sw(RED, 5) end
  -- days: a dot every other column on every other course
  if (x - 100) % 2 == 0 and (y - 13) % 2 == 0 then return sw(DARK, 5) end
  return sw(PAPER, 6)
end

-- ------------------------------------------------------- the north wall --
-- Two windows (x 80..95 and 112..127): a real recess with a white frame, a
-- sill, the glass three voxels back, and the blind half let down -- the
-- drawing's slats are the blind, so it stays, but it no longer covers the
-- whole pane: daylight shows under it.
local WINDOWS = { 80, 112 }

local function windowAt(x)
  for _, x0 in ipairs(WINDOWS) do
    if x >= x0 + 1 and x <= x0 + 14 then return x0 end
  end
  return nil
end

local function northWall(x, y, z, v)
  local w0 = windowAt(x)
  if w0 and y >= 11 and y <= 24 then
    local lx = x - w0
    local ring = lx == 1 or lx == 14 or y == 11 or y == 24
    if ring then
      if z <= 10 then return sw(TRIM, 5) end
    elseif z >= 8 then
      if z <= 10 then return nil end                      -- the reveal
    elseif z == 7 then
      -- the blind, one voxel in front of the glass, let down to the middle
      -- of the pane: slats every two courses and its cord down the centre.
      -- (Hung any nearer the room it threw its slats' shadows down over the
      -- sill and the panelling under it.)
      if y >= 17 and (y % 2 == 0 or lx == 7) then return sw(BLIND, y % 2 == 0 and 5 or 2) end
      return nil
    elseif z == 6 then
      -- the mullion and transom, then the glass: brighter toward the top
      if lx == 7 or lx == 8 or y == 18 then return sw(TRIM, 5) end
      return sw(SKY, 4 + floor((y - 11) / 4))
    end
  end
  -- the sill: the dado rail carried on under each window, one voxel proud
  -- like the rail itself (two proud, the sun pass threw it down the
  -- panelling as a row of jagged teeth)
  if w0 and y == 10 and z == 10 then return sw(TRIM, 6) end
  if z <= 9 then return wallSkin(x + 5, y, v) end
  -- skirting, dado rail and cornice stand one voxel proud of the face
  if z == 10 and Lib.proudCourse(SKIN[v], y) and not (w0 and y >= 11 and y <= 24) then
    return wallSkin(x + 5, y, v)
  end
  if z == 10 then return kantoMap(x, y, v) or calendar(x, y, v) end
  return nil
end

-- --------------------------------------------------- the PC on its desk --
-- A desk 7 tall (72 cm) against the wall, the beige tower under it, a CRT
-- monitor on it facing the room, the keyboard in front. The screen is on:
-- the PC is where the game keeps the player's items.
-- Over the desk, clear of the monitor's top (y 15): a wall shelf on two
-- brackets with what a boy keeps up there -- a row of books, a little cup
-- from a school race, a toy figure. Hers: books, a music box, a doll.
local function wallShelf(x, y, z, v)
  if x < 1 or x > 14 or z > 14 or y < 16 or y > 23 then return nil end
  if y <= 17 then                                        -- the brackets
    if (x == 2 or x == 13) and z <= 11 + (y - 16) then return sw(WALNUT, 3) end
    return nil
  end
  if y == 18 then return sw(WALNUT, z == 14 and 3 or 5) end   -- the board
  if z > 13 then return nil end
  -- books, two wide, standing at the back of the board
  if x >= 2 and x <= 7 and z <= 12 then
    local b = floor((x - 2) / 2)
    if y <= 19 + (b * 5 + v) % 3 then return sw(({ BOOK_R, BOOK_B, BOOK_Y })[b + 1], 3 + y % 2) end
    return nil
  end
  if v == 1 then
    -- the cup: a foot, a stem, a bowl and two handles
    local cx, cz = x - 9.5, z - 11.5
    local d = cx * cx + cz * cz
    if y == 19 and d <= 2.5 then return sw(BRASS, 3) end
    if y == 20 and d <= 0.6 then return sw(BRASS, 4) end
    if y >= 21 and y <= 22 and d <= 2.5 then return sw(BRASS, y == 22 and 6 or 5) end
    if y == 22 and (x == 7 or x == 12) and z == 11 then return sw(BRASS, 4) end
    -- the toy figure: a stout little body and a head
    if x == 12 or x == 13 then
      if z >= 11 and z <= 12 and y <= 20 then return sw(LEAF, 4 + x % 2) end
      if z == 11 and y == 21 then return sw(LEAF, 6) end
    end
  else
    -- the music box, its lid propped open
    if x >= 9 and x <= 11 and z >= 10 and z <= 12 and y == 19 then return sw(WALNUT, 4) end
    if x >= 9 and x <= 11 and z == 10 and y <= 21 then return sw(WALNUT, 5) end
    if x == 13 and z == 11 and y <= 21 then return sw(y == 21 and PILLOW or BLANKET, 5) end
  end
  return nil
end

local function pcDesk(x, y, z, v)
  if x > 15 or z < 10 or z > 31 then return nil end
  if y >= 16 then return wallShelf(x, y, z, v) end
  -- the desk: a top slab at y 6 over two side panels; open between them
  if y == 6 and z >= 11 then return sw(OAK, (x + z) % 7 == 0 and 3 or 5) end
  if y <= 5 then
    if z == 11 then return sw(OAK, 2) end                      -- back panel
    if (x <= 1 or x >= 14) and z >= 11 then return sw(OAK, 4) end
    -- the tower, standing under the desk on the east side
    if x >= 9 and x <= 12 and z >= 14 and z <= 28 then
      if z == 28 and y == 3 then return sw(DARK, 3) end         -- the drive slot
      if z == 28 and y == 1 and x == 11 then return sw(GLOW, 7) end  -- power light
      return sw(BEIGE, z == 28 and 6 or 4)
    end
    return nil
  end
  -- the monitor: a deep cabinet, narrowing to the back
  local mx = x - 7.5
  if y >= 7 and y <= 15 then
    local front = z >= 20 and z <= 24
    local back = z >= 13 and z <= 19 and abs(mx) <= 4.5 - (19 - z) * 0.35
    if front and abs(mx) <= 6.5 then
      if z == 24 and y >= 8 and y <= 14 and abs(mx) <= 5 then
        -- the glass, a little lit; one scanline brighter
        return sw(v == 2 and BUTTON or GLOW, y == 12 and 6 or 3)
      end
      if y == 7 then return sw(BEIGE, 3) end                    -- its foot
      return sw(BEIGE, 5)
    end
    if back and y <= 14 then return sw(BEIGE, 4) end
  end
  -- the keyboard, flat on the desk in front of the monitor
  if y == 7 and z >= 26 and z <= 29 and x >= 3 and x <= 12 then
    if z == 26 then return sw(BEIGE, 3) end
    return sw((x + z) % 2 == 0 and BEIGE or PAPER, 5)
  end
  -- the mouse, to its right
  if y == 7 and z >= 26 and z <= 28 and x == 14 then return sw(BEIGE, 6) end
  return nil
end

-- ------------------------------------------------------- the long table --
-- Under nothing but the plain wall, between the PC and the windows: a
-- kid's work table, 7 tall, four legs, and what a kid leaves on one.
local function longTable(x, y, z, v)
  if x < 16 or x > 47 or z < 10 or z > 31 then return nil end
  local tx, tz = x - 16, z - 10                 -- 0..31, 0..21
  if y <= 5 then
    local leg = (tx <= 1 or tx >= 30) and (tz <= 1 or tz >= 20)
    if leg then return sw(OAK, 3) end
    -- the apron under the top, set in one voxel so the top overhangs
    if y == 5 and (tx == 1 or tx == 30 or tz == 1 or tz == 20) then return sw(OAK, 2) end
    return nil
  end
  if y == 6 then return sw(OAK, (tx % 8 == 0) and 3 or 5) end
  -- on it: a stack of books, a cup of pencils, a desk lamp, a small toy
  if tx >= 3 and tx <= 9 and tz >= 4 and tz <= 9 and y <= 6 + 1 + floor(hash(0, 0, v) % 2) + 2 then
    local layer = y - 7
    return sw(({ BOOK_B, BOOK_R, BOOK_Y, BOOK_G })[layer % 4 + 1], 3 + layer)
  end
  if (tx == 13 or tx == 14) and (tz == 6 or tz == 7) and y <= 10 then
    if y == 10 then return sw(({ RED, BOOK_Y, BOOK_B, BOOK_G })[(tx + tz) % 4 + 1], 5) end
    return sw(v == 2 and BUTTON or CABLE, 4)
  end
  -- the desk lamp: a round brass foot by the wall, a thin upright, an arm
  -- reaching out over the table, and a cone shade lit underneath
  local fx, fz = tx - 27, tz - 4
  if y == 7 and fx * fx + fz * fz <= 2.5 then return sw(BRASS, 3) end
  if fx == 0 and fz == 0 and y >= 8 and y <= 14 then return sw(BRASS, 4) end
  if y == 14 and tx >= 24 and tx <= 27 and fz == 0 then return sw(BRASS, 4) end   -- the arm
  local sx, sz = tx - 23, tz - 5
  local sd = sx * sx + sz * sz
  if y == 14 and sd <= 1 then return sw(v == 2 and RED or BRASS, 5) end
  if y == 13 and sd <= 3 then return sw(v == 2 and RED or BRASS, 3) end
  if y == 12 and sd <= 4.5 and sd > 1.5 then return sw(v == 2 and RED or BRASS, 2) end
  if y == 12 and sd <= 1.5 then return sw(LIGHT, 7) end                         -- the bulb
  -- a toy: Red's is a little red-and-white ball, the Copycat's a doll
  local bx, bz = tx - 18, tz - 13
  if v == 1 then
    local d = bx * bx + bz * bz + (y - 8.5) * (y - 8.5)
    if d <= 3.2 then return sw(y >= 9 and RED or SHEET, 5) end
  elseif y <= 11 and abs(bx) <= 1 and abs(bz) <= 1 then
    return sw(y >= 10 and PILLOW or BLANKET, 5)
  end
  return nil
end

-- ----------------------------------------------- the stairwell's railing --
-- The stairs down (x 112..127, z 16..31) are the profile's sunken flight;
-- this kit cannot build below the floor (Buildings.emit stands y >= 0).
-- What an opening in a floor needs is a rail round it: along its south
-- edge (z 32) and down its west edge (x 111), leaving the north-west end
-- open where the flight starts.
local function railing(x, y, z, v)
  if y > 9 then return nil end
  local south = z == 32 and x >= 111 and x <= 127
  local west = x == 111 and z >= 22 and z <= 32
  if not (south or west) then return nil end
  if y == 9 then return sw(WALNUT, 4) end                       -- handrail
  local post = (south and (x == 111 or x == 119 or x == 127))
               or (west and (z == 22 or z == 27))
  if post then return sw(WALNUT, 3) end
  if y >= 2 and ((south and x % 2 == 0) or (west and z % 2 == 0)) then
    return sw(TRIM, 4)                                          -- balusters
  end
  if y == 1 then return sw(WALNUT, 2) end                       -- base rail
  return nil
end

-- ------------------------------------------------------- the television --
-- A CRT on a low cabinet in the middle of the room, facing south, the way
-- the drawing faces the player: the cabinet 5 tall with two doors, the set
-- on it 9 tall with its screen bulging a voxel out of the bezel and its
-- back tapering, as a tube's does.
local function television(x, y, z, v)
  if x < 48 or x > 63 or z < 64 or z > 79 then return nil end
  local tx, tz = x - 48, z - 64                 -- 0..15
  if y <= 4 then
    if tx < 1 or tx > 14 or tz < 3 or tz > 14 then return nil end
    if tz == 14 then
      if tx == 7 or tx == 8 or y == 0 then return sw(WALNUT, 2) end
      if (tx == 6 or tx == 9) and y == 2 then return sw(BRASS, 5) end
      return sw(WALNUT, 4)
    end
    if y == 4 then return sw(WALNUT, 5) end
    return sw(WALNUT, 3)
  end
  if y > 13 then return nil end
  local front = tz >= 10 and tz <= 13 and tx >= 2 and tx <= 13
  local back = tz >= 4 and tz <= 9 and abs(tx - 7.5) <= 3.5 + (tz - 4) * 0.4
  if front then
    if tz == 13 then
      if tx >= 3 and tx <= 12 and y >= 6 and y <= 12 then
        if tx == 12 and (y == 7 or y == 9) then return sw(DARK, 5) end   -- knobs
        if tx <= 10 then return sw(SCREEN, (y == 9 or tx == 6) and 5 or 3) end
      end
      return sw(TVBODY, 4)
    end
    return sw(TVBODY, 3)
  end
  if back and y <= 12 then return sw(TVBODY, 2) end
  -- the screen's bulge, a voxel proud of the bezel
  if tz == 14 and tx >= 4 and tx <= 9 and y >= 7 and y <= 11 then
    return sw(SCREEN, 4)
  end
  return nil
end

-- ---------------------------------------------- the console and its pad --
-- In front of the set: the console flat on the floor, a cartridge in it,
-- a cable to the controller lying a little to the right (where the drawing
-- puts it). Gen 1 draws a Super Nintendo; so does this.
local function console(x, y, z, v)
  if x < 48 or x > 63 or z < 80 or z > 95 then return nil end
  local tx, tz = x - 48, z - 80
  if y > 4 then return nil end
  -- the body
  if tx >= 3 and tx <= 12 and tz >= 2 and tz <= 8 and y <= 1 then
    if y == 1 and tz >= 6 and tx >= 4 and tx <= 6 then return sw(BUTTON, (tx + tz) % 2 == 0 and 4 or 6) end
    return sw(CONSOLE, y == 1 and 5 or 3)
  end
  -- the cartridge, standing in its slot
  if tx >= 7 and tx <= 10 and tz >= 3 and tz <= 4 and y >= 2 and y <= 4 then
    return sw(v == 2 and BLANKET or CABLE, y == 4 and 5 or 3)
  end
  -- the cable, along the floor from the console to the pad
  if y == 0 and tx == 11 and tz >= 9 and tz <= 11 then return sw(CABLE, 3) end
  -- the pad
  if y == 0 and tx >= 9 and tx <= 14 and tz >= 12 and tz <= 14 then
    if tz == 13 and (tx == 10 or tx == 13) then return sw(BUTTON, 5) end
    return sw(CONSOLE, 5)
  end
  return nil
end

-- --------------------------------------------------------------- the bed --
-- One cell wide and two long, head to the north: a headboard 10 tall, the
-- mattress on a frame on four legs, a pillow, and the blanket turned down
-- below it with the sheet showing in the fold.
local function bed(x, y, z, v)
  if x > 15 or z < 96 then return nil end
  local bz = z - 96                             -- 0..31
  if bz <= 2 then                               -- the headboard
    if y > 10 then return nil end
    if y == 10 or x == 0 or x == 15 then return sw(WALNUT, 3) end
    return sw(WALNUT, 5)
  end
  if bz >= 29 then                              -- the footboard
    if y > 6 then return nil end
    if y == 6 then return sw(WALNUT, 3) end
    return sw(WALNUT, 4)
  end
  if y <= 1 then
    local leg = (x <= 1 or x >= 14) and (bz <= 4 or bz >= 27)
    return leg and sw(WALNUT, 2) or nil
  end
  if y == 2 then return sw(WALNUT, 3) end       -- the frame
  if y <= 4 then
    if x == 0 or x == 15 then
      -- the blanket hangs over both sides below the fold
      return bz >= 11 and sw(v == 2 and PILLOW or BLANKET, 3) or nil
    end
    return sw(SHEET, 4)                         -- the mattress
  end
  if y == 5 then
    if bz >= 4 and bz <= 9 and x >= 3 and x <= 12 then return sw(PILLOW, 5) end
    if bz == 10 then return sw(SHEET, 6) end    -- the turned-down sheet
    if bz >= 11 then
      return sw(v == 2 and RUG or BLANKET, (bz % 6 == 0 or x == 1 or x == 14) and 3 or 5)
    end
    return sw(SHEET, 5)
  end
  if y == 6 and bz >= 5 and bz <= 8 and x >= 4 and x <= 11 then return sw(PILLOW, 6) end
  return nil
end

-- --------------------------------------------------------- the plant --
-- A palm in a clay pot: a round pot 6 tall, soil, a trunk to 13, and
-- fronds arching out of its top in six directions and drooping at the tip.
local function plant(x, y, z, v)
  -- the fronds reach past the plant's own cell, as a palm's do; only the
  -- pot is held to it (the cell is the collision, the crown is air)
  if x < 92 or x > 115 or z < 104 then return nil end
  local px, pz = x - 103.5, z - 116.5
  local d2 = px * px + pz * pz
  if y <= 6 then
    local r = 3.6 + y * 0.25
    if d2 > r * r then return nil end
    if y == 6 then return d2 <= (r - 1) * (r - 1) and sw(SOIL, 3) or sw(CLAY, 6) end
    if y == 0 then return sw(CLAY, 2) end
    return sw(CLAY, 4 + hash(floor(px + 8), y, floor(pz + 8)) % 2)
  end
  -- the trunk, ringed where old fronds fell, a voxel off true at the top
  if y <= 17 then
    local tx = px - (y >= 13 and 0.5 or 0)
    if tx * tx + pz * pz <= 0.9 then return sw(TRUNK, (y % 3 == 0) and 2 or 4) end
    -- (not a return: the fronds hang down past the top of the trunk)
  end
  -- nine fronds out of the crown: each rises, arches and droops at the
  -- tip, wide at the rib and narrowing to a point, a lighter rib down its
  -- middle. Their lengths differ so the crown is not a star.
  local r = sqrt(d2)
  if r < 1 then return y <= 20 and sw(LEAF, 2) or nil end
  if r > 11.5 then return nil end
  local a = math.atan2(pz, px)
  -- (seven, narrow: nine wide ones closed into a bush seen from above)
  local N = 7
  local step = 2 * math.pi / N
  local k = floor((a + math.pi) / step + 0.5)
  local fa = k * step - math.pi + (v == 2 and 0.35 or 0)
  local len = 9 + (k * 5) % 3                    -- 9..11
  if r > len then return nil end
  local off = abs(math.sin(a - fa)) * r
  local t = r / len
  local width = 0.4 + 0.8 * math.sin(t * math.pi) * (1 - t * 0.4)
  if off > width then return nil end
  -- each frond lifts out of the crown and then hangs: from the room's eye a
  -- palm is the arch of its fronds over the pot, not the star of them seen
  -- from above
  local function frondY(rr) return 19 + floor(rr * 0.7 - rr * rr * 0.17 * (10 / len)) end
  -- the height here and a step further out: where the frond droops
  -- steeply the voxels between the two are filled, so it has no gaps
  local y1, y2 = frondY(r), frondY(min(len, r + 0.9))
  if y < min(y1, y2) or y > max(y1, y2) then return nil end
  if off < 0.45 then return sw(LEAF, 6) end      -- the rib
  return sw(LEAF, (off > width * 0.6) and 2 or 4)
end

-- -------------------------------------------------------------- the rug --
-- One voxel thick, where the game is played: in front of the set, under
-- the console. Its cells are not claimed, so the floor keeps its own.
local function rug(x, z, v)
  if x < 40 or x > 75 or z < 82 or z > 101 then return nil end
  local bx, bz = min(x - 40, 75 - x), min(z - 82, 101 - z)
  local b = min(bx, bz)
  if b == 0 then return sw(RUG_EDGE, 4) end
  if b == 1 then return sw(v == 2 and BLANKET or RUG, 3) end
  if (x + z) % 8 == 0 then return sw(RUG_EDGE, 5) end
  return sw(v == 2 and BLANKET or RUG, 5 + hash(x, 0, z) % 2)
end

-- ------------------------------------------------------------ the floor --
-- Oak boards running east-west, four voxels wide, ends staggered, laid one
-- voxel thick over the tileset's single floor tile. The stairwell is left
-- open: the profile's stair_down_w builds it.
local function boards(x, z, v)
  if x >= 112 and z >= 16 and z <= 31 then return nil end
  local row = floor(z / 4)
  local run = x + row * 13
  if z % 4 == 0 or run % 28 == 0 then return sw(OAK, 2) end
  return sw(OAK, 4 + hash(floor(run / 28), row, v) % 3)
end

-- ------------------------------------------------------------- the room --

local function furniture(x, y, z, v)
  if z <= 11 then
    local w = northWall(x, y, z, v)
    if w then return w end
    if z <= 9 then return nil end
  end
  if x >= 111 and z >= 22 and z <= 32 then
    local r = railing(x, y, z, v)
    if r then return r end
  end
  if x <= 15 and z <= 31 then return pcDesk(x, y, z, v) end
  if x >= 16 and x <= 47 and z <= 31 then return longTable(x, y, z, v) end
  if z >= 64 and z <= 79 then return television(x, y, z, v) end
  if z >= 80 and z <= 95 then return console(x, y, z, v) end
  if z >= 96 and x <= 15 then return bed(x, y, z, v) end
  if z >= 104 and x >= 92 and x <= 115 then return plant(x, y, z, v) end
  return nil
end

local function roomFor(v)
  return function(x, y, z)
    if x < 0 or x > 127 then                         -- side walls, outside
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y, v)
    end
    local hit = furniture(x, y, z, v)
    if hit or y > 0 or z <= 9 then return hit end
    return rug(x, z, v) or boards(x, z, v)
  end
end

-- unclaimed: the floor, and the stairwell (the profile's stair_down_w
-- stands it; this kit only lays the boards round it)
local OPEN = { [1] = true, [10] = true, [11] = true, [26] = true, [27] = true }

function Kit.model(sp, t, mapId)
  local v = Kit.MAPS[mapId]
  if not v then return nil, "not Red's room: " .. tostring(mapId) end
  return Lib.model(Kit, sp, t, roomFor(v), OPEN)
end

Kit.room = roomFor   -- for a headless preview

return Kit
