-- Voxel world mode: the S.S. ANNE inside -- passages and cabins, read off
-- their own plans.
--
-- Every deck of the liner is drawn in one tileset, and the parts that make
-- a passage or a cabin are few:
--
--   17                the wall's cap        the top of the bulkhead
--   16, 2/3           the wall              white-painted steel, a brass
--                                           porthole with blue glass at 2/3
--   18/19             its lower band        a navy dado, a brass handrail
--   14/15 over 30/31  a door in it          a cabin door: oak leaf, brass
--                                           handle, a white frame
--   21/22             a bulkhead's side     a wall standing end-on
--   5/6/51            a partition's top     the low wall of the cabin fronts
--                                           along a passage (kept low, so the
--                                           passage shows from above)
--   4, 35, 74         the passage floor     a red runner, a gold border; the
--                                           shaded strips along a wall are
--                                           the same floor in its shadow
--   13/29             the cabin floor       a cream and blue lino checker
--   9..12 / 25..28    a table               an oak table, a white cloth, a
--                                           plate and a cup (26 and 44)
--   70/71 / 86/87..   a berth               an oak frame, a pillow, white
--                                           linen, a blue blanket
--
-- Everything else on these decks -- the stairs, the bow's deck and its
-- fittings, the kitchen's ranges, the captain's things -- stays the
-- profile's: its tiles are left open (and the template allows them to be
-- stood already: `allowSkip`). On the homes' shell: no south wall, no
-- ceiling. A room is cols*8 x rows*8 voxels. Nothing here is extracted from
-- the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/ship_kit.png", SHEET_W = 8, SHEET_H = 16 }
Kit.MAPS = { SS_ANNE_1F = 1, SS_ANNE_1F_ROOMS = 1, SS_ANNE_2F = 1, SS_ANNE_2F_ROOMS = 1,
             SS_ANNE_3F = 1, SS_ANNE_B1F = 1, SS_ANNE_B1F_ROOMS = 1, SS_ANNE_KITCHEN = 1,
             SS_ANNE_CAPTAINS_ROOM = 1, SS_ANNE_BOW = 1 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local PAINT, PAINT_DK, NAVY, BRASS, GLASS, RUNNER, GOLD, LINO_A, LINO_B, OAK, WALNUT,
      LINEN, BLANKET, STEEL, DARK, CHINA = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local WALL_H, LOW_H, SIDE_H = 28, 10, 20
Kit.CLASS = {}
local C = Kit.CLASS
C[17] = "cap"
for _, t in ipairs({ 16, 2, 3 }) do C[t] = "wall" end
for _, t in ipairs({ 18, 19 }) do C[t] = "dado" end
for _, t in ipairs({ 14, 15, 30, 31 }) do C[t] = "door" end
for _, t in ipairs({ 21, 22 }) do C[t] = "side" end
for _, t in ipairs({ 5, 6, 51 }) do C[t] = "low" end
for _, t in ipairs({ 4, 35, 74 }) do C[t] = "runner" end
for _, t in ipairs({ 13, 29 }) do C[t] = "lino" end
for _, t in ipairs({ 9, 10, 12, 25, 26, 44, 28 }) do C[t] = "table" end
for _, t in ipairs({ 70, 71, 86, 87 }) do C[t] = "berth" end
C[1] = "void"
-- the exit mat (36 over 52): claimed and laid by the kit, because the engine
-- paints the one unclaimed walkable tile under every claimed cell -- the
-- mat, drawn over the whole void round the cabins
for _, t in ipairs({ 36, 52 }) do C[t] = "mat" end
-- the bow's bulwark (46/47 over 62/63): the ship's side standing above
-- the open deck
for _, t in ipairs({ 46, 47, 62, 63 }) do C[t] = "bulwark" end
-- a table's front (11, its drawers 59/60), what is laid on one (the
-- platter 64/65 over 80/81, the open log book 68/69); the galley's hobs
for _, t in ipairs({ 11, 59, 60, 64, 65, 80, 81, 68, 69, 53 }) do C[t] = "table" end
-- the bins (72/73 over 88/89): a round steel bin
for _, t in ipairs({ 72, 73, 88, 89 }) do C[t] = "bin" end
-- the captain's cabinet against the east wall (9/12 its top, 54/43 its
-- drawers)
for _, t in ipairs({ 54, 43 }) do C[t] = "cabinet" end

local function wallFace(x, y)
  if y <= 1 then return sw(NAVY, 3) end
  if y >= WALL_H - 1 then return sw(PAINT, 6) end
  if x % 16 == 0 then return sw(PAINT_DK, 4) end                -- the plate seams
  return sw(PAINT, 4 + hash(floor(x / 16), floor(y / 7), 1) % 2)
