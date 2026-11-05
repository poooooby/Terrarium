-- Voxel world mode: the town houses of Kanto INSIDE, beyond Lavender's and
-- Vermilion's three.
--
-- Every town house is the one 16x16 plan (data/voxel_heights.lua,
-- buildings.HOUSE: the bookcases, the window, the picture, the dresser,
-- the table and its four seats, a plant each side of the door). Lavender's
-- three are lib/LavenderHomeKit.lua and Vermilion's three are
-- lib/VermilionHomeKit.lua; this is the same room for every other town,
-- built to their numbers -- the window opening 14 wide, y 9..24, with its
-- glass three voxels back and the sill at y 8 three voxels proud (where the
-- Gen 1 drawing puts it, x 80..95: see WIN_X0 below), the
-- curtains on the z 10/11 planes, the sconces either side of the table's
-- axis, the cases sixteen wide and twenty-one deep, the table on legs set in
-- three from its corners, a plant either side of the door -- and from the
-- shared parts in lib/HomeLib.lua.
--
-- The plan is the collision, so nothing moves. What changes is who lives
-- there: each map below has a RESIDENT, written first, and every slot gets
-- a thing that belongs to that person. Each town has its own sheet
-- (tools/town_homes.py), all with the same rows, so the room function
-- reads any of them and the house takes its town's colour.
--
--   BLUES_HOUSE (Pallet)  Daisy, Blue's sister, who keeps house while he is
--                         out to be the best: white panelling, a blue stripe,
--                         his trophies and his photo on her shelves, tea and
--                         biscuits on the table (the Town Map she gives you
--                         lies there as the game's own object), her dresser
--                         with a mirror and a brush, flowers by the door.
--   VIRIDIAN_NICKNAME_HOUSE  a father and his little girl and Speary, the
--                         Spearow she named: moss-grey boards and cream
--                         plaster, the kitchen dresser full of china, her
--                         picture books under his, a perch on top for the
--                         bird, bread and milk on the table and her crayon
--                         drawing of Speary, a rag rug, a fern and a rubber
--                         plant by the door.
--   ROUTE_2_TRADE_HOUSE   a man who trades: walnut panelling, parcels tied
--                         for posting, a ledger open on the table, the
--                         scales, a box of trade cards, a wall map with the
--                         routes pinned in red thread, crates by the door.
--
-- Coordinates: x east 0..127, z south 0..127, y up. Side walls stand
-- outside the box. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/home_pallet.png", SHEET_W = 8, SHEET_H = 32,
              SEAT_H = Lib.SEAT_H }

-- map id -> the resident (an index into HOMES below)
Kit.MAPS = { BLUES_HOUSE = 1, VIRIDIAN_NICKNAME_HOUSE = 2, ROUTE_2_TRADE_HOUSE = 3,
             PEWTER_NIDORAN_HOUSE = 4, PEWTER_SPEECH_HOUSE = 5,
             CERULEAN_TRADE_HOUSE = 6, CERULEAN_MELANIES_HOUSE = 7, DAYCARE = 8,
             CERULEAN_TRASHED_HOUSE = 9,
             -- the south: Mr. Psychic his own; the rest by trade -- the
             -- fisherman's brother a seaside home, the Pidgey post a trader's,
             -- the girl with the bird that flies a nickname house, Bill's
             -- grandpa an old collector's
             MR_PSYCHICS_HOUSE = 10, ROUTE_12_SUPER_ROD_HOUSE = 6, SAFFRON_PIDGEY_HOUSE = 3,
             ROUTE_16_FLY_HOUSE = 2, FUCHSIA_BILLS_GRANDPAS_HOUSE = 5 }

local TOWN = { [1] = "pallet", [2] = "viridian", [3] = "viridian", [4] = "pewter", [5] = "pewter",
               [6] = "cerulean", [7] = "cerulean", [8] = "cerulean", [9] = "cerulean",
               [10] = "saffron" }
-- the map's town, where it differs from its resident's
local TOWN_OF = { ROUTE_12_SUPER_ROD_HOUSE = "fuchsia", SAFFRON_PIDGEY_HOUSE = "saffron",
                  ROUTE_16_FLY_HOUSE = "celadon", FUCHSIA_BILLS_GRANDPAS_HOUSE = "fuchsia" }
function Kit.sheetFor(mapId)
  local v = Kit.MAPS[mapId]
  return v and ("assets/buildings/home_" .. (TOWN_OF[mapId] or TOWN[v]) .. ".png") or nil
end

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, hash, sideH = Lib.sw, Lib.hash, Lib.sideH
local WALL_H, WALL_D = Lib.WALL_H, Lib.WALL_D

-- rows of every town's sheet; tools/town_homes.py is the mirror of this list
local PLASTER, PLASTER_B, WAINS, OAK, WALNUT, DARK, TRIM, SKY,
      CURT, RUG_A, RUG_B, RUG_EDGE, CUSH_A, CUSH_B, CUSH_C, CUSH_D,
      BOOK_R, BOOK_G, BOOK_B, BOOK_Y, PAPER, CHINA, CLAY, LEAF,
      FLOWER, BRASS, IRON, LIGHT, SOIL, ACC_1, ACC_2, ACC_3 =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

-- ============================================================ the shell ==
-- The parts every house has, in the Lavender kit's numbers. Each resident
-- (HOMES, below) hands in what is theirs.
--
-- WHERE the window is: the Gen 1 drawing hangs the framed landscape at x
-- 48..63 (tiles 45/46 over 61/62: a mountain in a frame) and the two-pane
-- window at x 80..95 (36 over 52). lib/LavenderHomeKit.lua and
-- lib/VermilionHomeKit.lua read 45/46 as the window and put it at 48..63;
-- here the drawing is followed, and their window's numbers are moved over
-- to x 80..95 as they are.
local WIN_X0, WIN_X1 = 81, 94          -- the opening's frame ring
local PIC_X0, PIC_X1 = 48, 63          -- the picture's frame

-- the window in the north wall: opening x 81..94, y 9..24, the frame ring a
-- voxel proud, the reveal z 7..10 carved, the glass at z 6 with its cross
-- bar, lighter toward the top; the sill y 8, x 80..95, out to z 12
local function window(h)
  return Lib.northWindow({
    x0 = WIN_X0, x1 = WIN_X1, y0 = 9, y1 = 24,
    frame = h.frame, bar = h.frame,
    mullion = function(lx, y) return lx == 6 or lx == 7 or y == 16 or y == 17 end,
    glass = function(lx, y) return sw(SKY, 6 - floor((24 - y) / 4)) end,
    sill = { 8, 12, h.sill },
  })
end

-- tied-back curtains: two drops five wide either side of the window, y
-- 7..24, the tie-back at y 14, the outer column cut away below it, folds
-- in alternating shades, a brass rod at y 25 on the z 11 plane
local CUR_A0, CUR_A1 = WIN_X0 - 5, WIN_X1 + 5      -- 76 .. 99
local function tiedCurtains(x, y, z, row)
  if y == 25 and z == 11 and x >= CUR_A0 and x <= CUR_A1 then return sw(BRASS, 4) end
  if y >= 7 and y <= 24 and ((x >= CUR_A0 and x < WIN_X0) or (x > WIN_X1 and x <= CUR_A1)) then
    if y == 14 then return sw(TRIM, 4) end
    if y < 14 and (x == CUR_A0 or x == CUR_A1) then return nil end
    return sw(row, 3 + x % 2 * 3)
  end
  return nil
end

-- the two sconces either side of the table's axis
local function sconce(x, y, lit)
  if (x == 38 or x == 39 or x == 104 or x == 105) and y >= 16 and y <= 21 then
    if y == 16 then return sw(IRON, 3) end
    if y == 21 then return sw(BRASS, 3) end
    return lit and sw(LIGHT, 5) or sw(IRON, 5)
  end
  return nil
end

local function northWall(x, y, z, h)
  local handled, tex = h.win(x, y, z)
  if handled then return tex end
  if z == 10 or z == 11 then
    local c = h.curtains and h.curtains(x, y, z)
    if c then return c end
    local s = sconce(x, y, h.sconcesLit ~= false)
    if s then return s end
    if z == 10 and x >= PIC_X0 and x <= PIC_X1 and y >= 12 and y <= 23 then
      -- the picture, in its own frame coordinates: lx 0..15, y 12..23
      local p = h.picture(x - PIC_X0, y)
      if p then return p end
    end
    -- skirting, rail and cornice stand one voxel proud of the face
    if z == 10 and Lib.proudCourse(h.skin, y) then return h.wallSkin(x + 5, y) end
    return nil
  end
  if z <= 9 then return h.wallSkin(x + 5, y) end
  return nil
end

-- An open case: the Lavender kit's, as it is (sides, top and back in the
-- wood's shade 3, a plinth set back two, a shelf every six, the front three
-- voxels clear); `fill(ux, s, hy, dz)` stocks shelf s at local height hy.
local function case(ux, y, dz, H, wood, fill)
  if y > H then return nil end
  if ux == 0 or ux == 15 or y == H or dz <= 1 then return sw(wood, 3) end
  if y <= 1 then return dz <= 18 and sw(DARK, 2) or nil end
  if (y - 2) % 6 == 0 then return sw(wood, 5) end
  if dz >= 18 then return nil end
  return fill(ux, floor((y - 3) / 6), (y - 3) % 6, dz)
end

-- books two wide, height and colour by hash; every gapMod-th one missing
local function books(salt, unit, gapMod)
  return function(ux, s, hy, dz)
    if dz < 4 or dz > 16 then return nil end
    local bid = floor((ux - 1) / 2) + s * 7 + unit * 31
    local hh = hash(bid, s, salt)
    if gapMod and hh % gapMod == 0 then return nil end
    if hy >= 3 + hh % 3 then return nil end
    return sw(BOOK_R + hh % 4, hh)
  end
end

