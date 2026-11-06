-- Voxel world mode: two rooms of Cerulean INSIDE -- the Bike Shop and the
-- house of the man who tells of the badges -- read off their own plans.
--
--   BIKE_SHOP (CLUB tileset)
--     6                 the wall           white plaster, a grey skirting
--     1-3 over 17-19    bikes on the wall  two bicycles hung on the north wall
--     11 12 14 / 27 28 9  a bike for sale  a bicycle standing on the floor
--     7/8, 54 16 16 5, 23/24  the counter  an L of laminate on a blue front
--     29 13 / 21 22     a price board      an easel board on legs
--     15 31 30          the floor          grey and white vinyl in a checker
--   CERULEAN_BADGE_HOUSE (SHIP tileset)
--     16, 18/19         the wall           pale panelling, a blue dado rail
--     14 15 / 30 31     the back door      a blue door in the north wall
--     9..12 / ... 59 60 the table          a white table, a drawer, a cup
--     7 8 / 23 24       the stool          a round stool (its own template:
--                                          the cell is walkable, a seat)
--     72 73 / 88 89     a bin              a waste bin
--     13 29             the floor          a checker of white and grey tiles
--
-- On the homes' shell (lib/HomeLib.lua): the wall 28 tall and 5 thick
-- outside the box, the side walls cut down toward the camera, no south
-- wall, no ceiling. 128 x 128 voxels, x east, z south. The mats stay drawn.
-- Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/cerulean_rooms.png", SHEET_W = 8, SHEET_H = 20,
              SEAT_H = Lib.SEAT_H }
