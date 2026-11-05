-- Voxel world mode: Celadon Mansion (1F..3F, the roof) and the chief's
-- house -- the MANSION tileset's rooms.
--
-- The drawing: the north band (80) the rooms' wall, the white partitions
-- (74/75 running north-south with their feet 90/91 and heads 72/73 and
-- 88/89; 76/77 over 30 running east-west, 93 its end, 22/23 a doorway
-- through it), the black outside (16), the hall's dotted floor (1), the
-- rooms' carpet (17, 5 its edge), the stairs (12/13 over 28/29 up, 10/11
-- over 26/27 down), a door in the north wall (81/82 over 83/84). On the
-- roof the same partitions are the parapets, 78/79/44/92 their corners,
-- 15 over 31 the iron rail (42/43 and 33/49 its posts), and the shed
-- with the door to the roof room (38/39/41 over 54/55/57 its roof, 48/30
-- its walls, 81..84 the door, 6/7 a plaque). What stands:
--
--   walls        cream plaster on an oak wainscot under a white cornice;
--                the north wall 28 tall, the partitions 20 so the room
--                behind one still shows; outside the box the side walls,
--                cut toward the camera (the homes' dollhouse)
--   floors       pale marble in squares in the hall, a sage carpet with a
--                darker border in the rooms
--   stairs       stone steps up into the north wall; the ones down a well
--                with a rail round it
--   the roof     concrete pavers, parapets 12 tall in the walls' plaster,
--                a black iron rail; the shed a plastered box with a flat
--                roof slab, its door and the plaque on its south face
--
-- The furniture stays the profile's (MANSION `bookcase`, `table`, `stool`,
-- `prop` in data/voxel_heights.lua): the display cabinets, the tables and
-- desks, the stools, the palms; their cells and the mat are left open.
-- x east, z south, one tile 8 voxels. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/mansion_rooms.png", SHEET_W = 8, SHEET_H = 16 }
Kit.MAPS = { CELADON_MANSION_1F = "floor", CELADON_MANSION_2F = "floor",
             CELADON_MANSION_3F = "floor", CELADON_MANSION_ROOF = "roof",
             CELADON_CHIEF_HOUSE = "floor" }

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local sw = Lib.sw
local PLASTER, OAK, OAK_DK, TRIM, MARBLE, MARBLE_V, CARPET, CARPET_DK, STONE, IRON,
      PAVER, PAVER_DK, DOOR, BRASS, DARK, GLASS = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
      12, 13, 14, 15
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local NORTH = { [80] = true }
local PART = { [74] = true, [75] = true, [72] = true, [73] = true, [88] = true, [89] = true,
               [90] = true, [91] = true, [76] = true, [77] = true, [30] = true, [93] = true,
               [78] = true, [79] = true, [44] = true, [92] = true }
local DOORWAY = { [22] = true, [23] = true }
local UP = { [12] = true, [13] = true, [28] = true, [29] = true }
local DOWN = { [10] = true, [11] = true, [26] = true, [27] = true }
local DOOR_T = { [81] = true, [82] = true, [83] = true, [84] = true }
local RAIL = { [15] = true, [31] = true, [42] = true, [43] = true, [33] = true, [49] = true }
local SHED_TOP = { [38] = true, [39] = true, [41] = true, [54] = true, [55] = true, [57] = true }
local SHED_WALL = { [48] = true, [6] = true, [7] = true }
-- left to the profile: the cabinets, tables, desks, stools, palms; the
-- desks' aprons drawn in the floor; the mat
local OPEN = {}
for _, v in ipairs({ 21, 34, 35, 40, 45, 46, 47, 50, 51, 56, 61, 62, 63, 87,
                     36, 37, 38, 39, 41, 52, 53, 54, 55, 57, 58, 59, 60, 64, 65, 66, 67,
                     2, 3, 18, 19, 85, 86, 8, 9, 24, 25, 68, 69, 70, 71, 4, 20 }) do
  OPEN[v] = true
end