-- a plant pot whose radius grows with height (a flared tub), soil dark
-- inside the rim at y 7
local function pot(px, y, pz)
  local r = 3 + floor(y / 3)
  local d = px * px + pz * pz
  if d > r * r + 1 then return nil end
  if y == 7 and d <= (r - 1) * (r - 1) then return sw(SOIL, 2) end
  return sw(CLAY, y == 6 and 6 or 2 + hash(px, 0, pz) % 3)
end

-- ======================================================== the residents ==

-- ------------------------------------------------------------------ Daisy
local daisy = {}

daisy.skin = {
  skirt = { 2, function(u, y) return sw(WALNUT, 3) end },
  -- panelling painted white: a stile every ten, the top rail lighter, a
  -- shadow line at its foot (VermilionHomeKit's panelled dado)
  dado = { 11, function(u, y)
    if y == 11 then return sw(WAINS, 6) end
    if y == 3 then return sw(WAINS, 1) end
    if u % 10 == 0 then return sw(WAINS, 3) end
    if u % 10 == 1 then return sw(WAINS, 6) end
    return sw(WAINS, 4)
  end },
  rail = { 12, sw(TRIM, 5) },
  cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
  -- a two-tone stripe, pale blue and white
  field = function(u, y) return sw(u % 6 < 3 and PLASTER_B or PLASTER, 5) end,
}
daisy.wallSkin = Lib.wallSkin(daisy.skin)
daisy.frame, daisy.sill = sw(TRIM, 4), sw(TRIM, 6)
daisy.win = window(daisy)
daisy.curtains = function(x, y, z) return tiedCurtains(x, y, z, CURT) end

-- Pallet seen from the sea: the sky, the water, the shore, two houses with
-- red roofs among the trees (lx 0..15 across the frame)
function daisy.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(WALNUT, 4) end
  if y >= 19 then return sw(SKY, 5 + (y >= 21 and 1 or 0)) end
  local house = (lx >= 4 and lx <= 6) or (lx >= 10 and lx <= 12)
  if house and y == 18 then return sw(BOOK_R, 4) end            -- roofs
  if house and y == 17 then return sw(TRIM, 4) end              -- walls
  if y >= 16 then return sw(LEAF, 3 + (lx % 3 == 0 and 1 or 0)) end
  if y == 15 then return sw(PAPER, 4) end                       -- the beach
  return sw(ACC_1, 3 + (lx + y) % 2)                            -- the sea
end

-- the west cases (x 0..31, z 10..30, H 20): books on the left; on the
-- right Blue's trophies on the middle shelf -- three cups, the tallest in
-- the middle -- his photo above, books below
local function trophies(ux, s, hy, dz)
  if s == 1 then
    for i, c in ipairs({ { 3.5, 3 }, { 7.5, 4 }, { 11.5, 2 } }) do
      local dx, dd = ux - c[1], dz - 11.5
      local d = dx * dx + dd * dd
      local top = c[2]
      if hy == 0 and d <= 2.6 then return sw(WALNUT, 3) end        -- the plinth
      if hy >= 1 and hy < top and d <= 0.6 then return sw(ACC_3, 4) end
      if hy == top and d <= 2.6 then return sw(ACC_3, 6) end       -- the bowl
      if hy == top and (abs(dx) == 1.5 or abs(dx) == 2.5) and abs(dd) <= 0.5 then
        return sw(ACC_3, 5)                                         -- handles
      end
    end
    return nil
  end
  if s == 2 and ux >= 4 and ux <= 10 then
    -- his photo in a frame, leaning back on its stand
    if dz == 14 and hy <= 4 then
      if ux == 4 or ux == 10 or hy == 0 or hy == 4 then return sw(WALNUT, 5) end
      if hy == 1 then return sw(CUSH_D, 4) end                      -- a blue shirt
      if hy == 2 and ux >= 6 and ux <= 8 then return sw(PAPER, 3) end  -- a face
      if hy == 3 and ux >= 6 and ux <= 8 then return sw(WALNUT, 3) end -- spiky hair
      return sw(SKY, 5)
    end
    return nil
  end
  return books(11, 1, 7)(ux, s, hy, dz)
end

function daisy.westCases(x, y, z)
  local unit, ux, dz = floor(x / 16), x % 16, z - 10
  return case(ux, y, dz, 20, OAK, unit == 0 and books(11, 0, 9) or trophies)
end

-- the east case (x 112..127): her dresser, three drawers with brass pulls,
-- a little mirror on a stand on top, a vase of flowers, a hairbrush
function daisy.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  if y <= 12 then
    if dz == 20 then
      if (ux == 4 or ux == 11) and (y == 2 or y == 6 or y == 10) then return sw(BRASS, 4) end
      if y == 4 or y == 8 or y == 0 then return sw(DARK, 4) end
    end
    if dz > 20 then return nil end
    return sw(OAK, y == 12 and 6 or 3)
  end
  -- the mirror: a walnut oval, the glass sky-grey, at the back
  if dz >= 4 and dz <= 5 and ux >= 2 and ux <= 8 and y <= 22 then
    local mx, my = ux - 5, y - 18
    local e = mx * mx / 9 + my * my / 16
    if y == 13 and ux >= 4 and ux <= 6 then return sw(WALNUT, 3) end   -- its foot
    if e <= 1 then
      if dz == 4 or e > 0.6 then return sw(WALNUT, 4) end
      return sw(SKY, 4 + (my > 0 and 2 or 0))
    end
    return nil
  end
  -- the vase and its flowers
  local vx, vz = ux - 11, dz - 9
  local vd = vx * vx + vz * vz
  if y <= 16 and vd <= 1.6 then return sw(CHINA, y) end
  if y >= 17 and y <= 19 and vd == 0 then return sw(LEAF, 3) end
  if y >= 19 and y <= 21 and vd <= 4.5 and hash(ux, y, dz) % 2 == 0 then
    return sw(FLOWER, ux + y)
  end
  -- the hairbrush, lying in front
  if y == 13 and dz >= 15 and dz <= 16 and ux >= 6 and ux <= 12 then
    return sw(ux >= 10 and WALNUT or PAPER, ux >= 10 and 4 or 5)
  end
  return nil
end

-- the table (32 x 32 at x 48..79, z 48..79): the Lavender kit's tea table --
-- legs set in three, an apron, the top's corners rounded, a runner over both
-- ends -- with her teapot, two cups (hers and a guest's) and biscuits
function daisy.table(tx, y, tz)
  if y <= 5 then
    local lx = (tx >= 3 and tx <= 5) or (tx >= 26 and tx <= 28)
    local lz = (tz >= 3 and tz <= 5) or (tz >= 26 and tz <= 28)
    return (lx and lz) and sw(OAK, 2) or nil
  end
  local runner = tz >= 13 and tz <= 18
  if y <= 7 then
    if runner and (tx == 0 or tx == 31) then return sw(CURT, 4) end
    if tx >= 2 and tx <= 29 and tz >= 2 and tz <= 29
       and (tx == 2 or tx == 29 or tz == 2 or tz == 29) then return sw(OAK, 1) end
    return nil
  end
  if y <= 9 then
    if Lib.cornerCut(tx, tz, 32, 32, 4) then return nil end
    if runner and (tx == 0 or tx == 31) then return sw(CURT, 4) end
    if y == 9 and runner then return sw((tz == 13 or tz == 18) and TRIM or CURT, 5) end
    return sw(OAK, tz % 4 == 0 and 2 or 5)
  end
  -- the teapot, on the runner in the middle
  local cx, cz = tx - 15.5, tz - 15.5
  local d = cx * cx + cz * cz
  if y >= 10 and y <= 13 then
    if d <= 6.5 then return sw(CHINA, y - 6) end
    if (tz == 15 or tz == 16) and (tx == 18 or tx == 19) and y >= 11 and y <= 12 then
      return sw(CHINA, 6)                                           -- the handle
    end
    if tz == 15 and (tx == 11 or tx == 12) and y >= 11 then return sw(CHINA, 3) end   -- spout
  elseif y == 14 then
    if d <= 2.6 then return sw(ACC_1, 5) end                       -- the lid
  elseif y == 15 and d <= 0.6 then
    return sw(BRASS, 5)
  end
  -- two cups on saucers
  for _, c in ipairs({ { 7.5, 7.5 }, { 23.5, 23.5 } }) do
    local ux, uz = tx - c[1], tz - c[2]
    local ud = ux * ux + uz * uz
    if y == 10 and ud <= 4.5 then return sw(CHINA, 6) end
    if y == 11 and ud <= 1.6 then return sw(ud <= 0.6 and SOIL or CHINA, 4) end
  end
  -- a plate of biscuits by the guest's place (the Town Map she gives you
  -- is the game's own object on this table: it is not built twice)
  local bx, bz = tx - 10.5, tz - 23.5
  local bd = bx * bx + bz * bz
  if y == 10 and bd <= 6.5 then return sw(CHINA, 6) end
  if y == 11 and bd <= 4 and hash(tx, 1, tz) % 2 == 0 then return sw(BOOK_Y, 3 + tx % 2) end
  return nil
end

-- round stools, a cushion on each in a different colour; seat top y 7
local CUSHIONS = { CUSH_A, CUSH_B, CUSH_C, CUSH_D }
function daisy.stool(dx, dz, y, idx)
  local d = dx * dx + dz * dz
  if y <= 4 then return d <= 3 and sw(OAK, 2) or nil end
  if y == 5 then return d <= 27 and sw(OAK, 5) or nil end
  if y <= 7 then return d <= 21 and sw(CUSHIONS[idx], (y == 7 and 4 or 3) + hash(floor(dx + 9), y, floor(dz + 9)) % 2) or nil end
  return nil
end

-- either side of the door: a flowering bush on the left, a leafy one with
-- white flowers on the right, both in clay
function daisy.corner(px, y, pz, east)
  if y <= 7 then return pot(px, y, pz) end
  local d = px * px + pz * pz
  if y <= 10 then return d <= 1 and sw(WALNUT, 3) or nil end
  if east then
    local e = d / 36 + (y - 14) * (y - 14) / 30
    if e > 1 or hash(px, y, pz) % 8 == 0 then return nil end
    return (y >= 15 and hash(px, y, pz) % 3 == 0) and sw(TRIM, px) or sw(LEAF, hash(px, y, pz))
  end
  local e = d / 49 + (y - 17) * (y - 17) / 81
  if e <= 1 then
    if hash(px, y, pz) % 8 == 0 then return nil end
    return (y >= 20 and hash(px, y, pz) % 3 == 0) and sw(FLOWER, px + y) or sw(LEAF, hash(px, y, pz))
  end
  return nil
end

-- the round rug, concentric rings of blue and cream inside a white edge
function daisy.rug(x, z)
  local d = (x - 63.5) * (x - 63.5) + (z - 63.5) * (z - 63.5)
  if d > 38 * 38 then return nil end
  if d > 36 * 36 then return sw(TRIM, 3) end
  return sw(floor(d ^ 0.5 / 6) % 2 == 0 and RUG_A or RUG_B, 4 + hash(x, 0, z) % 2)
end

-- boards four wide, butt joints every 24 staggered 11 (Mr. Fuji's)
daisy.boards = Lib.boards(4, 24, 11, sw(OAK, 3), function(i, row)
  return sw(OAK, 5 + hash(i, row, 1) % 3)
end)

-- ----------------------------------------------- the Viridian father's
-- A father and his little girl, and Speary, the Spearow she named herself.
local speary = {}

speary.skin = {
  skirt = { 2, function(u, y) return sw(WALNUT, 3) end },
  -- moss-grey boards five wide to the rail, a shadow line between them
  dado = { 10, function(u, y)
    if u % 5 == 0 then return sw(WAINS, 1) end
    if y == 10 then return sw(WAINS, 6) end
    return sw(WAINS, 3 + floor(u / 5) % 3)
  end },
  rail = { 11, sw(OAK, 5) },
  cornice = { 26, function(u, y) return sw(OAK, ({ 3, 4, 6 })[y - 25] or 6) end },
  -- cream plaster in patches (the homes' block hash)
  field = function(u, y) return sw(PLASTER, 4 + hash(floor(u / 6), floor(y / 4), 5) % 3) end,
}
speary.wallSkin = Lib.wallSkin(speary.skin)
speary.frame, speary.sill = sw(OAK, 4), sw(OAK, 6)
speary.win = window(speary)
speary.curtains = function(x, y, z) return tiedCurtains(x, y, z, CURT) end

-- the drawing's own picture: a mountain under the sky, in an oak frame
function speary.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(OAK, 3) end
  local peak = 21 - abs(lx - 8) * 0.9
  if y <= peak and y >= 14 then
    return sw((y >= peak - 1 and lx >= 6 and lx <= 10) and TRIM or WAINS, 3 + (lx % 2))
  end
  if y <= 14 then return sw(LEAF, 3 + lx % 2) end             -- the forest at its foot
  return sw(SKY, 5)
end

-- the west cases: the kitchen dresser in two, as the drawing has them --
-- plates stood on edge on the top shelf, cups and jars on the next, bowls
-- stacked on the lowest
-- (stocked to the front lip, as the developer's shelves are: set back in
-- the case the china sat in the shelf's shadow and read as an empty case)
local function dishes(ux, s, hy, dz)
  if dz < 4 or dz > 17 then return nil end
  if s == 2 then
    -- plates stood on edge against a rail, rims in the curtain green
    if dz == 16 or dz == 17 then
      local px = (ux - 1) % 4
      local r2 = (px - 1.5) ^ 2 + (hy - 2) ^ 2
      if r2 <= 3.3 then return sw(r2 > 1.8 and CURT or CHINA, 5 + dz % 2) end
    end
    if dz == 15 and hy == 0 then return sw(OAK, 4) end              -- the plate rail
    return nil
  end
  if s == 1 then
    local slot = (ux - 1) % 5
    if slot <= 1 and dz >= 14 and dz <= 16 and hy <= 2 then         -- a cup
      if hy == 2 and slot == 1 and dz == 15 then return sw(CURT, 4) end   -- its rim
      return sw(CHINA, 6 - (slot == 1 and 1 or 0))
    end
    if slot == 3 and dz >= 12 and dz <= 16 and hy <= 4 then         -- a jar of honey
      if hy == 4 then return sw(BRASS, 5) end
      if hy == 0 then return sw(CHINA, 5) end
      return sw(BOOK_Y, 3 + hy % 2)
    end
    return nil
  end
  local cx = (ux - 1) % 5
  if cx <= 2 and dz >= 12 and dz <= 17 and hy <= 1 then
    return sw(hy == 1 and CURT or CHINA, 5 + hy)
  end
  return nil
end

function speary.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, OAK, dishes)
end

-- the east case: her picture books low down, her father's books above, and
-- on its top a perch for Speary -- a branch on a stand, a seed dish
local function picturebooks(ux, s, hy, dz)
  if s == 0 then
    if dz < 6 or dz > 16 then return nil end
    local bid = floor((ux - 1) / 3)
    if hy >= 3 + hash(bid, 1, 7) % 2 then return nil end
    return sw(({ CUSH_A, CUSH_B, CUSH_D, CUSH_C })[bid % 4 + 1], 4 + ux % 2)
  end
  return books(23, 2, 8)(ux, s, hy, dz)
end

function speary.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  if y <= 20 then return case(ux, y, dz, 20, OAK, picturebooks) end
  -- on top: the perch -- a foot, a post, a crossbar of branch
  local hy = y - 21
  if hy == 0 and ux >= 4 and ux <= 9 and dz >= 8 and dz <= 13 then return sw(WALNUT, 3) end
  if ux == 6 and dz == 10 and hy >= 1 and hy <= 6 then return sw(WALNUT, 4) end
  if hy == 6 and dz == 10 and ux >= 2 and ux <= 11 then return sw(WALNUT, 5) end
  -- the seed dish
  if hy == 1 and ux >= 10 and ux <= 12 and dz >= 14 and dz <= 16 then
    return sw((ux == 11 and dz == 15) and BOOK_Y or CHINA, 4)
  end
  return nil
end

-- the family table: the tea table's frame; on it a breadboard with a loaf,
-- a milk jug, two bowls, and the girl's drawing of a bird in crayon
function speary.table(tx, y, tz)
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
    if Lib.cornerCut(tx, tz, 32, 32, 3) then return nil end
    return sw(OAK, tz % 4 == 0 and 3 or 5)
  end
  -- the breadboard and its loaf
  if y == 10 and tx >= 11 and tx <= 20 and tz >= 11 and tz <= 17 then return sw(WALNUT, 5) end
  if y >= 11 and y <= 13 then
    local lx, lz = tx - 15.5, tz - 14
    local e = lx * lx / 12 + lz * lz / 4 + (y - 11) * (y - 11) / 6
    if e <= 1 then return sw(ACC_1, y == 13 and 6 or 4 + (tx % 3 == 0 and 1 or 0)) end
  end
  -- the milk jug
  local jx, jz = tx - 23.5, tz - 9.5
  local jd = jx * jx + jz * jz
  if y >= 10 and y <= 14 and jd <= 3.2 then
    if y == 14 then return jd <= 1.6 and sw(ACC_3, 6) or sw(CHINA, 5) end
    return sw(CHINA, 4 + (y % 2))
  end
  if y >= 11 and y <= 13 and tx == 25 and (tz == 9 or tz == 10) then return sw(CHINA, 5) end
  -- two bowls
  for _, c in ipairs({ { 7.5, 22.5 }, { 24.5, 22.5 } }) do
    local bx, bz = tx - c[1], tz - c[2]
    local bd = bx * bx + bz * bz
    if y == 10 and bd <= 3.5 then return sw(CHINA, 5) end
    if y == 11 and bd <= 4.5 and bd > 1.5 then return sw(CHINA, 6) end
    if y == 11 and bd <= 1.5 then return sw(BOOK_Y, 4) end          -- porridge
  end
  -- the drawing: a sheet of paper, a russet bird on it in crayon
  if y == 10 and tx >= 4 and tx <= 11 and tz >= 6 and tz <= 12 then
    local bird = (tz == 8 and tx >= 6 and tx <= 9) or (tz == 9 and tx >= 5 and tx <= 8)
                 or (tz == 7 and tx == 9)
    if bird then return sw(ACC_2, 4) end
    if tz == 10 and (tx == 6 or tx == 8) then return sw(BOOK_Y, 4) end   -- its feet
    return sw(PAPER, 6)
  end
  return nil
end

-- square stools with a cushion each, seat top y 7
local SQ_CUSHIONS = { CUSH_A, CUSH_C, CUSH_B, CUSH_D }
function speary.stool(dx, dz, y, idx)
  local ax, az = abs(dx), abs(dz)
  if ax > 5.5 or az > 5.5 then return nil end
  if y <= 4 then
    if ax >= 4 and az >= 4 then return sw(WALNUT, 3) end
    if y == 2 and (ax >= 4 or az >= 4) then return sw(WALNUT, 2) end
    return nil
  end
  if y == 5 then return sw(OAK, 4) end
  if ax > 4.5 or az > 4.5 then return nil end
  if y <= 7 then return sw(SQ_CUSHIONS[idx], (y == 7 and 5 or 3)) end
  return nil
end

-- either side of the door: a fern in a clay pot, and a rubber plant
function speary.corner(px, y, pz, east)
  if y <= 7 then return pot(px, y, pz) end
  local d = px * px + pz * pz
  if east then
    -- the rubber plant: a stem with broad leaves stepping up it
    if d <= 1 and y <= 26 then return sw(WALNUT, 3) end
    for i = 0, 5 do
      local ly = 11 + i * 3
      local side = (i % 2 == 0) and 1 or -1
      local lx, lz = px - side * 3, pz - ((i % 3) - 1) * 2
      if y >= ly and y <= ly + 1 and lx * lx / 6 + lz * lz / 2 <= 1 then
        return sw(LEAF, 2 + (y - ly) * 2)
      end
    end
    return nil
  end
  -- the fern: fronds arching out of the pot
  local r = sqrt(d)
  local fy = 9 + floor(r * 0.9 - r * r * 0.09)
  if r <= 7.5 and y >= fy and y <= fy + 1 and hash(floor(px + 9), y, floor(pz + 9)) % 4 ~= 0 then
    return sw(LEAF, 3 + (y - fy) * 2)
  end
  if r <= 1.2 and y <= 12 then return sw(LEAF, 2) end
  return nil
end

-- an oval rag rug: stripes three rows deep cycling through the cushions'
-- colours, a rope edge (VermilionHomeKit's rag rug)
local RAG = { RUG_A, RUG_B, CUSH_C, CUSH_D, CUSH_B }
function speary.rug(x, z)
  local dx, dz = (x - 63.5) / 46, (z - 63.5) / 30
  local e = dx * dx + dz * dz
  if e > 1 then return nil end
  if e > 0.9 then return sw(RUG_EDGE, 3 + (x + z) % 2) end
  return sw(RAG[floor(z / 3) % #RAG + 1], 4 + hash(x, 0, z) % 2)
end

-- honey boards running north-south, five wide, joints every 26 staggered 11
function speary.boards(x, z)
  local col = floor(x / 5)
  local run = z + col * 11
  if x % 5 == 0 or run % 26 == 0 then return sw(OAK, 3) end
  return sw(OAK, 5 + hash(floor(run / 26), col, 2) % 3)
end

-- ------------------------------------------------- the Route 2 trader's
-- A man who trades: what he sends and what he gets back pass through his
-- hands, and the house is full of the business of it -- a ledger, parcels
-- tied for posting, a wall map with the routes pinned, the scales.
local trader = {}

trader.skin = {
  skirt = { 2, function(u, y) return sw(WALNUT, 3) end },
  -- walnut panelling to the rail, a stile every twelve
  dado = { 12, function(u, y)
    if u % 12 == 0 or y == 3 or y == 12 then return sw(WALNUT, 2) end
    return sw(WALNUT, u % 12 < 2 and 3 or 5)
  end },
  rail = { 13, sw(BRASS, 4) },
  cornice = { 26, function(u, y) return sw(WALNUT, ({ 3, 4, 5 })[y - 25] or 5) end },
  -- warm plaster with a small diamond paper
  field = function(u, y)
    if (u + y) % 8 == 0 and (u - y) % 8 == 0 then return sw(PLASTER_B, 3) end
    return sw(PLASTER, 4 + hash(floor(u / 7), floor(y / 5), 6) % 2)
  end,
}
trader.wallSkin = Lib.wallSkin(trader.skin)
trader.frame, trader.sill = sw(WALNUT, 4), sw(OAK, 6)
trader.win = window(trader)
trader.curtains = function(x, y, z) return tiedCurtains(x, y, z, RUG_A) end

-- the picture: a map of the region, the trade routes pinned in red thread
function trader.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(WALNUT, 4) end
  local land = (lx >= 3 and lx <= 12 and y >= 14 and y <= 21) and not (lx >= 10 and y <= 15)
  local pin = (lx == 5 and y == 19) or (lx == 9 and y == 17) or (lx == 11 and y == 20)
  if pin then return sw(BOOK_R, 6) end
  if y == 19 and lx >= 5 and lx <= 7 then return sw(BOOK_R, 4) end       -- thread
  if y == 18 and lx >= 7 and lx <= 9 then return sw(BOOK_R, 4) end
  if land then return sw(PAPER, 4 + (lx + y) % 2) end
  return sw(SKY, 3)
end

-- the west cases: parcels on two shelves, wrapped in paper and tied; the
-- trade ledgers on the third
local function parcels(ux, s, hy, dz)
  if s == 1 then return books(37, 1, 6)(ux, s, hy, dz) end
  local slot = floor((ux - 1) / 5)
  local px = (ux - 1) % 5
  if px == 4 or dz < 6 or dz > 16 then return nil end
  local hh = 2 + (slot + s) % 3
  if hy >= hh then return nil end
  if px == 2 or hy == hh - 1 and dz == 11 then return sw(BOOK_R, 4) end    -- the string
  return sw(PAPER, 3 + (slot % 2))
end
function trader.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, WALNUT, parcels)
end

-- the east case: a counter-height cupboard, the scales on it -- two pans,
-- one down -- and a box of trade cards
function trader.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  if y <= 10 then
    if dz > 20 then return nil end
    if dz == 20 then
      if ux == 7 or ux == 8 then return sw(WALNUT, 2) end
      if y == 6 and (ux == 6 or ux == 9) then return sw(BRASS, 5) end
    end
    return sw(WALNUT, y == 10 and 5 or 3)
  end
  local hy = y - 11
  -- the scales: a pillar, a beam, two pans at different heights
  if ux == 7 and dz == 10 and hy <= 6 then return sw(BRASS, 4) end
  if hy == 6 and dz == 10 and ux >= 2 and ux <= 12 then return sw(BRASS, 5) end
  local function pan(cx, py) return hy == py and (ux - cx) ^ 2 + (dz - 10) ^ 2 <= 3 end
  if pan(3, 2) or pan(11, 4) then return sw(BRASS, 6) end
  if ux == 3 and dz == 10 and hy >= 3 and hy <= 5 then return sw(IRON, 4) end
  if ux == 11 and dz == 10 and hy == 5 then return sw(IRON, 4) end
  -- the card box, in front
  if dz >= 15 and dz <= 18 and ux >= 4 and ux <= 10 and hy <= 1 then
    if hy == 1 and ux >= 5 and ux <= 9 and dz >= 16 and dz <= 17 then
      return sw(({ CUSH_A, CUSH_B, CUSH_C, CUSH_D })[ux % 4 + 1], 5)          -- the cards
    end
    return sw(OAK, 4)
  end
  return nil
end

-- the table: a ledger open, a pen, a tied parcel, a cup of tea
function trader.table(tx, y, tz)
  if y <= 5 then
    local lx = (tx >= 3 and tx <= 5) or (tx >= 26 and tx <= 28)
    local lz = (tz >= 3 and tz <= 5) or (tz >= 26 and tz <= 28)
    return (lx and lz) and sw(WALNUT, 3) or nil
  end
  if y <= 7 then
    if tx >= 2 and tx <= 29 and tz >= 2 and tz <= 29
       and (tx == 2 or tx == 29 or tz == 2 or tz == 29) then return sw(WALNUT, 2) end
    return nil
  end
  if y <= 9 then
    if Lib.cornerCut(tx, tz, 32, 32, 2) then return nil end
    return sw(WALNUT, tz % 4 == 0 and 3 or 5)
  end
  if y == 10 then
    if tx >= 6 and tx <= 19 and tz >= 10 and tz <= 20 then                    -- the ledger
      if tx == 12 or tx == 13 then return sw(PAPER, 2) end
      if (tz - 10) % 2 == 1 and tx ~= 6 and tx ~= 19 then return sw(PAPER, 3) end
      return sw(PAPER, 6)
    end
    if tz == 22 and tx >= 8 and tx <= 15 then return sw(DARK, 4) end         -- the pen
  end
  -- the parcel
  if tx >= 21 and tx <= 27 and tz >= 8 and tz <= 13 and y <= 12 then
    if tx == 24 or tz == 10 then return sw(BOOK_R, 4) end
    return sw(PAPER, 4)
  end
  -- the cup
  local cx, cz = tx - 24.5, tz - 22.5
  local cd = cx * cx + cz * cz
  if y == 10 and cd <= 4.5 then return sw(CHINA, 6) end
  if y == 11 and cd <= 1.6 then return sw(cd <= 0.6 and SOIL or CHINA, 4) end
  return nil
end

-- chairs, a walnut frame, a cushion, a back on the side away from the table
function trader.stool(dx, dz, y, idx)
  local ax, az = abs(dx), abs(dz)
  if ax > 5.5 or az > 5.5 then return nil end
  if y <= 4 then return (ax >= 4.5 and az >= 4.5) and sw(WALNUT, 3) or nil end
  if y == 5 then return sw(WALNUT, 4) end
  if y <= 7 then return sw(RUG_A, y == 7 and 4 or 3) end
  local outer = (idx % 2 == 1) and dx <= -4.5 or (idx % 2 == 0 and dx >= 4.5)
  if outer and y <= 13 then
    if az >= 4.5 or y == 13 then return sw(WALNUT, 3) end
    return sw(RUG_A, 3)
  end
  return nil
end

-- by the door: a box planter with a bay tree, and a stack of crates
function trader.corner(px, y, pz, east)
  if east then
    if abs(px) <= 5 and abs(pz) <= 5 then
      local layer = floor(y / 6)
      if y < 12 then
        if y % 6 == 5 or abs(px) == 5 or abs(pz) == 5 then return sw(WALNUT, 3) end
        return sw(OAK, 4)
      end
      if y < 18 and abs(px) <= 3 and abs(pz) <= 3 then
        if y % 6 == 5 or abs(px) == 3 or abs(pz) == 3 then return sw(WALNUT, 3) end
        return sw(OAK, 5)
      end
    end
    return nil
  end
  if abs(px) <= 5 and abs(pz) <= 5 and y <= 7 then
    if y == 7 and abs(px) <= 4 and abs(pz) <= 4 then return sw(SOIL, 2) end
    return sw((y == 1 or y == 6) and BRASS or WALNUT, 3)
  end
  local d = px * px + pz * pz
  if d <= 1 and y <= 12 then return sw(WALNUT, 3) end
  local e = d / 30 + (y - 17) * (y - 17) / 36
  if e <= 1 and hash(px, y, pz) % 7 ~= 0 then return sw(LEAF, 2 + hash(px, y, pz) % 3) end
  return nil
end

-- a rectangular rug, a border and a lattice (VermilionHomeKit's carpet)
function trader.rug(x, z)
  if x < 20 or x > 107 or z < 38 or z > 89 then return nil end
  local b = min(x - 20, 107 - x, z - 38, 89 - z)
  if b <= 2 then return sw(b == 1 and BRASS or RUG_EDGE, 3) end
  if abs(x - 63.5) + abs(z - 63.5) <= 7 then return sw(RUG_B, 4) end
  if (abs(x - 63.5) + abs(z - 63.5)) % 12 < 2 then return sw(RUG_EDGE, 3) end
  return sw(RUG_A, 3 + hash(x, 0, z) % 2)
end

-- parquet, blocks of eight turned against each other (the Name Rater's)
function trader.boards(x, z)
  local along = (floor(x / 8) + floor(z / 8)) % 2 == 0
  local strip = along and z % 8 or x % 8
  if strip == 0 then return sw(WALNUT, 2) end
  return sw(OAK, 3 + hash(floor(x / 8), floor(strip / 2), floor(z / 8)) % 3)
end

-- ------------------------------------------------- Pewter: the Nidoran's
-- A boy and his pet Nidoran, and his mother: limewashed stone, a slate
-- dado, the boy's things on the shelves, the Nidoran's basket by the door.
local nido = {}
local function stoneSkin(v)
  return {
    skirt = { 2, function(u, y) return sw(DARK, 3) end },
    -- a dado of slate-grey boards
    dado = { 10, function(u, y)
      if u % 6 == 0 then return sw(WAINS, 2) end
      if y == 10 then return sw(WAINS, 6) end
      return sw(WAINS, 4 + floor(u / 6) % 2)
    end },
    rail = { 11, sw(OAK, 5) },
    cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
    -- limewashed stone: coursed blocks, the joints a shade under
    field = function(u, y)
      local course = floor((y - 12) / 4)
      if (y - 12) % 4 == 3 or (u + course % 2 * 5) % 10 == 0 then return sw(PLASTER_B, 4) end
      return sw(PLASTER, 4 + hash(floor((u + course % 2 * 5) / 10), course, v) % 3)
    end,
  }
end
nido.skin = stoneSkin(7)
nido.wallSkin = Lib.wallSkin(nido.skin)
nido.frame, nido.sill = sw(OAK, 4), sw(OAK, 6)
nido.win = window(nido)
nido.curtains = function(x, y, z) return tiedCurtains(x, y, z, CURT) end

-- the drawing's picture: a mountain -- Mt. Moon over the city's roofs
function nido.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(OAK, 3) end
  local peak = 21 - abs(lx - 7) * 1.0
  if y <= peak and y >= 15 then
    if y >= peak - 1 and lx >= 6 and lx <= 8 then return sw(TRIM, 6) end     -- snow
    return sw(ACC_1, 3 + (lx % 2))
  end
  if y <= 14 then return sw((lx % 3 == 0) and RUG_A or PLASTER_B, 4) end    -- the roofs
  return sw(SKY, 5)
end

-- the boy's shelves: comics, toy figures, a ball, books
local function boyShelf(ux, s, hy, dz)
  if s == 1 then
    -- three figures and a ball
    for i, c in ipairs({ 3, 7, 11 }) do
      local dx, dd = abs(ux - c), abs(dz - 11)
      if dx <= 1 and dd <= 1 and hy <= 3 and not (hy == 3 and dx + dd > 0) then
        return sw(({ CUSH_A, CUSH_C, CUSH_D })[i], hy == 3 and 6 or 4)
      end
    end
    return nil
  end
  if s == 2 then
    local dx, dd = ux - 7.5, dz - 11
    if dx * dx + dd * dd + (hy - 2) ^ 2 <= 4.5 then return sw(hy >= 2 and CUSH_A or TRIM, 5) end
    return nil
  end
  return books(41, s, 6)(ux, s, hy, dz)
end
function nido.westCases(x, y, z)
  local unit, ux, dz = floor(x / 16), x % 16, z - 10
  return case(ux, y, dz, 20, OAK, unit == 0 and books(42, 0, 7) or boyShelf)
end
-- the east case: a chest of drawers, a lamp and a framed photo of the boy
-- and his Nidoran on it
function nido.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  if y <= 12 then
    if dz > 20 then return nil end
    if dz == 20 then
      if (ux == 4 or ux == 11) and (y == 2 or y == 6 or y == 10) then return sw(BRASS, 4) end
      if y == 4 or y == 8 or y == 0 then return sw(DARK, 4) end
    end
    return sw(OAK, y == 12 and 6 or 3)
  end
  -- the lamp
  local lx, lz = ux - 4, dz - 8
  local ld = lx * lx + lz * lz
  if y == 13 and ld <= 2.5 then return sw(BRASS, 3) end
  if y <= 18 and ld == 0 then return sw(BRASS, 5) end
  if y >= 19 and y <= 21 and ld <= (22 - y) * 1.6 then return sw(CUSH_B, 5) end
  -- the photo
  if dz == 6 and ux >= 8 and ux <= 13 and y <= 19 then
    if ux == 8 or ux == 13 or y == 13 or y == 19 then return sw(WALNUT, 3) end
    if y <= 15 and ux >= 10 and ux <= 11 then return sw(ACC_2, 5) end            -- the Nidoran
    return sw(SKY, 5)
  end
  return nil
end

-- the table: a bowl of fruit, two plates, a toy left on it
function nido.table(tx, y, tz)
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
    if Lib.cornerCut(tx, tz, 32, 32, 3) then return nil end
    return sw(OAK, tz % 4 == 0 and 3 or 5)
  end
  -- the fruit bowl
  local cx, cz = tx - 15.5, tz - 15.5
  local d = cx * cx + cz * cz
  if y == 10 and d <= 10 then return sw(CHINA, 5) end
  if y == 11 and d <= 12 and d > 6 then return sw(CHINA, 6) end
  if y >= 11 and y <= 12 and d <= 6 and hash(tx, y, tz) % 3 ~= 0 then
    return sw(({ CUSH_A, CUSH_B, LEAF })[hash(tx, 0, tz) % 3 + 1], 5)
  end
  for _, c in ipairs({ { 7.5, 7.5 }, { 23.5, 23.5 } }) do
    local px, pz = tx - c[1], tz - c[2]
    if y == 10 and px * px + pz * pz <= 6 then return sw(CHINA, 6) end
  end
  if y == 10 and tx >= 22 and tx <= 24 and tz >= 6 and tz <= 8 then return sw(CUSH_D, 5) end   -- a toy car
  return nil
end
nido.stool = daisy.stool

-- by the door: the Nidoran's basket with its blanket, and a potted plant
function nido.corner(px, y, pz, east)
  if east then
    local d = px * px + pz * pz
    if y <= 3 and d <= 30 and d > 18 then return sw(OAK, 3 + y % 2) end          -- the basket's rim
    if y <= 1 and d <= 18 then return sw(OAK, 2) end
    if y == 2 and d <= 18 then return sw(ACC_2, 4 + hash(px, 0, pz) % 2) end     -- the blanket
    -- its bowl, in front
    local bx, bz = px - 1, pz + 8
    local bd = bx * bx + bz * bz
    if y <= 1 and bd <= 4 then return sw(bd <= 1.5 and y == 1 and SOIL or CUSH_D, 4) end
    return nil
  end
  return daisy.corner(px, y, pz, false)
end
nido.rug = speary.rug
nido.boards = daisy.boards

-- ---------------------------------------------- Pewter: the old miner's
-- The old man who talks about the mountain and the rocks, and his grandson:
-- his specimens on the shelves, a pickaxe and lamp, maps of the tunnels.
local miner = {}
miner.skin = stoneSkin(8)
miner.wallSkin = Lib.wallSkin(miner.skin)
miner.frame, miner.sill = sw(WALNUT, 4), sw(OAK, 6)
miner.win = window(miner)
miner.curtains = function(x, y, z) return tiedCurtains(x, y, z, RUG_B) end

-- the picture: a section through the mountain, the tunnels in it
function miner.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(WALNUT, 4) end
  if y >= 21 then return sw(SKY, 5) end
  local tunnel = (y == 16 and lx >= 3 and lx <= 11) or (y == 19 and lx >= 6 and lx <= 13)
                 or (lx == 6 and y >= 16 and y <= 19)
  if tunnel then return sw(DARK, 4) end
  return sw(ACC_1, 3 + floor((y - 13) / 3) % 2)
end

-- the specimen shelves: stones of every colour, set out with labels
local function specimens(ux, s, hy, dz)
  if dz < 8 or dz > 16 then return nil end
  local slot = floor((ux - 1) / 4)
  local px = (ux - 1) % 4
  if px == 3 then return nil end
  local sx, sz = px - 1, dz - 12
  local r = 1.3 + (hash(slot, s, 3) % 3) * 0.3
  if sx * sx + sz * sz + (hy - 1) ^ 2 <= r * r then
    return sw(({ ACC_1, CUSH_D, ACC_3, CUSH_C, PLASTER_B })[hash(slot, s, 4) % 5 + 1], 3 + hy)
  end
  if hy == 0 and dz == 16 and px == 1 then return sw(PAPER, 6) end              -- a label
  return nil
end
function miner.westCases(x, y, z)
  local unit, ux, dz = floor(x / 16), x % 16, z - 10
  return case(ux, y, dz, 20, WALNUT, unit == 0 and specimens or books(43, 1, 5))
end
-- the east case: a tool chest, his pickaxe leaning on it, a miner's lamp on top
function miner.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  if y <= 10 then
    if dz > 20 then return nil end
    if dz == 20 and (y == 5 or ux == 7 or ux == 8) then return sw(IRON, 4) end
    return sw(WALNUT, y == 10 and 5 or 3)
  end
  -- the lamp: a brass body, a glass, a hook
  local lx, lz = ux - 7.5, dz - 10
  local ld = lx * lx + lz * lz
  if y >= 11 and y <= 13 and ld <= 4 then return sw(BRASS, 4 + (y - 11)) end
  if y >= 14 and y <= 16 and ld <= 2 then return sw(y == 15 and LIGHT or BRASS, 5) end
  if y == 17 and ld <= 0.6 then return sw(IRON, 3) end
  return nil
end

-- the table: a tunnel map spread out, a lump of ore on it as a weight, a mug
function miner.table(tx, y, tz)
  if y <= 9 then return speary.table(tx, y, tz) end
  if y == 10 and tx >= 4 and tx <= 21 and tz >= 6 and tz <= 22 then
    local line = (tz == 12 and tx >= 6 and tx <= 18) or (tx == 10 and tz >= 12 and tz <= 20)
                 or (tz == 18 and tx >= 10 and tx <= 19)
    if line then return sw(BOOK_R, 4) end
    return sw(PAPER, 5 + (tx + tz) % 2)
  end
  local ox, oz = tx - 18, tz - 9
  if y >= 11 and y <= 12 and ox * ox + oz * oz <= 2.5 then return sw(ACC_1, 3 + y % 2) end
  local mx, mz = tx - 25.5, tz - 20.5
  local md = mx * mx + mz * mz
  if y >= 10 and y <= 12 and md <= 1.8 then return sw(md <= 0.6 and y == 12 and SOIL or CHINA, 4) end
  return nil
end
miner.stool = trader.stool
-- by the door: a pickaxe and a shovel leaning in a corner, and a rubber plant
function miner.corner(px, y, pz, east)
  if east then
    -- the handles lean against the east wall: the pick's head at the top
    if pz >= -1 and pz <= 0 then
      local hx = 2 + floor(y / 6)
      if px == hx and y <= 18 then return sw(OAK, 4) end
      if y == 18 and px >= hx - 3 and px <= hx + 2 then return sw(IRON, 4) end
      local sx = -1 + floor(y / 7)
      if px == sx and y <= 15 and pz == 0 then return sw(OAK, 3) end
      if y <= 3 and px >= -3 and px <= 0 and pz == -1 then return sw(IRON, 5) end   -- the blade
    end
    return nil
  end
  return speary.corner(px, y, pz, true)
end
miner.rug = trader.rug
miner.boards = speary.boards

-- ------------------------------------------- Cerulean: the trade house
-- A household on the water, where a Pokemon is traded across the table:
-- white boards to the rail, pale blue plaster, shells and a ship in a bottle
-- on the shelves, a fishing rod in the corner by the door.
local seaside = {}
seaside.skin = {
  skirt = { 2, function(u, y) return sw(RUG_A, 3) end },
  -- white matchboard to the rail
  dado = { 11, function(u, y)
    if u % 4 == 0 then return sw(WAINS, 3) end
    return sw(WAINS, 5)
  end },
  rail = { 12, sw(RUG_A, 4) },
  cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
  field = function(u, y) return sw(PLASTER, 4 + hash(floor(u / 8), floor(y / 5), 9) % 2) end,
}
seaside.wallSkin = Lib.wallSkin(seaside.skin)
seaside.frame, seaside.sill = sw(TRIM, 5), sw(TRIM, 6)
seaside.win = window(seaside)
seaside.curtains = function(x, y, z) return tiedCurtains(x, y, z, CURT) end

-- the picture: a cape running out into the sea, a little house on it (the
-- one up the coast where the man who studies Pokemon lives)
function seaside.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(WALNUT, 3) end
  if y >= 19 then return sw(SKY, 5) end
  local land = y <= 17 - floor(max(0, lx - 4) * 0.6)
  if lx >= 4 and lx <= 6 and y >= 17 and y <= 18 then return sw(CUSH_A, 5) end     -- the house
  if land then return sw(LEAF, 3 + (lx + y) % 2) end
  return sw(ACC_1, 3 + (y % 2))
end

-- shells on the shelves, of every shape and colour, and books
local function shells(ux, s, hy, dz)
  if s == 0 then return books(51, 0, 5)(ux, s, hy, dz) end
  if dz < 8 or dz > 15 then return nil end
  local slot = floor((ux - 1) / 4)
  local sx, sz = (ux - 1) % 4 - 1.5, dz - 11.5
  local r = 1.4 + (hash(slot, s, 7) % 2) * 0.4
  if sx * sx + sz * sz <= r * r and hy <= (hash(slot, s, 8) % 2) + 1 then
    return sw(({ ACC_2, PAPER, CUSH_B, CUSH_A })[hash(slot, s, 9) % 4 + 1], 4 + hy)
  end
  return nil
end
function seaside.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, OAK, shells)
end
-- the east case: a sea chest, a ship in a bottle on it
function seaside.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  if y <= 9 then
    if dz > 20 or dz < 4 then return nil end
    if (dz == 20 or dz == 4) and (ux == 2 or ux == 13) then return sw(BRASS, 4) end   -- the corners
    if y == 6 then return sw(IRON, 3) end                                          -- a band
    return sw(WALNUT, y == 9 and 5 or 3)
  end
  -- the bottle lying on a cradle, the ship inside it
  local bx, by = ux - 7.5, y - 12
  local bz = dz - 12
  if y == 10 and (ux == 4 or ux == 11) and abs(bz) <= 1 then return sw(OAK, 4) end
  if ux >= 2 and ux <= 13 and bz * bz + by * by <= 5.5 then
    if ux >= 13 then return sw(CHINA, 3) end                                       -- the cork
    if abs(bz) <= 0.5 and by <= 0 and ux >= 5 and ux <= 10 then return sw(WALNUT, 4) end -- the hull
    if abs(bz) <= 0.5 and by >= 1 and (ux == 6 or ux == 9) then return sw(TRIM, 6) end  -- sails
    if bz * bz + by * by >= 3.5 then return sw(SKY, 6) end                          -- the glass
  end
  return nil
end
-- the table: a teapot, two cups, a bowl of shells
function seaside.table(tx, y, tz)
  if y <= 9 then return speary.table(tx, y, tz) end
  local px, pz = tx - 12, tz - 14
  local pd = px * px + pz * pz
  if y >= 10 and y <= 13 and pd <= 6 - max(0, y - 12) * 3 then return sw(CHINA, 5 + (y == 13 and 1 or 0)) end
  if y == 12 and tx >= 15 and tx <= 16 and tz == 14 then return sw(CHINA, 4) end   -- the spout
  for _, c in ipairs({ { 21.5, 9.5 }, { 21.5, 21.5 } }) do
    local cx, cz = tx - c[1], tz - c[2]
    if y >= 10 and y <= 11 and cx * cx + cz * cz <= 1.6 then return sw(CURT, 4 + y % 2) end
  end
  local sx, sz = tx - 8.5, tz - 23.5
  local sd = sx * sx + sz * sz
  if y == 10 and sd <= 7 then return sw(CHINA, 6) end
  if y == 11 and sd <= 4 and hash(tx, 1, tz) % 2 == 0 then return sw(ACC_2, 5) end
  return nil
end
seaside.stool = daisy.stool
-- by the door: a fishing rod and a net in the east corner, a plant west
function seaside.corner(px, y, pz, east)
  if east then
    if pz == 0 and px == 2 + floor(y / 8) and y <= 24 then return sw(OAK, 4) end    -- the rod
    if y >= 2 and y <= 10 and pz == -1 and px >= -3 and px <= 1 and (px + y) % 2 == 0 then
      return sw(RUG_B, 3)                                                          -- the net
    end
    if y <= 2 and px >= -2 and px <= 1 and pz >= -3 and pz <= -2 then return sw(WALNUT, 3) end  -- a creel
    return nil
  end
  return daisy.corner(px, y, pz, false)
end
seaside.rug = speary.rug
seaside.boards = daisy.boards

-- --------------------------------------------- Cerulean: Melanie's (Yellow)
-- The girl who looks after Pokemon nobody wanted: soft cushions and beds
-- for them all round the room, a first-aid box, a basket of berries, a
-- watering can for the plants; her Bulbasaur's own bed by the door.
local melanie = {}
melanie.skin = seaside.skin
melanie.wallSkin = seaside.wallSkin
melanie.frame, melanie.sill = seaside.frame, seaside.sill
melanie.win = seaside.win
melanie.curtains = function(x, y, z) return tiedCurtains(x, y, z, FLOWER) end

-- the picture: a meadow of flowers under a blue sky
function melanie.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(OAK, 4) end
  if y >= 18 then return sw(SKY, 5 + (y >= 21 and 1 or 0)) end
  if (lx * 3 + y * 5) % 7 == 0 then return sw(({ FLOWER, CUSH_B, TRIM })[(lx + y) % 3 + 1], 5) end
  return sw(LEAF, 3 + (lx % 2))
end

-- the shelves: folded blankets, jars of medicine, a first-aid box
local function blankets(ux, s, hy, dz)
  if dz < 6 or dz > 16 then return nil end
  if s == 2 then
    -- the first-aid box: white, a red cross
    if ux >= 3 and ux <= 12 and hy <= 3 and dz >= 8 and dz <= 15 then
      if dz == 15 and hy >= 1 and hy <= 2 and ((ux >= 7 and ux <= 8) or (hy == 1 or hy == 2) and ux >= 6 and ux <= 9 and hy == 2) then
        return sw(CUSH_A, 5)
      end
      return sw(TRIM, 5)
    end
    return nil
  end
  if s == 1 then
    local slot = floor((ux - 1) / 3)
    local jx = (ux - 1) % 3
    if jx == 2 or hy > 3 then return nil end
    if hy == 3 then return sw(CHINA, 6) end
    return sw(({ CUSH_C, CUSH_B, CUSH_D, FLOWER })[slot % 4 + 1], 4)
  end
  -- folded blankets, stacked
  if hy >= 4 then return nil end
  return sw(({ CUSH_D, FLOWER, CUSH_B, CUSH_C })[(floor((ux - 1) / 7) + hy) % 4 + 1], 4 + (dz == 16 and 1 or 0))
end
function melanie.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, OAK, blankets)
end
-- the east side: a low cushion bed for the little ones, a watering can by it
function melanie.eastCase(x, y, z)
  local ux, dz = x - 112, z - 10
  local cx, cz = ux - 7.5, dz - 11
  local d = (cx / 7) ^ 2 + (cz / 8) ^ 2
  if y <= 4 and d <= 1 then
    if y <= 1 then return sw(OAK, 3) end
    if d >= 0.62 then return sw(FLOWER, 4 + y % 2) end                             -- the bolster
    if y <= 3 then return sw(CUSH_D, 5) end
    return nil
  end
  return nil
end
-- the table: a basket of berries, a bowl of water, a ribbon
function melanie.table(tx, y, tz)
  if y <= 9 then return speary.table(tx, y, tz) end
  local bx, bz = tx - 12, tz - 12
  local bd = bx * bx + bz * bz
  if y >= 10 and y <= 12 and bd <= 20 and bd >= 12 then return sw(OAK, 3 + y % 2) end   -- the basket
  if y >= 10 and y <= 12 and bd < 12 then
    if y == 12 and hash(tx, 2, tz) % 3 == 0 then return nil end
    return sw(({ CUSH_A, CUSH_D, CUSH_B })[hash(tx, 3, tz) % 3 + 1], 4 + (y - 10))
  end
  if y == 14 and abs(bz) <= 0 and abs(bx) <= 4 then return sw(OAK, 4) end              -- its handle
  if y == 13 and abs(bx) == 4 and abs(bz) <= 0 then return sw(OAK, 4) end
  local wx, wz = tx - 22.5, tz - 22.5
  local wd = wx * wx + wz * wz
  if y == 10 and wd <= 6 then return sw(CHINA, 5) end
  if y == 11 and wd <= 6 and wd > 3 then return sw(CHINA, 6) end
  if y == 11 and wd <= 3 then return sw(SKY, 6) end
  return nil
end
melanie.stool = daisy.stool
-- by the door: the Bulbasaur's bed east (a round basket, a leafy blanket),
-- a potted plant west
function melanie.corner(px, y, pz, east)
  if east then
    local d = px * px + pz * pz
    if y <= 3 and d <= 30 and d > 18 then return sw(OAK, 3 + y % 2) end
    if y <= 1 and d <= 18 then return sw(OAK, 2) end
    if y == 2 and d <= 18 then return sw(ACC_3, 4 + hash(px, 0, pz) % 2) end
    return nil
  end
  return daisy.corner(px, y, pz, false)
end
melanie.rug = speary.rug
melanie.boards = daisy.boards

-- --------------------------------------------- Route 5: the Day Care
-- The old man who minds a Pokemon while you travel: cushioned beds along
-- the shelves' foot, a ledger of whose is whose, a ball and food bowls.
local daycare = {}
daycare.skin = trader.skin
daycare.wallSkin = trader.wallSkin
daycare.frame, daycare.sill = trader.frame, trader.sill
daycare.win = trader.win
daycare.curtains = function(x, y, z) return tiedCurtains(x, y, z, CUSH_C) end
-- the picture: a Pokemon egg (no Nintendo design: a plain spotted oval)
function daycare.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(WALNUT, 4) end
  local ex, ey = lx - 7.5, (y - 17.5) * 1.25
  if ex * ex + ey * ey <= 14 then
    if (lx == 6 and y == 19) or (lx == 9 and y == 16) or (lx == 8 and y == 20) then return sw(CUSH_C, 4) end
    return sw(PAPER, 5)
  end
  return sw(RUG_B, 3)
end
-- the shelves: food tins, a ledger, a ball
local function careShelf(ux, s, hy, dz)
  if s == 2 then return books(61, 2, 4)(ux, s, hy, dz) end
  if dz < 7 or dz > 15 then return nil end
  local slot = floor((ux - 1) / 4)
  local px = (ux - 1) % 4
  if px == 3 or hy > 3 then return nil end
  if hy == 3 then return sw(IRON, 4) end
  return sw(({ CUSH_A, CUSH_B, CUSH_C })[(slot + s) % 3 + 1], 4)
end
function daycare.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, WALNUT, careShelf)
end
daycare.eastCase = melanie.eastCase
-- the table: the ledger open, a pen, a pot of tea
function daycare.table(tx, y, tz)
  if y <= 9 then return speary.table(tx, y, tz) end
  if y == 10 and tx >= 6 and tx <= 19 and tz >= 9 and tz <= 20 then
    if tx == 12 or tx == 13 then return sw(WALNUT, 3) end
    if (tz - 9) % 2 == 1 and tx ~= 6 and tx ~= 19 then return sw(PAPER, 3) end
    return sw(PAPER, 6)
  end
  if y == 11 and tz == 14 and tx >= 15 and tx <= 18 then return sw(DARK, 4) end    -- the pen
  local px, pz = tx - 24, tz - 22
  if y >= 10 and y <= 13 and px * px + pz * pz <= 6 - max(0, y - 12) * 3 then return sw(CLAY, 4) end
  return nil
end
daycare.stool = trader.stool
-- by the door: food bowls and a ball east, a plant west
function daycare.corner(px, y, pz, east)
  if east then
    for i, c in ipairs({ { -1, -2 }, { 3, -2 } }) do
      local bx, bz = px - c[1], pz - c[2]
      local bd = bx * bx + bz * bz
      if y <= 1 and bd <= 3.5 then return sw(bd <= 1.5 and y == 1 and SOIL or ({ CUSH_D, CUSH_A })[i], 4) end
    end
    local bx, bz = px - 1, pz + 6
    if bx * bx + bz * bz + (y - 2) ^ 2 <= 5 then return sw(y >= 2 and CUSH_A or TRIM, 5) end  -- a ball
    return nil
  end
  return daisy.corner(px, y, pz, false)
end
daycare.rug = trader.rug
daycare.boards = trader.boards

-- --------------------------------------- Cerulean: the house that was robbed
-- A Rocket broke in through the back wall and left the same way: the hole
-- where the drawing hangs the picture (the house's back door, the game's
-- warp), the plaster cracked round it, his footprints across the floor
-- (the drawing's 55) to it, books thrown off the shelves (34), lumps of
-- the wall (40), two stools knocked over (28/29 over 68/69), something
-- spilled across the table (80..83), the plant by the door tipped over
-- (42..44 over 12/13/53/56). The window is a cell further west (x 64..79)
-- and has no curtains left; the east case is gone. Read off the plan
-- (`h.plan`, set by Kit.model) so the debris lies where it is drawn.
local trashed = {}
trashed.skin = seaside.skin
trashed.wallSkin = seaside.wallSkin
trashed.frame, trashed.sill = sw(TRIM, 4), sw(TRIM, 5)
trashed.win = Lib.northWindow({
  x0 = 64, x1 = 79, y0 = 9, y1 = 24, frame = trashed.frame, bar = trashed.frame,
  mullion = function(lx, y) return lx == 6 or lx == 7 or y == 16 or y == 17 end,
  -- one pane broken: dark, a jagged edge
  glass = function(lx, y)
    if lx >= 8 and y <= 15 and (lx + y) % 3 ~= 0 then return sw(DARK, 3) end
    return sw(SKY, 6 - floor((24 - y) / 4))
  end,
  sill = { 8, 12, trashed.sill },
})
trashed.curtains = nil
trashed.sconcesLit = false
function trashed.picture() return nil end
-- the shelves: half emptied, books lying on their sides
local function ransacked(ux, s, hy, dz)
  local b = books(71, s, 2)(ux, s, hy, dz)
  if b then return b end
  if hy == 0 and dz >= 6 and dz <= 14 and hash(ux, s, 72) % 3 == 0 then return sw(BOOK_R + ux % 4, 3) end
  return nil
end
function trashed.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, OAK, ransacked)
end
function trashed.eastCase() return nil end
function trashed.table(tx, y, tz)
  if y <= 9 then return speary.table(tx, y, tz) end
  -- a vase lying on its side, the water and flowers spilled out of it
  local vx, vz = tx - 7, tz - 22
  if y >= 10 and y <= 12 and abs(vz) <= 1.5 and vx >= -3 and vx <= 3 then return sw(CHINA, 4 + (y - 10)) end
  if y == 10 and tx >= 11 and tx <= 20 and tz >= 18 and tz <= 26 and hash(tx, 0, tz) % 3 == 0 then
    return sw((tx + tz) % 2 == 0 and FLOWER or LEAF, 4)
  end
  if y == 10 and tx >= 10 and tx <= 18 and tz >= 20 and tz <= 25 then return sw(SKY, 4) end   -- the water
  return nil
end
trashed.stool = daisy.stool
trashed.corner = function(px, y, pz, east)
  if east then return nil end                     -- the tipped plant is read off the plan
  return daisy.corner(px, y, pz, false)
end
trashed.rug = function() return nil end
trashed.boards = daisy.boards

-- what the plan scatters about: x, y, z in the room
function trashed.extra(x, y, z)
  local P = trashed.plan
  if not P then return nil end
  local function tl(c, r) local row = P[r + 1]; return row and row[c + 1] end
  -- the hole in the north wall, x 49..62, ragged, through to the dark
  if z <= 11 and x >= 46 and x <= 65 then
    local cx = 55.5
    local top = 20 - floor(abs(x - cx) * 0.9) - hash(x, 0, 3) % 3
    local inHole = x >= 49 and x <= 62 and y >= 1 and y <= top
    if inHole then return false end                               -- carved
    -- cracked plaster round it
    if z == 10 and y <= top + 3 and y >= 2 and (x + y) % 4 == 0 then return sw(PLASTER_B, 2) end
  end
  if y > 8 then return nil end
  local c, r = floor(x / 8), floor(z / 8)
  local v = tl(c, r)
  local lx, lz = x % 8, z % 8
  if v == 40 then                                                -- a lump of the wall
    local d = (lx - 3.5) ^ 2 + (lz - 4) ^ 2
    if d <= 5 - y * 2 and y <= 2 then return sw(PLASTER, 3 + hash(x, y, z) % 3) end
  elseif v == 34 then                                            -- a book thrown down
    if y == 1 and lx >= 1 and lx <= 6 and lz >= 2 and lz <= 6 then
      return sw(BOOK_R + (c + r) % 4, (lz == 2 or lz == 6) and 2 or 4)
    end
  elseif v == 55 and y == 0 then                                 -- a boot print
    local heel = (lx - 3) ^ 2 + (lz - 6) ^ 2 <= 2
    local sole = (lx - 3.5) ^ 2 / 4 + (lz - 2.5) ^ 2 / 6 <= 1
    if heel or sole then return sw(SOIL, 3) end
  end
  -- the knocked-over stools: a round seat on its edge, the legs out north
  if (tl(c, r) == 28 or tl(c, r) == 29 or tl(c, r) == 68 or tl(c, r) == 69) then
    local c0 = (tl(c, r) == 28 or tl(c, r) == 68) and c or c - 1
    local r0 = (tl(c, r) == 28 or tl(c, r) == 29) and r or r - 1
    local ux, uz = x - c0 * 8, z - r0 * 8
    local sx, sy = ux - 7.5, y - 5
    if uz >= 10 and uz <= 12 and sx * sx + sy * sy <= 30 and y >= 0 then
      return sw(uz == 12 and CUSH_D or OAK, 4)
    end
    if y >= 2 and y <= 3 and (abs(sx) >= 3 and abs(sx) <= 4) and uz >= 2 and uz <= 9 then
      return sw(OAK, 2)
    end
  end
  -- the tipped plant by the door: the pot on its side, soil and leaves out
  if x >= 96 and z >= 112 then
    local px, pz = x - 116, z - 122
    if y <= 6 and px * px * 0.3 + (y - 3) ^ 2 <= 9 and pz >= -3 and pz <= 3 then
      return sw(CLAY, 3 + hash(x, y, z) % 2)
    end
    if y == 0 and x >= 98 and x <= 110 and abs(pz) <= 4 then return sw(SOIL, 2 + hash(x, 0, z) % 2) end
    if y <= 3 and x >= 100 and x <= 109 and (x + z * 3) % 5 == 0 and abs(pz) <= 5 then return sw(LEAF, 3 + y) end
  end
  return nil
end

-- --------------------------------------------- Saffron: Mr. Psychic's
-- The man who knew you were coming: a dim room, a crystal ball on a cloth
-- on the table, a chart of the stars on the wall, candles, a cat's cushion.
local psychic = {}
psychic.skin = trader.skin
psychic.wallSkin = trader.wallSkin
psychic.frame, psychic.sill = trader.frame, trader.sill
psychic.win = trader.win
psychic.curtains = function(x, y, z) return tiedCurtains(x, y, z, ACC_3) end
psychic.sconcesLit = false
-- the picture: a chart of the stars, a crescent moon
function psychic.picture(lx, y)
  if lx == 0 or lx == 15 or y == 12 or y == 23 then return sw(BRASS, 4) end
  if (lx - 11) ^ 2 + (y - 19) ^ 2 <= 6 and (lx - 12) ^ 2 + (y - 20) ^ 2 > 4 then return sw(LIGHT, 6) end
  if (lx * 5 + y * 3) % 11 == 0 then return sw(TRIM, 6) end
  return sw(ACC_1, 2)
end
local function curios(ux, s, hy, dz)
  if s == 0 then return books(81, 0, 4)(ux, s, hy, dz) end
  if dz < 8 or dz > 15 then return nil end
  local slot = floor((ux - 1) / 5)
  local cx, cz = 1 + slot * 5 + 2, 11.5
  if s == 1 and hy <= 3 and (ux - cx) ^ 2 + (dz - cz) ^ 2 <= 2 then          -- jars
    return sw(hy == 3 and DARK or ({ ACC_3, CUSH_C, CUSH_B })[slot % 3 + 1], 4)
  end
  if s == 2 and hy <= 1 and abs(ux - cx) <= 1 and abs(dz - cz) <= 2 then      -- cards in a stack
    return sw(PAPER, 5)
  end
  return nil
end
function psychic.westCases(x, y, z)
  local ux, dz = x % 16, z - 10
  return case(ux, y, dz, 20, WALNUT, curios)
end
psychic.eastCase = trader.eastCase
-- the table: a dark cloth, the crystal ball on its stand, two candles
function psychic.table(tx, y, tz)
  if y <= 8 then return speary.table(tx, y, tz) end
  if y == 9 then
    if Lib.cornerCut(tx, tz, 32, 32, 3) then return nil end
    return sw(ACC_3, 2 + (tx + tz) % 2)                                     -- the cloth
  end
  local cx, cz = tx - 15.5, tz - 15.5
  local d = cx * cx + cz * cz
  if y == 10 and d <= 5 then return sw(BRASS, 3) end                       -- the stand
  local by = y - 14
  if y >= 11 and d + by * by <= 12 then return sw(SKY, 5 + (by > 1 and 2 or 0)) end   -- the ball
  for _, c in ipairs({ { 6, 6 }, { 25, 25 } }) do
    local px, pz = tx - c[1], tz - c[2]
    if px * px + pz * pz <= 1 then
      if y <= 13 then return sw(PAPER, 6) end
      if y == 14 then return sw(LIGHT, 7) end                               -- the flame
    end
  end
  return nil
end
psychic.stool = trader.stool
psychic.corner = function(px, y, pz, east)
  if east then
    local d = px * px + pz * pz
    if y <= 2 and d <= 20 then return sw(ACC_3, 3 + y) end                  -- a cushion
    return nil
  end
  return daisy.corner(px, y, pz, false)
end
psychic.rug = trader.rug
psychic.boards = trader.boards

local HOMES = { daisy, speary, trader, nido, miner, seaside, melanie, daycare, trashed, psychic }

-- ============================================================= the room ==

local STOOL_AT = { { 39.5, 55.5 }, { 87.5, 55.5 }, { 39.5, 71.5 }, { 87.5, 71.5 } }

local function stools(x, y, z, h)
  if z < 48 or z > 79 then return nil end
  for idx, c in ipairs(STOOL_AT) do
    local dx, dz = x - c[1], z - c[2]
    if abs(dx) <= 7.5 and abs(dz) <= 7.5 then return h.stool(dx, dz, y, idx) end
  end
  return nil
end

local function furniture(x, y, z, h)
  if z <= 11 then
    local w = northWall(x, y, z, h)
    if w or z <= 9 or not (x <= 31 or x >= 112) then return w end
  end
  if z >= 10 and z <= 30 then
    if x <= 31 then return h.westCases(x, y, z) end
    if x >= 112 then return h.eastCase(x, y, z) end
  end
  if x >= 48 and x <= 79 and z >= 48 and z <= 79 then return h.table(x - 48, y, z - 48) end
  if z >= 108 and (x <= 15 or x >= 112) then
    local east = x >= 112
    return h.corner(x - (east and 120 or 8), y, z - 120, east)
  end
  return nil
end

local function roomFor(h)
  return function(x, y, z)
    if x < 0 or x > 127 then                         -- side walls, outside
      if y > sideH(z) or z < 0 then return nil end
      return h.wallSkin(z + 5, y)
    end
    -- a resident's own scatter, read off the plan (false: carved away)
    if h.extra then
      local e = h.extra(x, y, z)
      if e == false then return nil end
      if e then return e end
    end
    local hit = furniture(x, y, z, h)
    if hit or y > 0 or z <= 9 then return hit end
    -- the doormat's cells stay open: the drawn mat shows, set in the boards
    if z >= 112 and x >= 32 and x <= 63 then return nil end
    return h.rug(x, z) or h.boards(x, z)
  end
end

local FLOOR = { [1] = true, [4] = true, [20] = true }
local STOOL = { [2] = true, [3] = true, [18] = true, [19] = true }

-- `t.home` is "room", "stoolsW" or "stoolsE"; `mapId` picks who lives here.
function Kit.model(sp, t, mapId)
  local v = Kit.MAPS[mapId]
  if not v then return nil, "not a town home: " .. tostring(mapId) end
  local h = HOMES[v]
  h.plan = t.tiles
  if t.home == "seat" then
    -- one stool alone, its cell's corner at tile t.seatAt
    local x0, z0 = t.seatAt[1] * 8, t.seatAt[2] * 8
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      return stools(x + x0, y, z + z0, h)
    end, FLOOR)
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 15, 13
    m.standH = Kit.SEAT_H
    return m
  end
  local seats = t.home == "stoolsW" or t.home == "stoolsE"
  if not seats then
    local open = {}
    for id in pairs(FLOOR) do open[id] = true end
    for id in pairs(STOOL) do open[id] = true end
    -- a plan whose floor has its own drawings (the robbed house's debris)
    -- claims those too: the kit stands them
    return Lib.model(Kit, sp, t, roomFor(h), open)
  end
  -- the seats: only the stool cells, at the sitter's height; the
  -- template's own corner is tile (4, 6) or (10, 6)
  local x0 = t.home == "stoolsW" and 32 or 80
  local m, why = Lib.model(Kit, sp, t, function(x, y, z)
    return stools(x + x0, y, z + 48, h)
  end, FLOOR)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 31, 13
  m.standH = Kit.SEAT_H
  return m
end

Kit.room = roomFor   -- for a headless preview

return Kit