end

-- the decks open to the sky: their passage floor (4) is the teak deck
Kit.OPEN_DECK = { SS_ANNE_BOW = true }

local function build(t, mapId)
  local openDeck = Kit.OPEN_DECK[mapId]
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return 1 end
    return t.tiles[r + 1][c + 1]
  end
  local function cls(c, r) return C[tile(c, r)] end
  local W, D = cols * 8, rows * 8

  -- the tables: a top row 9 10 .. 10 12 of any width, body rows starting
  -- 25 below it, and a front row of drawers (11/59/60) if the drawing has
  -- one; each tile of one points at its box { x0, z0, depth, width, front }
  local owner = {}
  for rr = 0, rows - 2 do
    for cc = 0, cols - 2 do
      if tile(cc, rr) == 9 and tile(cc, rr + 1) == 25 then
        local w = 1
        while tile(cc + w, rr) == 10 do w = w + 1 end
        if tile(cc + w, rr) == 12 then
          w = w + 1
          local n = 1
          while tile(cc, rr + n) == 25 do n = n + 1 end
          local front = tile(cc, rr + n) == 11 or tile(cc, rr + n) == 59
          if front then n = n + 1 end
          local box = { cc * 8, rr * 8, n * 8, w * 8, front }
          for i = 0, w - 1 do for j = 0, n - 1 do owner[cc + i + (rr + j) * cols] = box end end
        end
      end
    end
  end
  -- the galley's range: a run of 10 along a row with no 9/12 at its ends,
  -- and everything under it down to the plan's edge
  local RANGE = { [44] = true, [53] = true, [64] = true, [65] = true, [80] = true,
                  [81] = true, [26] = true }
  for rr = 0, rows - 1 do
    for cc = 0, cols - 1 do
      if tile(cc, rr) == 10 and not owner[cc + rr * cols] and tile(cc - 1, rr) ~= 10 then
        local w = 1
        while tile(cc + w, rr) == 10 and not owner[cc + w + rr * cols] do w = w + 1 end
        local n = 1
        while rr + n < rows and RANGE[tile(cc, rr + n)] do n = n + 1 end
        if n > 1 then
          local box = { cc * 8, rr * 8, n * 8, w * 8, false, range = true }
          for i = 0, w - 1 do for j = 0, n - 1 do owner[cc + i + (rr + j) * cols] = box end end
        end
      end
    end
  end
  for rr = 0, rows - 2 do
    for cc = 0, cols - 2 do
      if tile(cc, rr) == 70 and tile(cc + 1, rr) == 71 then
        local n = 1
        while tile(cc, rr + n) == 86 do n = n + 1 end
        local box = { cc * 8, rr * 8, n * 8 }
        for i = 0, 1 do for j = 0, n - 1 do owner[cc + i + (rr + j) * cols] = box end end
      end
    end
  end
  local sideMemo = {}
  local function tallSide(cc, rr)
    local key = cc + rr * cols
    if sideMemo[key] ~= nil then return sideMemo[key] end
    local up = cls(cc, rr - 1)
    local v = (up == "cap" or up == "wall" or up == "dado" or up == "door")
    if up == "side" then v = tallSide(cc, rr - 1) end
    sideMemo[key] = v
    return v
  end
  -- the runner's border: the floor tiles of a passage next to a non-floor
  local function isRun(c, r) return cls(c, r) == "runner" end

  return function(x, y, z)
    if x < 0 or x >= W or z < 0 or z >= D or y < 0 then return nil end
    local c, r = floor(x / 8), floor(z / 8)
    local v = tile(c, r)
    local k = C[v]
    local lx, lz = x % 8, z % 8
    if k == "void" and openDeck then
      -- outside the bulwark on the open deck: the hull's painted top, a
      -- shade under, so nothing of the drawing shows past the rail
      if y > 0 then return nil end
      return sw(PAINT_DK, 2 + hash(floor(x / 16), 0, floor(z / 16)) % 2)
    end
    if (v == 9 or v == 12) and C[tile(c, r + 1)] == "cabinet" then k = "cabinet" end
    if not k or k == "void" then return nil end
    if k == "bulwark" then
      -- white plating to y 9, a teak cap rail, a scupper at the deck every 16
      if y > 11 then return nil end
      if y >= 10 then return sw(OAK, y == 11 and 5 or 4) end
      if y <= 1 and x % 16 >= 6 and x % 16 <= 9 then return sw(DARK, 3) end
      if y == 0 then return sw(NAVY, 3) end
      if x % 16 == 0 or z % 16 == 0 then return sw(PAINT_DK, 4) end
      return sw(PAINT, 4 + hash(floor(x / 16), 0, floor(z / 16)) % 2)
    end

    if k == "cap" then
      if y > WALL_H then return nil end
      return (y == WALL_H) and sw(PAINT, 6) or wallFace(x, y)
    end
    if k == "wall" or k == "dado" or k == "door" then
      -- the bulkhead: the wall band two tiles deep, its face at the south
      -- of the dado row; the cabin door cut through it
      if y > WALL_H then return nil end
      local faceRow = (k == "dado") or v == 30 or v == 31
      if k == "door" then
        local dx = (v == 14 or v == 30) and lx or (lx + 8)       -- 0..15 across
        local inDoor = dx >= 2 and dx <= 13 and y <= 22
        if inDoor then
          if faceRow and lz >= 5 then
            if y == 0 then return sw(OAK, 3) end
            if dx == 2 or dx == 13 or y == 22 then return sw(PAINT, 6) end     -- the frame
            if lz == 5 then
              if dx == 11 and y == 11 then return sw(BRASS, 6) end
              if y == 6 or y == 16 or dx == 5 or dx == 10 then return sw(WALNUT, 3) end
              return sw(OAK, 4 + (y % 2))
            end
            return nil
          end
        end
      end
      if faceRow and lz == 7 then
        if y == 10 then return sw(BRASS, 5) end                  -- the handrail
        if y <= 9 then return sw(NAVY, 4 + (y == 9 and 1 or 0)) end
      end
      if not faceRow and lz == 7 and (v == 2 or v == 3) then
        -- (the porthole sits in the upper tile's face: drawn through to the
        -- dado row, so it is placed on the band's face below)
      end
      -- portholes: centred on the 2/3 pair, on the face
      local up = (k == "dado") and tile(c, r - 1) or v
      if (up == 2 or up == 3) and faceRow and lz == 7 then
        local cx = (up == 2) and (c * 8 + 8) or (c * 8)
        local d = sqrt((x - cx + 0.5) ^ 2 + (y - 18) ^ 2)
        if d <= 3.2 then return sw(GLASS, 4 + (y > 18 and 2 or 0)) end
        if d <= 4.4 then return sw(BRASS, 4 + (y % 2)) end
      end
      if faceRow and lz == 7 and y >= 11 then return wallFace(x, y) end
      if faceRow and lz == 7 then return wallFace(x, y) end
      return wallFace(x, y)
    end
    if k == "side" then
      -- a bulkhead's end stands as tall as what it carries on from: under a
      -- wall band it is a wall, under a cabin front's low wall it is low
      local h = tallSide(c, r) and SIDE_H or LOW_H
      if y > h then return nil end
      if y == h then return (h == LOW_H) and sw(OAK, 5) or sw(PAINT, 6) end
      return wallFace(z, y)
    end
    if k == "low" then
      if y > LOW_H then return nil end
      if y == LOW_H then return sw(OAK, 5) end                   -- a varnished capping rail
      if y <= 1 then return sw(NAVY, 3) end
      return sw(PAINT, 4 + hash(floor(x / 16), 0, 2) % 2)
    end

    -- the floors: everything below stands on y 0
    if k == "table" or (v == 44 and owner[c + r * cols]) then
      local box = owner[c + r * cols]
      if not box then return nil end
      local tx, tz = x - box[1], z - box[2]
      local TD, TW = box[3], box[4]
      if box.range then
        -- the galley range: a steel cabinet 10 tall, its top the hob plate
        if y <= 9 then
          if y == 9 then return sw(STEEL, 5) end
          if tz == 0 then return sw(STEEL, 6) end                    -- its lit back edge
          if y <= 1 then return sw(DARK, 3) end
          return sw(STEEL, 3 + hash(floor(x / 16), 0, 3) % 2)
        end
      else
        if y <= 7 then
          local leg = (tx <= 2 or tx >= TW - 3) and (tz <= 2 or tz >= TD - 3)
          if leg then return sw(WALNUT, 3) end
          if box[5] and tz >= TD - 6 and y >= 4 then
            -- the drawers under the front
            if tx % 16 == 8 and y == 6 then return sw(BRASS, 5) end
            if y == 4 or tx % 16 == 0 then return sw(WALNUT, 3) end
            return sw(OAK, 4)
          end
          if y == 0 then return sw(LINO_A, 3) end
          return nil
        end
        if y <= 9 then return sw(LINEN, y == 9 and 6 or 5) end      -- the cloth, hanging down
      end
      -- what is laid on it, by the tile under the voxel
      local hy = y - 10
      if v == 53 then
        -- a hob: a black ring on the plate
        local cx = (tile(c - 1, r) == 53) and c * 8 or c * 8 + 8
        local cz = (tile(c, r - 1) == 53) and r * 8 or r * 8 + 8
        local d = sqrt((x - cx + 0.5) ^ 2 + (z - cz + 0.5) ^ 2)
        if hy == 0 and ((d <= 5.5 and d >= 3.5) or d <= 1.5) then return sw(DARK, 2) end
        return nil
      end
      if v == 64 or v == 65 or v == 80 or v == 81 then
        -- a platter under a domed cover
        local cx = (v == 64 or v == 80) and c * 8 + 8 or c * 8
        local cz = (v == 64 or v == 65) and r * 8 + 8 or r * 8
        local d = sqrt((x - cx + 0.5) ^ 2 + (z - cz + 0.5) ^ 2)
        if hy == 0 and d <= 6.5 then return sw(CHINA, d > 5.5 and 4 or 6) end
        if hy >= 1 and hy <= 4 and d <= 5 - hy * 0.9 then return sw(STEEL, 5 + (hy >= 3 and 1 or 0)) end
        if hy == 5 and d <= 0.8 then return sw(BRASS, 6) end
        return nil
      end
      if v == 68 or v == 69 then
        -- the log book, open: two pages, lines on them, a spine
        local bx = x - ((v == 68) and c * 8 or (c - 1) * 8)
        local lz2 = z % 8
        if hy == 0 and bx >= 2 and bx <= 13 and lz2 >= 1 and lz2 <= 6 then
          if bx == 7 or bx == 8 then return sw(WALNUT, 4) end
          if lz2 % 2 == 0 and bx % 6 ~= 1 then return sw(DARK, 4) end
          return sw(LINEN, 7)
        end
        return nil
      end
      if v == 26 then
        -- a plate
        local lx2, lz2 = x % 8 - 3.5, z % 8 - 3.5
        local pd = lx2 * lx2 + lz2 * lz2
        if hy == 0 and pd <= 9 then return sw(CHINA, pd <= 3 and 4 or 6) end
        return nil
      end
      if v == 44 and not box.range and x % 16 == 12 and z % 16 == 4 and hy <= 2 then
        return sw(hy == 2 and DARK or CHINA, 4)                       -- a cup
      end
      return nil
    end
    if k == "bin" then
      local c0 = (v == 72 or v == 88) and c or c - 1
      local r0 = (v == 72 or v == 73) and r or r - 1
      local dx, dz = x - (c0 * 8 + 7.5), z - (r0 * 8 + 7.5)
      local d = sqrt(dx * dx + dz * dz)
      if y <= 11 and d <= 5.4 then
        if d > 4.4 then
          if y == 11 or y == 1 then return sw(STEEL, 6) end
          if y % 4 == 0 then return sw(STEEL, 3) end
          return sw(STEEL, 4 + (dx > 0 and 1 or 0))
        end
        if y == 0 then return sw(DARK, 3) end
        if y == 11 then return sw(STEEL, 5) end
        return nil
      end
      if y == 12 and d <= 4 then return sw(STEEL, 6) end              -- the lid
      if y > 0 then return nil end
      local alt = (floor(x / 8) + floor(z / 8)) % 2
      return sw(alt == 0 and LINO_A or LINO_B, 4)
    end
    if k == "cabinet" then
      -- the captain's cabinet: oak, 20 tall, drawers on its west face (the
      -- room side), brass pulls; 9/12 above it is its top
      if y > 20 then return nil end
      if y == 20 then return sw(OAK, 6) end
      if x % 16 == 0 then
        if y <= 1 then return sw(WALNUT, 2) end
        if (y - 2) % 6 == 0 then return sw(WALNUT, 3) end              -- the drawer lines
        if (y - 2) % 6 == 3 and z % 8 == 4 then return sw(BRASS, 6) end
        return sw(OAK, 4)
      end
      return sw(OAK, 3)
    end
    if k == "berth" then
      local box = owner[c + r * cols]
      if not box then return nil end
      local tx, tz, len = x - box[1], z - box[2], box[3]
      if tx < 1 or tx > 14 or tz > len - 2 then return (y == 0) and sw(LINO_A, 3) or nil end
      if y <= 1 then return sw(WALNUT, 3) end
      if tz <= 1 and y <= 12 then return sw(OAK, 4 + (y == 12 and 2 or 0)) end    -- the headboard
      if tx == 1 or tx == 14 then return (y <= 6) and sw(OAK, 4) or nil end
      if y <= 5 then return sw(LINEN, 4) end
      if y == 6 then
        if tz <= 6 then return sw(LINEN, 7) end                   -- the pillow
        if tz <= 8 then return sw(LINEN, 6) end                   -- the sheet turned down
        return sw(BLANKET, 4 + (tx % 4 == 0 and 1 or 0))
      end
      if y == 7 and tz >= 2 and tz <= 5 and tx >= 3 and tx <= 12 then return sw(LINEN, 7) end
      return nil
    end
    if y > 0 then return nil end
    if k == "runner" and openDeck then
      -- teak planks running north-south, caulked seams, butt joints staggered
      if x % 4 == 0 then return sw(WALNUT, 2) end
      local plank = floor(x / 4)
      if (z + plank * 13) % 40 == 0 then return sw(WALNUT, 3) end
      return sw(OAK, 3 + hash(plank, floor((z + plank * 13) / 40), 4) % 3)
    end
    if k == "runner" then
      -- the runner: red, a gold border where the passage floor meets the
      -- wall or a cabin, the floor's shadow strip a shade under
      local edge = (lx == 0 and not isRun(c - 1, r)) or (lx == 7 and not isRun(c + 1, r))
                   or (lz == 0 and not isRun(c, r - 1)) or (lz == 7 and not isRun(c, r + 1))
      if edge then return sw(GOLD, 4) end
      local shade = (v == 35 or v == 74) and -1 or 0
      if (x + z) % 8 == 0 and (x - z) % 8 == 0 then return sw(GOLD, 3) end      -- a small figure
      -- a woven diamond in two reds round each figure
      local dx, dz = (x + 4) % 8 - 4, (z + 4) % 8 - 4
      local ring = abs(dx) + abs(dz)
      if ring == 3 then return sw(RUNNER, 2 + shade) end
      return sw(RUNNER, 4 + shade + (ring <= 1 and 1 or 0) + hash(x, 0, z) % 2)
    end
    if k == "mat" then
      if lx == 0 and not (C[tile(c - 1, r)] == "mat") or lx == 7 and not (C[tile(c + 1, r)] == "mat") then
        return sw(WALNUT, 3)
      end
      return sw(OAK, 2 + ((x + z) % 2) + hash(floor(x / 2), 0, floor(z / 2)) % 2)
    end
    if k == "lino" then
      if x % 8 == 0 or z % 8 == 0 then return sw(LINO_A, 2) end
      local alt = (floor(x / 8) + floor(z / 8)) % 2
      return sw(alt == 0 and LINO_A or LINO_B, 4 + hash(floor(x / 8), 0, floor(z / 8)) % 2)
    end
    return nil
  end, W, D
