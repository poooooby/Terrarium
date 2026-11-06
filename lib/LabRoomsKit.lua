-- Voxel world mode: the rooms on the lab tileset -- Cinnabar's lab and its
-- three rooms, Fuchsia's meeting room and the Warden's house, the Safari
-- Zone's secret house.
--
-- The drawing: the wall band (34, 35 the pillar that turns the lab's L),
-- a framed picture in it (16/17 over 32/33), the metronome room's row of
-- brackets (48/49, in a band two cells deep there), a vent over each of
-- the lab's three doorways (24/25 over the doorways' 76/77 and 52/53),
-- the meeting room's low partitions (64/65/66 over 34 and their end caps
-- 42/43), the black outside of the lab's L (54), the checker floor (1/38)
-- and the fossil room's striped mat (12/13). What stands:
--
--   walls        lab-white paint over a blue-grey dado, a white cornice,
--                28 tall; the partitions 16; outside the box the side
--                walls, cut toward the camera (the homes' dollhouse)
--   the picture  a framed chart -- three linked rings, a lab's poster
--   brackets     three steel shelf brackets on the face, a bar along them
--   doorways     a steel frame, the dark beyond, a vent grille over each
--   floors       lino squares in two shades; the fossil room's rubber mat
--   (the black outside, 54, is left to the profile's void rule: claimed,
--   the engine laid a floor under it)
--
-- The furniture is the developer's (data/voxel_heights.lua LAB: the
-- machine banks and shelf ranks as `bookcase`, the benches and tables as
-- `table`, the chairs and stools, the plants, the Warden's five round
-- specimens, his big console as wall): their cells, the benches' aprons
-- and the mat are left open, the lino laid under them.
-- x east, z south, one tile 8 voxels. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/lab_rooms.png", SHEET_W = 8, SHEET_H = 14 }
Kit.MAPS = { CINNABAR_LAB = 1, CINNABAR_LAB_TRADE_ROOM = 1, CINNABAR_LAB_METRONOME_ROOM = 1,
             CINNABAR_LAB_FOSSIL_ROOM = 1, FUCHSIA_MEETING_ROOM = 1, WARDENS_HOUSE = 1,
             SAFARI_ZONE_SECRET_HOUSE = 1 }
-- the Warden's console (87..89 over 28/71/29, 36/24/25/37, 42/34/34/43) is
-- the developer's one 16px block: its cells left to him
local KEEP = { WARDENS_HOUSE = { 8, 11, 4, 7 } }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local PAINT, DADO, TRIM, LINO_A, LINO_B, STEEL, STEEL_DK, DARK, RUBBER, PAPER, INK, RED,
      GLASS, FRAME = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local BAND = { [34] = true, [35] = true, [16] = true, [17] = true, [32] = true, [33] = true,
               [48] = true, [49] = true, [24] = true, [25] = true }
local CAP = { [42] = true, [43] = true }
local TRIMROW = { [64] = true, [65] = true, [66] = true }
local DOORWAY = { [76] = true, [77] = true, [52] = true, [53] = true }
local OPEN = {}
for _, v in ipairs({ 10, 11, 26, 27, 40, 41, 59, 64, 65, 66, 69, 70, 74, 75, 85, 86, 90, 91,
                     2, 3, 4, 5, 18, 19, 20, 21, 58, 72, 73, 80, 81, 82, 83, 84,
                     6, 7, 14, 15, 22, 23, 30, 31, 44, 45, 46, 47, 60, 61, 62, 63,
                     50, 51, 67, 68, 39, 55, 8, 9, 87, 88, 89, 28, 29, 71, 36, 37,
                     -- the lab's black outside: the profile's void rule's
                     54 }) do
  OPEN[v] = true
end
Kit.OPEN = OPEN

local WALL_H, PART_H = 28, 16