local NORTH_H, PART_H, PARAPET_H, RAIL_H, SHED_H = 28, 20, 12, 12, 24

local function build(t, style)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  local roof = style == "roof"
  local function tileAt(x, z) return tile(floor(x / 8), floor(z / 8)) end

  -- on the roof the shed's own top and walls; on the floors those tiles
  -- are furniture (the shed is drawn with the tables' tiles)
  local function wallH(v)
    if NORTH[v] then return roof and PARAPET_H or NORTH_H end
    if PART[v] then return roof and PARAPET_H or PART_H end
    return nil
  end
  -- the shed: its footprint (cells of 38..57, 48, 30, 81..84, 6/7 inside
  -- the box the top spans), found once
  local shed
  if roof then
    for r = 0, rows - 1 do
      for c = 0, cols - 1 do
        if tile(c, r) == 38 then shed = shed or { c0 = c, r0 = r } end
      end
    end
    if shed then
      local c1 = shed.c0
      while tile(c1 + 1, shed.r0) == 39 or tile(c1 + 1, shed.r0) == 41 do c1 = c1 + 1 end
      local r1 = shed.r0
      while tile(shed.c0, r1 + 1) and tile(shed.c0, r1 + 1) ~= 1 do r1 = r1 + 1 end
      shed.x0, shed.x1, shed.z0, shed.z1 = shed.c0 * 8, c1 * 8 + 7, shed.r0 * 8, r1 * 8 + 7
    end
  end
  local function inShed(x, z)
    return shed and x >= shed.x0 and x <= shed.x1 and z >= shed.z0 and z <= shed.z1
  end

  -- a wall's skin: oak wainscot to 10, a rail, plaster, a white cornice
  local function skin(u, y, H)
    if y >= H - 2 then return sw(TRIM, y == H - 1 and 6 or 4) end
    if roof then
      if y <= 1 then return sw(PAVER_DK, 3) end
      return sw(PLASTER, 3 + hash(floor(u / 6), floor(y / 4), 2) % 2)
    end
    if y <= 1 then return sw(OAK_DK, 3) end
    if y <= 10 then
      local m = u % 12
      if m == 0 or y == 2 or y == 10 then return sw(OAK_DK, 4) end     -- the panels' frames
      return sw(OAK, 3 + (m == 1 and 2 or 0) + (y == 3 and 1 or 0))
    end
    if y == 11 then return sw(OAK, 6) end                              -- the rail
    return sw(PLASTER, 4 + (hash(u, y, 4) % 19 == 0 and -1 or 0))
  end
  local function solidH(x, z)
    if x < 0 or z < 0 or x >= W or z >= D then return 0 end
    local v = tileAt(x, z)
    return wallH(v) or 0
  end
  local function wall(x, y, z, H)
    if y >= H then return nil end
    if y == H - 1 then return sw(TRIM, 5 + hash(floor(x / 8), 0, floor(z / 8)) % 2) end
    if solidH(x, z + 1) < H and solidH(x, z + 1) <= y then return skin(x, y, H) end
    if solidH(x + 1, z) <= y or solidH(x - 1, z) <= y then return skin(z, y, H) end
    if solidH(x, z - 1) <= y then return skin(x, y, H) end
    return sw(PLASTER, 3)
  end

  -- the floors
  local function marble(x, z)
    local gx, gz = x % 16, z % 16
    if gx == 0 or gz == 0 then return sw(MARBLE_V, 4) end
    local vein = (x * 3 + z * 5 + hash(floor(x / 16), 1, floor(z / 16)) * 7) % 23
    if vein == 0 then return sw(MARBLE_V, 6) end
    return sw(MARBLE, 4 + hash(floor(x / 16), 0, floor(z / 16)) % 3)
  end
  local function carpet(x, z)
    -- a darker border a cell's quarter wide where the carpet meets anything
    -- that is not carpet
    local function isC(xx, zz)
      local v = tileAt(xx, zz)
      return v == 17 or v == 5 or (v and OPEN[v] and v ~= 4 and v ~= 20)
    end
    local edge = not (isC(x - 3, z) and isC(x + 3, z) and isC(x, z - 3) and isC(x, z + 3))
    if edge then return sw(CARPET_DK, 4) end
    return sw(CARPET, 3 + hash(floor(x / 2), floor(z / 2), 3) % 3 + ((x + z) % 4 == 0 and 1 or 0))
  end
  local function paver(x, z)
    local gx, gz = x % 16, z % 16
    if gx == 0 or gz == 0 then return sw(PAVER_DK, 3) end
    return sw(PAVER, 3 + hash(floor(x / 16), 2, floor(z / 16)) % 3 + (hash(x, 3, z) % 9 == 0 and -1 or 0))
  end
  local function floorAt(x, z, v)
    if roof then return paver(x, z) end
    if v == 17 then return carpet(x, z) end
    if v == 5 then return (z % 8 < 4) and carpet(x, z) or marble(x, z) end
    return marble(x, z)
  end

  -- the stairs: four steps in the cell pair's two rows, rising north;
  -- the well down: a rail round it, the steps going down in the dark
  local function stairs(x, y, z, v)
    local c, r = floor(x / 8), floor(z / 8)
    local r0 = (UP[tile(c, r - 1)] or DOWN[tile(c, r - 1)]) and r - 1 or r
    local lz = z - r0 * 8                             -- 0..15, north to south
    if UP[v] then
      local step = 3 - floor(lz / 4)                  -- 3 at the north
      local top = 6 * (step + 1)
      if y >= top then return nil end
      if y == top - 1 then return sw(STONE, 6) end
      if lz % 4 == 3 then return sw(STONE, 2) end   -- the riser's shadow
      return sw(STONE, 4 + hash(c, step, 5) % 2)
    end
    -- down: the rail on the well's east and west, the steps fading
    local c0 = DOWN[tile(c - 1, r)] and c - 1 or c
    local lx = x - c0 * 8
    if (lx == 0 or lx == 15) and lz >= 2 and y <= 9 then
      if y == 9 then return sw(OAK, 5) end
      if lz % 4 == 2 then return sw(IRON, 4) end
      return nil
    end
    if y > 0 then return nil end
    if lz % 4 == 0 then return sw(STONE, 5) end      -- each step's nose
    return sw(STONE, 1 + floor(lz / 4))              -- darker deeper, to the north
  end

  local function door(x, y, z, H, x0)
    -- a panelled door on the wall's south face, x0..x0+15
    local lx = x - x0
    if lx >= 2 and lx <= 13 and y <= 21 then
      if lx == 2 or lx == 13 or y == 21 then return sw(TRIM, 5) end      -- the frame
      if lx == 11 and y == 10 then return sw(BRASS, 6) end               -- the knob
      if (lx == 4 or lx == 11) and y >= 3 and y <= 18 then return sw(DOOR, 3) end
      if (y == 3 or y == 11 or y == 18) and lx > 3 and lx < 12 then return sw(DOOR, 3) end
      return sw(DOOR, 4 + (y > 11 and 1 or 0))
    end
    return nil
  end

  local function at(x, y, z)
    if y < 0 then return nil end
    -- the side walls outside the box, where the room reaches the edge
    if x < 0 or x >= W then
      if x < -5 or x > W + 4 or z < 0 or z >= D then return nil end
      local v = tileAt(x < 0 and 0 or W - 1, z)
      if v == 16 or v == nil then return nil end
      local H = roof and PARAPET_H or Lib.sideH(z)
      if y > H then return nil end
      if y == H then return sw(TRIM, 5) end
      return skin(z, y, H + 1)
    end
    if z < 0 or z >= D then return nil end
    local v = tileAt(x, z)
    if v == 16 then return nil end                                     -- outside
    -- the roof's shed
    if roof and inShed(x, z) then
      local lz = z - shed.z0
      if y > SHED_H + 1 then return nil end
      if y >= SHED_H then
        -- the flat roof slab, a voxel proud all round
        return sw(TRIM, (y == SHED_H + 1) and 5 or 3)
      end
      if z == shed.z1 then
        if DOOR_T[v] then
          local d0 = floor(x / 8) * 8
          if DOOR_T[tileAt(x - 8, z)] then d0 = d0 - 8 end
          local dv = door(x, y, z, SHED_H, d0)
          if dv then return dv end
        end
        if (v == 6 or v == 7) and y >= 8 and y <= 14 then
          local p0 = (tileAt(x - 8, z) == 6) and floor(x / 8) * 8 - 8 or floor(x / 8) * 8
          local lx = x - p0
          if lx >= 3 and lx <= 12 then
            if y == 8 or y == 14 or lx == 3 or lx == 12 then return sw(BRASS, 4) end
            if y % 2 == 1 and lx >= 5 and lx <= 10 then return sw(DARK, 3) end
            return sw(TRIM, 6)
          end
        end
      end
      if x == shed.x0 or x == shed.x1 or z == shed.z0 or z == shed.z1 then
        local u = (z == shed.z1 or z == shed.z0) and x or z
        if y <= 1 then return sw(PAVER_DK, 2) end
        return sw(PLASTER, 4 + hash(floor(u / 8), floor(y / 6), 7) % 2)
      end
      return sw(PLASTER, 3)
    end
    if DOOR_T[v] and not roof then
      -- the door in the north wall: the wall, the door on its face
      local d0 = floor(x / 8) * 8
      if DOOR_T[tileAt(x - 8, z)] then d0 = d0 - 8 end
      if y >= NORTH_H then return nil end
      local lzs = z % 16
      if lzs == 15 then
        local dv = door(x, y, z, NORTH_H, d0)
        if dv then return dv end
      end
      if y == NORTH_H - 1 then return sw(TRIM, 5) end
      return skin(x, y, NORTH_H)
    end
    local H = wallH(v)
    if H then return wall(x, y, z, H) end
    if DOORWAY[v] then
      -- an opening through the partition: the lintel over it
      if y >= PART_H then return nil end
      if y >= 17 then return (y == PART_H - 1) and sw(TRIM, 5) or skin(x, y, PART_H) end
      if y == 0 then return sw(OAK_DK, 4) end                          -- the threshold
      return nil
    end
    if RAIL[v] then
      -- the iron rail: a top bar, two lower bars, a baluster every four,
      -- a post at each end piece
      local post = v == 42 or v == 43 or v == 33 or v == 49
      local lz = z % 16
      if lz >= 6 and lz <= 9 then
        if post and (x % 8 >= 2 and x % 8 <= 5) and y <= RAIL_H then
          return sw(IRON, 3 + (y == RAIL_H and 2 or 0))
        end
        if lz >= 7 and lz <= 8 then
          if y == RAIL_H - 1 then return sw(IRON, 5) end
          if (y == 4 or y == 1) then return sw(IRON, 3) end
          if x % 4 == 0 and y < RAIL_H - 1 then return sw(IRON, 2) end
        end
      end
      if y > 0 then return nil end
      return paver(x, z)
    end
    if UP[v] or DOWN[v] then return stairs(x, y, z, v) end
    if y > 0 then return nil end
    if v == 4 or v == 20 then return nil end                           -- the mat, drawn
    -- the carpet runs on under the furniture: its cells are the profile's,
    -- but the drawn floor beside a palm's thin standee would show
    if OPEN[v] then return floorAt(x, z, 17) end
    return floorAt(x, z, v)
  end
  return at, W, D
end

function Kit.model(sp, t, mapId)
  local style = Kit.MAPS[mapId]
  if not style then return nil, "not the Mansion: " .. tostring(mapId) end
  local at, W, D = build(t, style)
  local open = OPEN
  if style == "roof" then
    -- on the roof the table's tiles are the shed's, built here
    open = { [4] = true, [20] = true }
  end
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, -5, W + 4, D - 1, NORTH_H + 1
  return m
end

return Kit