end

-- a seat alone, its own template (its cell is walkable, the sitter
-- stands at its height): the round stool (7/8 over 23/24), the captain's
-- chair (84/85 its back's top in the wall's band, 66/67 the back, 23/24 the
-- seat)
local function seat(x, y, z, chair)
  local dx, dz = x - 7.5, z - 8
  local d = dx * dx + dz * dz
  if y <= 6 and d <= 1.5 then return sw(STEEL, 4) end                 -- the post
  if y == 0 and d <= 12 then return sw(STEEL, 3) end                  -- its foot
  if y >= 6 and y <= 7 and d <= 20 then
    return sw(chair and NAVY or OAK, y == 7 and 5 or 4)               -- the seat
  end
  if chair and y >= 8 and y <= 18 and z >= 1 and z <= 2 and x >= 2 and x <= 13 then
    return sw(NAVY, 4 + (y == 18 and 1 or 0))                         -- the back
  end
  return nil
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not the S.S. Anne: " .. tostring(mapId) end
  if t.home == "seat" then
    local chair = t.tiles[1][1] == 84
    local oz = chair and 8 or 0
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      local v = seat(x, y, z - oz, chair)
      if v then return v end
      if y == 0 and z >= oz then
        return sw((floor(x / 8) + floor(z / 8)) % 2 == 0 and LINO_A or LINO_B, 4)
      end
      return nil
    end, chair and { [84] = true, [85] = true } or {})
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, #t.tiles * 8 - 1, 20
    m.standH = Lib.SEAT_H
    return m
  end
  local at, W, D = build(t, mapId)
  -- open: every tile this kit does not build
  local open = {}
  for r = 1, #t.tiles do
    for c = 1, #t.tiles[1] do
      local v = t.tiles[r][c]
      if not C[v] then open[v] = true end
    end
  end
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, WALL_H + 1
  return m
end

return Kit
