-- Voxel world mode: Professor Oak's laboratory INSIDE (OAKS_LAB).
--
-- The homes' contract (lib/HomeLib.lua) on a bigger plan: 20x24 tiles, so
-- the room is 160 x 192 voxels, x east and z south. An authored sheet
-- (tools/oaks_lab.py, whose wood, dark and white are the Pallet homes'), the
-- room one function of position, a person sixteen voxels, the wall 28 tall
-- and 5 thick outside the box, the side walls cut down toward the camera,
-- no south wall, no ceiling.
--
-- The plan (tools/interior_plan.py) is the collision, so nothing moves:
--
--   x  0..31   z 16..39   the instrument bench: a terminal and a machine
--                         with a gauge (91-95, 54/55, 85, 88-90)
--   x 32..63   z 16..39   the table the two Pokedexes lie on (the game's
--                         own objects: kept clear for them)
--   x 64..95   z  0..15   two charts on the wall (52/67 over 82/83)
--   x 96..159  z  0..31   four bookcases against the north wall
--   x 96..143  z 48..71   the table of starter balls (the balls are the
--                         game's objects; a name card in front of each)
--   x144..159  z 48..63   Yellow only: a ball drawn into the floor tiles
--                         (11/12 over 27/28), left to the profile, which
--                         stands the game's own drawing up -- no ball is
--                         redrawn here
--   x  0..63, 96..159  z 96..127   two banks of four free-standing cases
--   x 64..95   z176..191  the doormat, left drawn (6/22)
--
-- The table tops stand at y 11 so the objects on them -- which stand at
-- the profile's `table` height, 12 (VoxelScene.groundAt asks TileShape) --
-- lie ON them.
--
-- Who works here: Oak. A working lab, not a showroom: binders and journals
-- to the cornice, a terminal left on, a machine reading something, papers
-- pinned up, a chart of three forms growing into one another, the three
-- balls on their table with a card each.
--
-- Coordinates: x east 0..159, z south 0..191, y up. Nothing here is
-- extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/oaks_lab.png", SHEET_W = 8, SHEET_H = 32 }

Kit.MAPS = { OAKS_LAB = 1 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, hash = Lib.sw, Lib.hash
local WALL_H, WALL_D = Lib.WALL_H, Lib.WALL_D
local W, D = 160, 192

-- rows of the sheet; tools/oaks_lab.py is the mirror of this list
local PLASTER, TILE, ASH, OAK, WALNUT, DARK, TRIM, STEEL,
      STEEL_D, BENCH, BEIGE, SCREEN, GLOW, BUTTON_R, BUTTON_Y, BUTTON_B,
      GLASS, LIQ_G, LIQ_B, LIQ_R, PAPER, BOOK_R, BOOK_G, BOOK_B,
      BOOK_Y, BINDER, CORK, LEAF, CLAY, BRASS, LIGHT, RUNNER =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31

-- the dollhouse cut, the homes' ramp
local sideH = Lib.sideH

-- ------------------------------------------------------------ the walls --
-- A dark skirting, a dado of square tiles to the rail (a laboratory's
-- washable wall), cool white plaster, a three-course cornice.
local SKIN = {
  skirt = { 2, function(u, y) return sw(DARK, y == 2 and 4 or 3) end },
  dado = { 11, function(u, y)
    if u % 4 == 0 or (y - 3) % 4 == 3 then return sw(TILE, 2) end   -- the joints
    return sw(TILE, 5 + hash(floor(u / 4), floor((y - 3) / 4), 3) % 2)
  end },
  rail = { 12, sw(TRIM, 5) },
  cornice = { 26, function(u, y) return sw(TRIM, ({ 3, 5, 6 })[y - 25] or 6) end },
  field = function(u, y) return sw(PLASTER, hash(u, y, 4) % 17 == 0 and 4 or 5) end,
}
local wallSkin = Lib.wallSkin(SKIN)

-- two charts on the wall over x 64..95 (the drawing's two panels): on the
-- left three forms, each grown from the one before, an arrow between;
-- on the right a curve climbing over a ruled grid
local function charts(x, y)
  if y < 12 or y > 24 then return nil end
  local left = x >= 66 and x <= 78
  local right = x >= 81 and x <= 93
  if not (left or right) then return nil end
  local x0 = left and 66 or 81
  local lx = x - x0                                    -- 0..12
  if lx == 0 or lx == 12 or y == 12 or y == 24 then return sw(WALNUT, 4) end
  if left then
    for i, c in ipairs({ { 2.5, 1.2 }, { 6, 1.7 }, { 10, 2.3 } }) do
      local dx, dy = lx - c[1], y - 18
      if dx * dx + dy * dy <= c[2] * c[2] + 0.3 then
        return sw(({ LIQ_G, LIQ_B, LIQ_R })[i], 4)
      end
    end
    if y == 18 and (lx == 4 or lx == 8) then return sw(DARK, 4) end   -- arrows
    if y == 22 and lx >= 2 and lx <= 10 then return sw(DARK, 5) end   -- a title
    return sw(PAPER, 6)
  end
  local curve = 14 + floor((lx - 1) * (lx - 1) / 14)
  if y == curve and lx >= 1 and lx <= 11 then return sw(BUTTON_R, 4) end
  if lx == 1 or y == 14 then return sw(DARK, 5) end                   -- the axes
  if (lx - 1) % 3 == 0 or (y - 14) % 3 == 0 then return sw(PAPER, 4) end
  return sw(PAPER, 6)
end

-- a cork board over the Pokedex table, papers pinned on it
local function noticeBoard(x, y)
  if x < 36 or x > 59 or y < 14 or y > 23 then return nil end
  if x == 36 or x == 59 or y == 14 or y == 23 then return sw(WALNUT, 3) end
  for _, p in ipairs({ { 38, 16, 43, 21 }, { 45, 17, 49, 22 }, { 51, 15, 57, 20 } }) do
    if x >= p[1] and x <= p[3] and y >= p[2] and y <= p[4] then
      if x == p[1] + 1 and y == p[4] then return sw(BUTTON_R, 5) end   -- the pin
      if (y - p[2]) % 2 == 1 and x > p[1] and x < p[3] then return sw(PAPER, 3) end
      return sw(PAPER, 6)
    end
  end
  return sw(CORK, 4 + hash(x, y, 5) % 2)
end

local function northWall(x, y, z)
  if z <= 9 then return wallSkin(x + 5, y) end
  if z == 10 then
    if Lib.proudCourse(SKIN, y) then return wallSkin(x + 5, y) end
    return charts(x, y) or noticeBoard(x, y)
  end
  return nil
end

-- ------------------------------------------------- the instrument bench --
-- x 0..31, z 16..38: a bench 10 tall with steel cupboards under a black
-- resin top that overhangs a voxel and is nosed; on it, the terminal (a
-- beige cabinet, its green screen on, a keyboard in front) and a machine
-- with a round gauge, a row of buttons and a strip of readout.
local function bench(x, y, z)
  if x > 31 or z < 16 or z > 39 then return nil end
  local front = 38
  if y <= 9 then
    if z > front - 1 then return nil end
    if y <= 1 then return z <= front - 3 and sw(STEEL_D, 2) or nil end      -- kick
    if z == front - 1 then
      if x % 16 == 0 or x % 16 == 15 or x == 7 or x == 8 or x == 23 or x == 24 then
        return sw(STEEL_D, 4)                                               -- door frames
      end
      if y == 6 and (x == 6 or x == 9 or x == 22 or x == 25) then return sw(BRASS, 5) end
      return sw(STEEL, 5)
    end
    return sw(STEEL, 3)
  end
  if y <= 11 then
    if y == 11 and (z == front or x == 31) then return nil end              -- the nose
    return sw(BENCH, y == 11 and 4 or 3)
  end
  -- the terminal, on the left
  if x >= 2 and x <= 14 then
    local tx = x - 2                                     -- 0..12
    if z >= 20 and z <= 31 and y <= 23 then
      local back = z <= 25 and abs(tx - 6) <= 4 - (25 - z) * 0.4
      local box = z >= 26
      if box then
        if z == 31 and y >= 14 and y <= 21 and tx >= 2 and tx <= 10 then
          -- the screen: green phosphor, a few lines of text
          if (y == 19 or y == 17 or y == 15) and (tx + y) % 3 ~= 0 then return sw(GLOW, 6) end
          return sw(SCREEN, 4)
        end
        if y == 12 then return sw(BEIGE, 3) end
        return sw(BEIGE, z == 31 and 5 or 4)
      end
      if back and y <= 22 then return sw(BEIGE, 3) end
    end
    if y == 12 and z >= 33 and z <= 36 and tx >= 1 and tx <= 11 then          -- keyboard
      if z == 33 then return sw(BEIGE, 3) end
      return sw((tx + z) % 2 == 0 and BEIGE or PAPER, 5)
    end
    return nil
  end
  -- the machine, on the right: a steel case to y 24, a round gauge on its
  -- face, a strip of readout, three buttons, a cable out of its side
  if x >= 17 and x <= 30 then
    local mx = x - 17                                    -- 0..13
    if z >= 20 and z <= 33 and y <= 24 then
      if y == 24 then return sw(STEEL_D, 4) end
      if z == 33 then
        local gx, gy = mx - 6.5, y - 19
        local gd = gx * gx + gy * gy
        if gd <= 10 then
          if gd > 6.5 then return sw(BRASS, 4) end                          -- bezel
          if abs(gx - (gy - 0.5) * 0.5) < 0.6 and gy <= 0.5 and gy >= -2.5 then
            return sw(BUTTON_R, 4)                                          -- needle
          end
          return sw(GLASS, 6)
        end
        if y == 14 and mx >= 2 and mx <= 11 then return sw(GLOW, 4 + mx % 2) end
        if y == 12 and (mx == 3 or mx == 6 or mx == 9) then
          return sw(({ BUTTON_R, BUTTON_Y, BUTTON_B })[mx / 3], 5)
        end
        if mx == 0 or mx == 13 then return sw(STEEL_D, 4) end
        return sw(STEEL, 5)
      end
      return sw(STEEL, 4)
    end
    return nil
  end
  -- the cable, terminal to machine, lying on the bench top
  if y == 12 and x >= 15 and x <= 16 and z == 28 then return sw(DARK, 3) end
  return nil
end

-- --------------------------------------------------------- lab tables --
-- A table 32 or 48 wide on round steel legs, an apron, a pale laminate top
-- two voxels thick (y 10..11) with a steel edge band.
local function labTable(tx, y, tz, w, d)
  if y <= 9 then
    local lx = tx >= 2 and tx <= 3 or tx >= w - 4 and tx <= w - 3
    local lz = tz >= 2 and tz <= 3 or tz >= d - 4 and tz <= d - 3
    if lx and lz then return sw(STEEL_D, y == 0 and 2 or 4) end
    if y >= 8 and (tx == 2 or tx == w - 3 or tz == 2 or tz == d - 3)
       and tx >= 2 and tx <= w - 3 and tz >= 2 and tz <= d - 3 then
      return sw(STEEL_D, 3)                                                -- apron
    end
    return nil
  end
  if y <= 11 then
    if Lib.cornerCut(tx, tz, w, d, 1) then return nil end
    if tx == 0 or tx == w - 1 or tz == 0 or tz == d - 1 then return sw(STEEL, y == 11 and 6 or 4) end
    return sw(TRIM, y == 11 and 4 or 3)
  end
  return nil
end

-- the Pokedex table (x 32..63, z 16..39): the two Pokedexes lie in its
-- north half (the game's objects); in the south half an open notebook and
-- a pen
local function dexTable(x, y, z)
  local tx, tz = x - 32, z - 16
  local t = labTable(tx, y, tz, 32, 24)
  if t then return t end
  if y == 12 and tz >= 17 and tz <= 21 and tx >= 6 and tx <= 15 then
    if tx == 10 or tx == 11 then return sw(PAPER, 2) end                    -- the spine
    return sw(PAPER, (tz % 2 == 0) and 4 or 6)
  end
  if y == 12 and tz == 19 and tx >= 18 and tx <= 23 then return sw(BOOK_B, 4) end   -- the pen
  return nil
end

-- the starter table (x 96..143, z 48..71): the balls are the game's own
-- objects on its north half; along the front, a name card for each, its
-- mark the colour of what is inside. In Yellow one ball is left, Blue's.
local function ballTable(x, y, z, yellow)
  local tx, tz = x - 96, z - 48
  local t = labTable(tx, y, tz, 48, 24)
  if t then return t end
  if y == 12 or y == 13 then
    for i, c in ipairs({ 8, 24, 40 }) do
      if not yellow or i == 2 then
        if tx >= c - 3 and tx <= c + 2 and tz >= 18 and tz <= 19 then
          if y == 12 and tz == 19 then return sw(PAPER, 4) end              -- the card's foot
          if y == 13 and tz == 18 then
            if tx == c - 2 then
              return sw(yellow and BOOK_Y or ({ LIQ_R, LIQ_B, LIQ_G })[i], 4)
            end
            return sw(PAPER, 6)
          end
        end
      end
    end
  end
  return nil
end

-- ------------------------------------------------------------ the cases --
-- Against the north wall, four units of sixteen (x 96..159, z 10..30),
-- full height (H 26): the Lavender kit's open case, stocked by unit.
local function journals(salt, unit)
  return function(ux, s, hy, dz)
    if dz < 4 or dz > 16 then return nil end
    local bid = floor((ux - 1) / 2) + s * 7 + unit * 31
    local h = hash(bid, s, salt)
    if h % 11 == 0 then return nil end
    if hy >= 3 + h % 3 then return nil end
    return sw(BOOK_R + h % 4, h)
  end
end

local function binders(ux, s, hy, dz)
  if dz < 4 or dz > 16 then return nil end
  local bid = floor((ux - 1) / 2)
  if hy >= 5 then return nil end
  if hy == 3 and dz == 16 then return sw(PAPER, 5) end                     -- the label
  if hash(bid, s, 21) % 9 == 0 then return nil end
  return sw(BINDER, 3 + hash(bid, s, 22) % 3)
end

local function specimens(ux, s, hy, dz)
  -- jars on one shelf, a flask, then journals
  if s == 1 then
    for i, c in ipairs({ 3.5, 7.5, 11.5 }) do
      local dx, dd = ux - c, dz - 11
      local d = dx * dx + dd * dd
      if d <= 2.6 and hy <= 3 then
        if hy == 3 then return sw(DARK, 4) end                              -- lid
        if hy >= 1 and d <= 1.2 then return sw(({ LIQ_G, LIQ_B, LIQ_R })[i], 4) end
        return sw(GLASS, 5)
      end
    end
    return nil
  end
  return journals(31, 2)(ux, s, hy, dz)
end

local function scrolls(ux, s, hy, dz)
  if s == 2 then                       -- rolled charts lying stacked
    if dz >= 6 and dz <= 15 and hy <= 2 and ux >= 2 and ux <= 13 then
      local r = (ux % 3 == 1) and 0 or 1
      if hy <= 1 + r then return sw(PAPER, 4 + (dz + hy) % 3) end
    end
    return nil
  end
  return journals(41, 3)(ux, s, hy, dz)
end

local STOCK = { journals(11, 0), binders, specimens, scrolls }

local function caseAt(ux, y, dz, H, fill)
  return Lib.case(ux, y, dz, H, OAK, DARK, fill)
end

local function northCases(x, y, z)
  if x < 96 or z < 10 or z > 30 then return nil end
  local unit = floor((x - 96) / 16)
  return caseAt(x % 16, y, z - 10, 26, STOCK[unit + 1])
end

-- The two banks in the middle of the room (z 96..127): elevations, so each
-- case stands in the south cell of its two (z 108..127, front to the south)
-- and the north cell behind it is the case's own shadow. Lower than the
-- wall cases (H 20) -- they stand in the room, in front of the camera.
-- What lies on the banks' tops, one thing a unit (ux 0..15, dz 0..19, hy
-- the height above the top): their tops face the camera square-on, and
-- left bare they measured as the frame's largest single swatch.
local function onBank(unit, ux, hy, dz)
  local kind = unit % 4
  if unit >= 6 then kind = (unit + 2) % 4 + 4 end
  if kind == 0 then                    -- journals lying stacked, offset
    if ux >= 3 and ux <= 11 and dz >= 5 and dz <= 13 and hy <= 2 then
      local off = hy % 2
      if ux - off >= 3 and ux - off <= 10 then return sw(BOOK_R + hy, 3 + (dz % 2)) end
    end
  elseif kind == 1 then                -- a microscope: foot, pillar, arm, tube
    local fx, fz = ux - 8, dz - 10
    if hy == 0 and abs(fx) <= 2 and abs(fz) <= 2 then return sw(STEEL_D, 3) end
    if hy >= 1 and hy <= 4 and fx == 1 and fz == 1 then return sw(STEEL_D, 4) end
    if hy == 2 and abs(fx) <= 1 and fz == -1 then return sw(STEEL, 5) end        -- stage
    if hy >= 3 and hy <= 5 and fx == 0 and fz == 0 then return sw(STEEL, 6) end  -- tube
    if hy == 5 and fx == 1 and fz <= 1 and fz >= 0 then return sw(STEEL_D, 4) end
  elseif kind == 2 then                -- a fern in a clay pot
    local px, pz = ux - 7.5, dz - 9.5
    local d = px * px + pz * pz
    if hy <= 2 then
      if d <= (2 + hy * 0.4) ^ 2 then return sw(hy == 2 and SOIL or CLAY, 4) end
    elseif hy <= 6 then
      local r = 4.2 - abs(hy - 4) * 0.8
      if d <= r * r and hash(ux, hy, dz) % 4 ~= 0 then return sw(LEAF, 3 + hy % 3) end
    end
  elseif kind == 3 then                -- three box files standing in a row
    if dz >= 7 and dz <= 14 and hy <= 4 and ux >= 2 and ux <= 13 and (ux - 2) % 4 ~= 3 then
      if dz == 14 and hy == 3 then return sw(PAPER, 5) end
      return sw(BINDER, 3 + floor((ux - 2) / 4))
    end
  elseif kind == 4 then                -- rolled charts
    if dz >= 6 and dz <= 14 and hy <= 1 and ux >= 2 and ux <= 13 then
      if (ux % 3 ~= 0) or hy == 0 then return sw(PAPER, 4 + (ux + dz) % 3) end
    end
  elseif kind == 5 then                -- a globe on its stand
    local gx, gz = ux - 8, dz - 10
    if hy == 0 and gx * gx + gz * gz <= 4 then return sw(WALNUT, 3) end
    if hy == 1 and gx == 0 and gz == 0 then return sw(BRASS, 4) end
    local gd = gx * gx + gz * gz + (hy - 5) * (hy - 5)
    if gd <= 9.5 then return hash(ux, hy, dz) % 3 == 0 and sw(LEAF, 5) or sw(LIQ_B, 4) end
  elseif kind == 6 then                -- a specimen jar
    local jx, jz = ux - 6.5, dz - 9.5
    local jd = jx * jx + jz * jz
    if hy <= 4 and jd <= 4.5 then
      if hy == 4 then return sw(DARK, 4) end
      if jd <= 2 and hy >= 1 then return sw(LIQ_G, 4) end
      return sw(GLASS, 5)
    end
  else                                 -- loose papers, a pen on them
    if hy == 0 and ux >= 3 and ux <= 12 and dz >= 5 and dz <= 13 then
      if dz == 9 and ux >= 6 and ux <= 10 then return sw(BOOK_B, 4) end
      return sw(PAPER, 5 + (ux + dz * 3) % 2)
    end
  end
  return nil
end

local function bankCases(x, y, z)
  if z < 108 or z > 127 then return nil end
  if not (x <= 63 or x >= 96) then return nil end
  local unit = floor(x / 16)
  local ux, dz = x % 16, z - 108                       -- dz 0 back .. 19 front
  if y > 20 then return onBank(unit, ux, y - 21, dz) end
  if y == 20 then                                      -- the top, boards with joints
    if ux == 0 or dz % 5 == 0 then return sw(OAK, 3) end
    return sw(OAK, 4 + hash(floor(dz / 5), unit, 3) % 3)
  end
  local fill = unit % 2 == 0 and journals(51, unit) or binders
  return caseAt(ux, y, dz + 1, 20, fill)
end

-- --------------------------------------------------- the floor, the rug --
-- Ash boards four wide, joints every 32 staggered 13. The lab's floor is
-- the biggest surface in Pallet, and three shades over it measured as one
-- swatch (a fifth of the frame): four shades a plank, and a grain streak
-- now and then along it.
local boardsOf = Lib.boards(4, 32, 13, sw(ASH, 2), function(i, row)
  return 3 + hash(i, row, 7) % 4
end)
local function planks(x, z)
  local s = boardsOf(x, z)
  if s == sw(ASH, 2) then return s end
  if (x * 7 + floor(z / 4) * 13) % 19 == 0 and z % 4 ~= 1 then s = s - 1 end
  return sw(ASH, s)
end

-- a runner from the door to the starter table, unclaimed
local function runner(x, z)
  if x < 66 or x > 93 or z < 132 or z > 173 then return nil end
  local b = min(x - 66, 93 - x, z - 132, 173 - z)
  if b == 0 then return sw(RUNNER, 2) end
  if b == 2 then return sw(PAPER, 3) end
  return sw(RUNNER, 4 + hash(floor(x / 2), 0, floor(z / 2)) % 2)
end

-- -------------------------------------------------------------- the room --

local function furniture(x, y, z, yellow)
  if z <= 10 then
    local w = northWall(x, y, z)
    if w or z <= 9 then return w end
  end
  if z <= 39 then
    if x <= 31 then return bench(x, y, z) end
    if x <= 63 and z >= 16 then return dexTable(x, y, z) end
    if x >= 96 then return northCases(x, y, z) end
    return nil
  end
  if z >= 48 and z <= 71 and x >= 96 and x <= 143 then return ballTable(x, y, z, yellow) end
  if z >= 96 and z <= 127 then return bankCases(x, y, z) end
  return nil
end

local function roomFor(yellow)
  return function(x, y, z)
    if x < 0 or x > W - 1 then                          -- side walls, outside
      if y > sideH(z) or z < 0 then return nil end
      return wallSkin(z + 5, y)
    end
    local hit = furniture(x, y, z, yellow)
    if hit or y > 0 or z <= 9 then return hit end
    if z >= 176 and x >= 64 and x <= 95 then return nil end         -- the mat, drawn
    -- (Yellow's ball cell gets the boards too: the drawing's own floor
    -- round the ball showed as a square of another floor; the profile's
    -- cutout stands the ball itself up on them)
    return runner(x, z) or planks(x, z)
  end
end

-- unclaimed: the floor, the doormat, and Yellow's drawn ball
local OPEN = { [17] = true, [6] = true, [22] = true,
               [11] = true, [12] = true, [27] = true, [28] = true }

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not Oak's lab: " .. tostring(mapId) end
  -- Yellow's plan draws a ball at tiles (18, 6): row 7, column 19 here
  local yellow = t.tiles[7] and t.tiles[7][19] == 11
  local m, why = Lib.model(Kit, sp, t, roomFor(yellow), OPEN)
  if not m then return nil, why end
  m.W, m.xmax, m.zmax = W, W - 1 + WALL_D, D - 1
  return m
end

Kit.room = roomFor   -- for a headless preview

return Kit