local function build(t, mapId)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  local keep = KEEP[mapId]
  local function kept(c, r)
    return keep and c >= keep[1] and c <= keep[2] and r >= keep[3] and r <= keep[4]
  end
  -- what each tile is: "wall", "part" (a partition), "door", "void", "open",
  -- "mat" (the fossil room's), "floor"
  local kind = {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local v = tile(c, r)
      local k = "floor"
      if kept(c, r) then k = "open"
      elseif v == 54 then k = "void"
      elseif DOORWAY[v] then k = "door"
      elseif CAP[v] then k = "part"
      elseif TRIMROW[v] and (CAP[tile(c, r + 1)] or tile(c, r + 1) == 34) then k = "part"
      elseif v == 34 and (TRIMROW[tile(c, r - 1)] or CAP[tile(c - 1, r)] or CAP[tile(c + 1, r)])
             and r > 1 then k = "part"
      elseif BAND[v] then k = "wall"
      elseif OPEN[v] then k = "open"
      elseif v == 12 or v == 13 then k = "mat" end
      kind[r * cols + c] = k
    end
  end
  local function kindAt(x, z)
    if x < 0 or z < 0 or x >= W or z >= D then return nil end
    return kind[floor(z / 8) * cols + floor(x / 8)]
  end
  local function hAt(x, z)
    local k = kindAt(x, z)
    if k == "wall" then return WALL_H end
    if k == "part" then return PART_H end
    return 0
  end

  local function skin(u, y, H)
    if y >= H - 2 then return sw(TRIM, y == H - 1 and 6 or 4) end
    if y <= 1 then return sw(STEEL_DK, 3) end
    if y <= 9 then
      if y == 9 then return sw(TRIM, 5) end
      return sw(DADO, 3 + hash(floor(u / 16), floor(y / 4), 2) % 2)
    end
    return sw(PAINT, 4 + (hash(u, y, 4) % 23 == 0 and -1 or 0))
  end

  -- the framed chart on the face, centred on the picture's 16 wide cell
  local function chart(lx, y)
    if lx < 1 or lx > 14 or y < 12 or y > 24 then return nil end
    if lx == 1 or lx == 14 or y == 12 or y == 24 then return sw(FRAME, 4) end
    -- three rings linked in a triangle
    for _, c in ipairs({ { 5, 21 }, { 10, 21 }, { 7.5, 16 } }) do
      local d = sqrt((lx - c[1]) ^ 2 + (y - c[2]) ^ 2)
      if d >= 1.4 and d <= 2.4 then return sw(INK, 3) end
    end
    if (y == 21 and lx >= 6 and lx <= 9) then return sw(RED, 4) end
    return sw(PAPER, 5)
  end

  local function wall(x, y, z, H)
    if y >= H then return nil end
    if y == H - 1 then return sw(TRIM, 5 + hash(floor(x / 16), 0, floor(z / 16)) % 2) end
    local southOpen = hAt(x, z + 1) <= y
    local westOpen, eastOpen = hAt(x - 1, z) <= y, hAt(x + 1, z) <= y
    if southOpen then
      local v = tile(floor(x / 8), floor(z / 8))
      -- the picture: its cell is the 16/17 pair's (the tile above 32/33)
      local c = floor(x / 8)
      local r = floor(z / 8)
      local pc
      for rr = r, r - 1, -1 do
        for cc = c, c - 1, -1 do
          if tile(cc, rr) == 16 and tile(cc + 1, rr) == 17 then pc = cc end
        end
      end
      if pc then
        local p = chart(x - pc * 8, y)
        if p then return p end
      end
      -- the brackets (48/49 in the band's middle row): a bar at 18, a
      -- bracket under it every 16
      local br = false
      for rr = r - 2, r do if tile(c, rr) == 48 or tile(c, rr) == 49 then br = true end end
      if br then
        if y == 18 then return sw(STEEL, 6) end
        if x % 16 == 8 and y >= 14 and y < 18 then return sw(STEEL_DK, 4) end
      end
      -- the vent over a doorway (24/25): a grille of slots
      for rr = r - 1, r do
        local vv = tile(c, rr)
        if vv == 24 or vv == 25 then
          if y >= 20 and y <= 25 then
            if y == 20 or y == 25 or x % 8 == 0 then return sw(STEEL_DK, 4) end
            return sw((y % 2 == 0) and DARK or STEEL, 4)
          end
        end
      end
      return skin(x, y, H)
    end
    if westOpen or eastOpen then return skin(z, y, H) end
    return sw(PAINT, 3)
  end

  local function doorway(x, y, z)
    -- the doorway pair runs two tiles wide (76/77): a steel frame, the dark
    -- beyond it, the vent above is the wall's
    local c, r = floor(x / 8), floor(z / 8)
    local c0 = (tile(c, r) == 77 or tile(c, r) == 53) and c - 1 or c
    local lx = x - c0 * 8
    if y >= WALL_H then return nil end
    if y >= 20 then return wall(x, y, z, WALL_H) end
    if lx <= 1 or lx >= 14 then
      if y <= 1 then return sw(STEEL_DK, 3) end
      return sw(STEEL, (lx == 1 or lx == 14) and 5 or 4)
    end
    if y == 19 then return sw(STEEL, 5) end                         -- the head
    local lz = z % 16
    if lz <= 9 then return sw(DARK, 2 + (y <= 1 and 0 or 1)) end
    if y == 0 then return sw(STEEL, 3) end                          -- the sill
    return nil
  end

  local function lino(x, z)
    local gx, gz = floor(x / 8), floor(z / 8)
    if x % 8 == 0 or z % 8 == 0 then return sw(LINO_B, 2) end
    local a = (gx + gz) % 2 == 0
    return sw(a and LINO_A or LINO_B, 4 + hash(gx, 0, gz) % 2 + (hash(x, 1, z) % 13 == 0 and -1 or 0))
  end
  local function mat(x, z)
    if z % 3 == 0 then return sw(RUBBER, 2) end
    return sw(RUBBER, 4 + hash(floor(x / 4), 2, floor(z / 3)) % 2)
  end

  local function at(x, y, z)
    if y < 0 then return nil end
    if x < 0 or x >= W then
      if x < -5 or x > W + 4 or z < 0 or z >= D then return nil end
      local k = kindAt(x < 0 and 0 or W - 1, z)
      if k == "void" or k == nil then return nil end
      local H = Lib.sideH(z)
      if y > H then return nil end
      if y == H then return sw(TRIM, 5) end
      return skin(z, y, H + 1)
    end
    if z < 0 or z >= D then return nil end
    local k = kindAt(x, z)
    if k == "void" then return nil end
    if k == "wall" then return wall(x, y, z, WALL_H) end
    if k == "part" then return wall(x, y, z, PART_H) end
    if k == "door" then return doorway(x, y, z) end
    if y > 0 then return nil end
    local v = tile(floor(x / 8), floor(z / 8))
    if v == 39 or v == 55 then return nil end                       -- the doormat, drawn
    if v == 8 or v == 9 then return nil end                         -- the benches' aprons
    if k == "mat" then return mat(x, z) end
    return lino(x, z)
  end
  return at, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not a lab room: " .. tostring(mapId) end
  local at, W, D = build(t, mapId)
  local open = OPEN
  if KEEP[mapId] then
    -- the kept block's own band tiles (24/25, 34, 42/43) are his too
    local k = KEEP[mapId]
    open = {}
    for v in pairs(OPEN) do open[v] = true end
    local m, why = Lib.model(Kit, sp, t, at, open)
    if not m then return nil, why end
    local cols = #t.tiles[1]
    for r = k[3], k[4] do
      for c = k[1], k[2] do m.claimMask[r * cols + c + 1] = false end
    end
    m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, -5, W + 4, D - 1, WALL_H + 1
    return m
  end
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, -5, W + 4, D - 1, WALL_H + 1
  return m
end

return Kit