-- the Good Rod fisherman's house in Fuchsia is drawn from the badge
-- house's very plan (the same SHIP tiles, tile for tile): built the same
Kit.MAPS = { BIKE_SHOP = 1, CERULEAN_BADGE_HOUSE = 2, BILLS_HOUSE = 3,
             FUCHSIA_GOOD_ROD_HOUSE = 2 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw, hash = Lib.sw, Lib.hash
local WALL_H, WALL_D = Lib.WALL_H, Lib.WALL_D
local WALL, WALL_DK, VINYL_A, VINYL_B, COUNTER, TOP, TYRE, CHROME, FRAME_R, FRAME_B,
      SADDLE, WOOD, WOOD_DK, DOOR, BRASS, PAPER, DARK, CHINA, LEAF, RAIL =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19

local function reader(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local function find(pat)
    local out = {}
    for r = 0, rows - #pat do
      for c = 0, cols - #pat[1] do
        local ok = true
        for i = 1, #pat do
          for j = 1, #pat[1] do
            if tile(c + j - 1, r + i - 1) ~= pat[i][j] then ok = false break end
          end
          if not ok then break end
        end
        if ok then out[#out + 1] = { c = c, r = r } end
      end
    end
    return out
  end
  return tile, find
end

-- a bicycle side on: its length along x from bx, wheels on the floor at
-- z = bz (two voxels thick), frame `row`. u along, y up, w across.
local function bicycle(u, y, w, row)
  if u < 0 or u > 22 then return nil end
  local aw = abs(w)
  -- the wheels: rings of radius 5, tyres black, spokes chrome
  for _, cu in ipairs({ 5, 17 }) do
    local du, dy = u - cu, y - 5
    local d = sqrt(du * du + dy * dy)
    if aw <= 0.5 then
      if d >= 4.2 and d <= 5.4 then return sw(TYRE, 3) end
      if d <= 0.8 then return sw(CHROME, 4) end
      if d < 4.2 and (abs(du) < 0.5 or abs(dy) < 0.5) then return sw(CHROME, 5) end
    end
  end
  if aw > 0.5 then
    -- the pedals and the handlebar stick out sideways
    if aw <= 2.5 and y == 12 and u >= 17 and u <= 18 then return sw(DARK, 3) end
    if aw <= 1.5 and y == 4 and u == 11 then return sw(DARK, 3) end
    return nil
  end
  -- the frame: a triangle from the crank (11, 5) to the saddle post (9, 10)
  -- and the head (16, 10), down the fork to the front hub, the stays back
  local function seg(u0, y0, u1, y1)
    local L = max(abs(u1 - u0), abs(y1 - y0))
    for i = 0, L do
      local su = u0 + (u1 - u0) * i / L
      local sy = y0 + (y1 - y0) * i / L
      if abs(u - su) < 0.6 and abs(y - sy) < 0.6 then return true end
    end
    return false
  end
  if seg(11, 5, 9, 10) or seg(11, 5, 16, 10) or seg(9, 10, 16, 10)
     or seg(16, 10, 17, 5) or seg(11, 5, 5, 5) or seg(9, 10, 5, 5) then
    return sw(row, 4 + (y >= 9 and 1 or 0))
  end
  if y == 11 and u >= 8 and u <= 10 then return sw(SADDLE, 3) end
  if y >= 11 and y <= 12 and u == 16 then return sw(CHROME, 4) end
  if y == 12 and u >= 16 and u <= 18 then return sw(DARK, 3) end
  return nil
end

-- ------------------------------------------------------------ Bike Shop
local function bikeShop(t)
  local tile, find = reader(t)
  local SKIN = Lib.wallSkin({
    skirt = { 2, function() return sw(WALL_DK, 3) end },
    dado = { 3, function() return sw(WALL_DK, 4) end },
    rail = { 4, sw(COUNTER, 4) },
    cornice = { 26, function(u, y) return sw(WALL, ({ 4, 5, 6 })[y - 25] or 6) end },
    field = function(u, y) return sw(WALL, 4 + hash(floor(u / 8), floor(y / 6), 3) % 2) end,
  })
  local hung = find({ { 1, 2, 3 }, { 17, 18, 19 } })
  local floorBikes = find({ { 11, 12, 14 }, { 27, 28, 9 } })
  local boards = find({ { 29, 13 }, { 21, 22 } })
  local CTR = { [7] = true, [8] = true, [54] = true, [16] = true, [5] = true, [23] = true, [24] = true }
  local function isC(x, z)
    if x < 0 or z < 0 or x > 127 or z > 127 then return false end
    return CTR[tile(floor(x / 8), floor(z / 8))] or false
  end
  return function(x, y, z)
    if x < 0 or x > 127 then
      if y > Lib.sideH(z) or z < 0 then return nil end
      return SKIN(z + 5, y)
    end
    -- the north wall, its face at z 10; bicycles hung on it
    if z <= 9 then return SKIN(x + 5, y) end
    for i, p in ipairs(hung) do
      local bx = p.c * 8 + 1
      if z >= 10 and z <= 12 and x >= bx and x <= bx + 22 and y >= 6 then
        local v = bicycle(x - bx, y - 7, z - 11, i == 1 and FRAME_B or FRAME_R)
        if v then return v end
        if z == 10 and y == 19 and (x == bx + 6 or x == bx + 16) then return sw(DARK, 3) end  -- the hooks
      end
    end
    if z == 10 and Lib.proudCourse({ skirt = { 2 }, rail = { 4 }, cornice = { 26 } }, y) then
      return SKIN(x + 5, y)
    end
    -- the counter: laminate on a blue front, a kick set in
    if isC(x, z) then
      if y > 13 then return nil end
      local edge = not (isC(x + 1, z) and isC(x - 1, z) and isC(x, z + 1) and isC(x, z - 1))
      if y >= 12 then return sw(TOP, y == 13 and 6 or 4) end
      if y <= 1 then return edge and nil or sw(DARK, 3) end
      if edge then return sw(COUNTER, 4 + (y == 11 and 1 or 0)) end
      return sw(COUNTER, 2)
    end
    -- the bicycles for sale, side on along x, on a little stand
    for i, p in ipairs(floorBikes) do
      local bx, bz = p.c * 8 + 1, p.r * 8 + 8
      if x >= bx - 1 and x <= bx + 23 and z >= bz - 3 and z <= bz + 3 then
        local v = bicycle(x - bx, y, z - bz, (i % 2 == 0) and FRAME_R or FRAME_B)
        if v then return v end
        if y == 0 and abs(z - bz) <= 1 and (x - bx == 5 or x - bx == 17) then return sw(DARK, 3) end
      end
    end
    -- the price boards: an easel, a white board with lines
    for _, p in ipairs(boards) do
      local bx, bz = p.c * 8, p.r * 8
      local lx, lz = x - bx, z - bz
      if lx >= 3 and lx <= 12 and lz >= 6 and lz <= 10 then
        if y <= 13 and (lx == 4 or lx == 11) and lz == 8 then return sw(WOOD_DK, 3) end
        if y >= 6 and y <= 14 and lz == 7 and lx >= 3 and lx <= 12 then
          if lx == 3 or lx == 12 or y == 6 or y == 14 then return sw(WOOD, 4) end
          if y % 2 == 0 and lx >= 5 and lx <= 10 then return sw(DARK, 4) end
          return sw(PAPER, 6)
        end
      end
    end
    if y > 0 then return nil end
    local v = tile(floor(x / 8), floor(z / 8))
    if v == 10 or v == 26 then return nil end                     -- the mat
    if x % 8 == 0 or z % 8 == 0 then return sw(VINYL_B, 2) end
    local gx, gz = floor(x / 8), floor(z / 8)
    return sw((gx + gz) % 2 == 0 and VINYL_A or VINYL_B, 3 + hash(gx, 0, gz) % 3)
  end
end

-- ------------------------------------------------------- the badge house
local function badgeStool(x, y, z, cx, cz)
  local d = (x - cx) ^ 2 + (z - cz) ^ 2
  if y <= 6 and d <= 1.2 then return sw(CHROME, 4) end
  if y == 0 and d <= 9 then return sw(CHROME, 3) end
  if y >= 6 and y <= 7 and d <= 16 then return sw(y == 7 and DOOR or WOOD_DK, 5) end
  return nil
end

local function badgeHouse(t)
  local tile, find = reader(t)
  local SKIN = Lib.wallSkin({
    skirt = { 2, function() return sw(WOOD_DK, 3) end },
    dado = { 11, function(u, y)
      if u % 8 == 0 then return sw(WALL_DK, 4) end
      return sw(WALL, 4)
    end },
    rail = { 12, sw(RAIL, 4) },
    cornice = { 26, function(u, y) return sw(WALL, ({ 4, 5, 6 })[y - 25] or 6) end },
    field = function(u, y) return sw(WALL, 5 + hash(floor(u / 10), floor(y / 6), 4) % 2) end,
  })
  local door = find({ { 14, 15 }, { 30, 31 } })[1]
  local tbl = find({ { 9, 10, 10, 12 } })[1]
  local bin = find({ { 72, 73 }, { 88, 89 } })[1]
  return function(x, y, z)
    if x < 0 or x > 127 then
      if y > Lib.sideH(z) or z < 0 then return nil end
      return SKIN(z + 5, y)
    end
    -- the north wall, the back door in it
    if door then
      local dx0 = door.c * 8 + 1
      if x >= dx0 and x <= dx0 + 13 and y <= 22 and z <= 10 then
        if x == dx0 or x == dx0 + 13 or y == 22 then
          return (z <= 10) and sw(PAPER, 5) or nil                 -- the frame
        end
        if z >= 8 then return nil end                              -- the reveal
        if x == dx0 + 10 and y == 11 then return sw(BRASS, 5) end
        if y == 6 or y == 16 or x == dx0 + 3 or x == dx0 + 10 then return sw(DOOR, 3) end
        return sw(DOOR, 5)
      end
    end
    if z <= 9 then return SKIN(x + 5, y) end
    if z == 10 and Lib.proudCourse({ skirt = { 2 }, rail = { 12 }, cornice = { 26 } }, y) then
      return SKIN(x + 5, y)
    end
    -- the table: white, a drawer on the front, a cup on it
    if tbl then
      local x0, z0 = tbl.c * 8, tbl.r * 8
      local tx, tz = x - x0, z - z0
      if tx >= 1 and tx <= 30 and tz >= 2 and tz <= 29 then
        if y <= 9 then
          local leg = (tx <= 3 or tx >= 28) and (tz <= 4 or tz >= 27)
          if leg then return sw(WOOD_DK, 3) end
          if y >= 7 and tz >= 27 and tx >= 11 and tx <= 20 then           -- the drawer
            if y == 8 and tx >= 15 and tx <= 16 then return sw(BRASS, 5) end
            return sw(CHINA, 3)
          end
          if y >= 8 and (tz == 2 or tz == 29 or tx == 1 or tx == 30) then return sw(CHINA, 3) end
          return nil
        end
        if y <= 10 then return sw(CHINA, y == 10 and 6 or 4) end
        local cx, cz = tx - 15.5, tz - 9.5
        local cd = cx * cx + cz * cz
        if y >= 11 and y <= 13 and cd <= 3 then
          if y == 13 and cd <= 1.2 then return sw(WOOD_DK, 2) end
          return sw(CHINA, 5)
        end
        if y == 12 and tx == 18 and tz >= 9 and tz <= 10 then return sw(CHINA, 4) end   -- its handle
        return nil
      end
    end
    -- the waste bin
    if bin then
      local cx, cz = bin.c * 8 + 7.5, bin.r * 8 + 8
      local d = (x - cx) ^ 2 + (z - cz) ^ 2
      if y <= 9 and d <= 22 then
        if y == 9 and d <= 14 then return sw(DARK, 2) end
        return sw(CHROME, 3 + (y % 3 == 0 and 1 or 0))
      end
    end
    if y > 0 then return nil end
    local v = tile(floor(x / 8), floor(z / 8))
    if v == 36 or v == 52 then return nil end                     -- the mat
    if x % 8 == 0 or z % 8 == 0 then return sw(VINYL_B, 2) end
    local gx, gz = floor(x / 8), floor(z / 8)
    return sw((gx + gz) % 2 == 0 and VINYL_A or VINYL_B, 3 + hash(gx, 0, gz) % 3)
  end, find
end

-- ----------------------------------------------------- Bill's cottage
--   BILLS_HOUSE (INTERIOR tileset)
--     16                the wall           white panelling, a grey skirting
--     7..10 / ... 55..58  a cell separator  a steel drum on a plinth, a domed
--                                          glass hood, a porthole and dials
--                                          on its front (where Bill turned
--                                          himself into a Pokemon)
--     37/38 over 53/54  the pipe           a steel pipe between the two
--     11..14 / 27..30 / 43 44 91 92  the desk  his desk: the PC, a keyboard,
--                                          papers, a mug
--     59 60             the chair          a desk chair (its own template:
--                                          the cell is walkable, a seat)
--     31 / 69           the floor          oak parquet in a herringbone
local billsFloor
local function billsChair(x, y, z, cx, cz)
  local dx, dz = x - cx, z - cz
  if y == 0 and dx * dx + dz * dz <= 12 then return (abs(dx) < 1 or abs(dz) < 1) and sw(DARK, 3) or nil end
  if y <= 6 and dx * dx + dz * dz <= 1.2 then return sw(CHROME, 4) end
  if y == 7 and abs(dx) <= 4 and abs(dz) <= 4 then return sw(FRAME_B, 4) end
  if y >= 8 and y <= 15 and dz >= 4 and dz <= 5 and abs(dx) <= 4 then return sw(FRAME_B, 3 + (y == 15 and 2 or 0)) end
  return nil
end

local function billsHouse(t)
  local tile, find = reader(t)
  local SKIN = Lib.wallSkin({
    skirt = { 2, function() return sw(WALL_DK, 3) end },
    dado = { 11, function(u, y)
      if u % 12 == 0 then return sw(WALL_DK, 4) end
      return sw(WALL, 4)
    end },
    rail = { 12, sw(CHROME, 4) },
    cornice = { 26, function(u, y) return sw(WALL, ({ 4, 5, 6 })[y - 25] or 6) end },
    field = function(u, y) return sw(WALL, 5 + hash(floor(u / 10), floor(y / 6), 5) % 2) end,
  })
  local pods = find({ { 7, 8, 9, 10 } })
  local desk = find({ { 11, 12, 13, 14 } })[1]
  return function(x, y, z)
    if x < 0 or x > 127 then
      if y > Lib.sideH(z) or z < 0 then return nil end
      return SKIN(z + 5, y)
    end
    -- the separators: a drum r 13, a dome of glass, a porthole on the front
    for _, p in ipairs(pods) do
      local cx, cz = p.c * 8 + 16, p.r * 8 + 24
      local dx, dz = x - cx, z - cz
      local r = math.sqrt(dx * dx + dz * dz)
      if r <= 14.5 then
        if y <= 2 then return sw(DARK, 3 + (r > 13.5 and 1 or 0)) end          -- the plinth
        if y <= 22 and r <= 13 then
          if r > 12 then
            -- the porthole and two dials on the front (south)
            if dz > 10 and abs(dx) <= 4 and y >= 10 and y <= 18 then
              local pr = math.sqrt(dx * dx + (y - 14) ^ 2)
              if pr <= 3 then return sw(DOOR, 6) end
              if pr <= 4.2 then return sw(CHROME, 6) end
            end
            if dz > 10 and y == 6 and (dx == -6 or dx == 6) then return sw(FRAME_R, 5) end
            if y == 4 or y == 20 then return sw(CHROME, 6) end
            return sw(CHROME, 3 + floor((dx + 13) / 6) % 2 + (dz > 0 and 1 or 0))
          end
          return sw(DARK, 2)
        end
        -- the domed hood
        local hy = y - 22
        if hy >= 1 and r * r + (hy * 2.2) ^ 2 <= 13 * 13 then
          if r * r + (hy * 2.2) ^ 2 >= 11 * 11 then return sw(r <= 3 and CHROME or DOOR, 5 + (hy > 3 and 1 or 0)) end
          return nil
        end
        if y == 23 and r <= 13 then return sw(CHROME, 5) end
      end
    end
    -- the pipe between them, on the wall at y 14..18
    if #pods >= 2 then
      local x0, x1 = pods[1].c * 8 + 30, pods[2].c * 8 + 2
      if x >= x0 and x <= x1 and z >= 12 and z <= 16 then
        local d = (y - 16) ^ 2 + (z - 14) ^ 2
        if d <= 5 then return sw(CHROME, (x % 12 == 0) and 3 or (y >= 16 and 6 or 4)) end
      end
    end
    if z <= 9 then return SKIN(x + 5, y) end
    if z == 10 and Lib.proudCourse({ skirt = { 2 }, rail = { 12 }, cornice = { 26 } }, y) then
      return SKIN(x + 5, y)
    end
    -- the desk: z 66..79, the PC on it
    if desk then
      local tx, tz = x - desk.c * 8, z - desk.r * 8
      if tx >= 1 and tx <= 30 and tz >= 2 and tz <= 15 then
        if y <= 9 then
          if tx <= 2 or tx >= 29 then return sw(WOOD_DK, 3) end
          if tx >= 18 and tx <= 28 then                                     -- the drawers
            if tz == 15 and (y == 3 or y == 7) and tx >= 22 and tx <= 24 then return sw(BRASS, 5) end
            if tz == 15 and (y == 5 or y == 9) then return sw(WOOD_DK, 3) end
            return sw(WOOD, 4)
          end
          if y >= 8 then return sw(WOOD, 4) end
          return nil
        end
        if y == 10 then return sw(WOOD, 6) end
        -- the monitor: a beige box, the screen to the south, a glow
        if tx >= 17 and tx <= 27 and tz >= 3 and tz <= 11 and y <= 20 then
          if tz == 11 and tx >= 19 and tx <= 25 and y >= 13 and y <= 18 then return sw(DOOR, 6) end
          return sw(TOP, 4 + (y == 20 and 1 or 0))
        end
        if y == 11 and tx >= 17 and tx <= 27 and tz >= 13 and tz <= 14 then return sw(DARK, 3 + tx % 2) end   -- keyboard
        if y == 11 and tx >= 4 and tx <= 13 and tz >= 4 and tz <= 12 then              -- papers
          if (tz % 2 == 0) and tx >= 5 and tx <= 12 then return sw(DARK, 5) end
          return sw(PAPER, 6)
        end
        local mx, mz = tx - 8.5, tz - 13.5
        if y >= 11 and y <= 13 and mx * mx + mz * mz <= 2 then return sw(y == 13 and DARK or CHINA, 4) end
        return nil
      end
    end
    if y > 0 then return nil end
    local v = tile(floor(x / 8), floor(z / 8))
    if v == 70 or v == 71 then return nil end                     -- the mat
    return billsFloor(x, z)
  end
end

-- oak parquet in a herringbone of 2 x 6 blocks
billsFloor = function(x, z)
    local bx = floor((x + z) / 6)
    local by = floor((x - z) / 6)
    local alt = (bx + by) % 2
    if (alt == 0 and (x + z) % 6 == 0) or (alt == 1 and (x - z) % 6 == 0) then return sw(WOOD_DK, 4) end
    return sw(WOOD, 4 + hash(bx, by, 7) % 3)
end

function Kit.model(sp, t, mapId)
  local v = Kit.MAPS[mapId]
  if not v then return nil, "not a Cerulean room: " .. tostring(mapId) end
  if v == 3 and t.home == "seat" then
    local x0, z0 = t.seatAt[1] * 8, t.seatAt[2] * 8
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      local v = billsChair(x, y, z, 7.5, 9)
      if v then return v end
      if y == 0 then return billsFloor(x + x0, z + z0) end
      return nil
    end, {})
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 15, 16
    m.standH = Kit.SEAT_H
    return m
  end
  if v == 3 then
    return Lib.model(Kit, sp, t, billsHouse(t), { [70] = true, [71] = true,
                                                  [43] = true, [44] = true, [59] = true, [60] = true })
  end
  if v == 2 and t.home == "seat" then
    -- the round stool alone, at the sitter's height
    local x0, z0 = t.seatAt[1] * 8, t.seatAt[2] * 8
    local m, why = Lib.model(Kit, sp, t, function(x, y, z)
      return badgeStool(x, y, z, 7.5, 8)
    end, {})
    if not m then return nil, why end
    m.W, m.xmin, m.xmax, m.zmin, m.zmax, m.ytop = 16, 0, 15, 0, 15, 9
    m.standH = Kit.SEAT_H
    return m
  end
  local at
  if v == 1 then
    at = bikeShop(t)
    return Lib.model(Kit, sp, t, at, { [10] = true, [26] = true })
  end
  at = badgeHouse(t)
  return Lib.model(Kit, sp, t, at, { [36] = true, [52] = true,
                                     [7] = true, [8] = true, [23] = true, [24] = true })
end

return Kit
