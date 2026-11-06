-- Voxel world mode: the FACILITY rooms inside -- the Power Plant, Silph Co.'s
-- floors -- read off their own plans.
--
-- The tileset draws a few parts over and over:
--
--   1                  the floor            pale terrazzo in two tones
--   42, 45/46          a partition's top    \
--   43/44              its side             |  a partition wall, 20 tall,
--   58, 59/60          its lit face         /  dark coping, a blue skirting
--   87/89              the outer north wall the building's wall band, 28 tall
--   86/88              Silph's lift doors   steel sliding doors in the band
--   13/14 .. 74/75 .. 76/77   a cabinet     a steel equipment cabinet: green
--                                           screens and dials on its front
--   13 2 2 14 / 29 53 53 30 / 68 69 69 68   a desk: grey laminate, a steel
--                                           frame, legs at the 68/69 row
--   9/10 over 25/26    a terminal           a console with a lit screen
--   83/84 over 54/38   rubble               the developer's reading: the drifts
--                                           of the Mansion and the Power Plant,
--                                           two rough boulders a cell
--   20                 the lobby island     Silph's foyer: a flat patterned
--                                           carpet the reception terminals ring
--
-- The rest -- plants, warp pads, stairs, lifts -- stays the profile's (left
-- open; the template allows it already stood: `allowSkip`). On the homes'
-- shell: no south wall, no ceiling. cols*8 x rows*8 voxels. Nothing here is
-- extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/facility_kit.png", SHEET_W = 8, SHEET_H = 16 }
Kit.MAPS = { POWER_PLANT = 1, SILPH_CO_1F = 1, SILPH_CO_2F = 1, SILPH_CO_3F = 1,
             SILPH_CO_4F = 1, SILPH_CO_5F = 1, SILPH_CO_6F = 1, SILPH_CO_7F = 1,
             SILPH_CO_8F = 1, SILPH_CO_9F = 1, SILPH_CO_10F = 1,
             ROCKET_HIDEOUT_B1F = 1, ROCKET_HIDEOUT_B2F = 1, ROCKET_HIDEOUT_B3F = 1,
             ROCKET_HIDEOUT_B4F = 1, POKEMON_MANSION_1F = 1, POKEMON_MANSION_2F = 1,
             POKEMON_MANSION_3F = 1, POKEMON_MANSION_B1F = 1, SAFFRON_GYM = 1, CINNABAR_GYM = 1,
             SILPH_CO_11F = 1 }
-- each building its own character on the same parts: the Hideout dark
-- concrete and bare steel with a red stripe, the Mansion old boards and
-- cream panelling gone grey with age, the rest the office's terrazzo
Kit.STYLE = { ROCKET_HIDEOUT_B1F = "hideout", ROCKET_HIDEOUT_B2F = "hideout",
              ROCKET_HIDEOUT_B3F = "hideout", ROCKET_HIDEOUT_B4F = "hideout",
              POKEMON_MANSION_1F = "mansion", POKEMON_MANSION_2F = "mansion",
              POKEMON_MANSION_3F = "mansion", POKEMON_MANSION_B1F = "mansion" }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local FLOOR_A, FLOOR_B, WALL, WALL_DK, TRIM, STEEL, STEEL_DK, SCREEN, LAMP, DESK, WOOD,
      DARK, COPPER, GLASS, RED, YELLOW = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local WALL_H, BAND_H = 20, 28
local C = {}
Kit.CLASS = C
C[1] = "floor"
C[17] = "floor"                      -- the Mansion's second floor tone
for _, t in ipairs({ 42, 45, 46, 43, 44 }) do C[t] = "wall" end
for _, t in ipairs({ 58, 59, 60 }) do C[t] = "face" end
for _, t in ipairs({ 87, 89, 86, 88 }) do C[t] = "band" end
for _, t in ipairs({ 13, 14, 2, 29, 30, 53, 74, 75, 76, 77, 68, 69 }) do C[t] = "furn" end
for _, t in ipairs({ 9, 10, 25, 26 }) do C[t] = "term" end
for _, t in ipairs({ 83, 84, 54, 38 }) do C[t] = "gen" end
C[18] = "furn"                       -- a counter's front (Silph's reception)
C[20] = "island"                     -- Silph's lobby island, a carpet
for _, t in ipairs({ 66, 82 }) do C[t] = "mat" end   -- the exit mat, laid here
                                     -- (or the engine paints it under all)

-- Silph's top floor is drawn on the INTERIOR tileset, not FACILITY: the
-- same building in other tiles. Its plan is read into this tileset's
-- parts and built the same -- 31 the floor (68 its shaded edge), the black
-- partitions (45/46/87 their top run, 89/90 a run north-south, 91/88/92
-- and 52 the lit face), the band (16; 3 over 4 the lift doors; 5/6 over
-- 21/22 a chart hung in it); the dark outside east (47) is left to the
-- profile's void rule, as the lab's is. The president's
-- table, his desk, the sofa, the picture and the warp pad are the
-- profile's. 91/92 are also the desk's and the table's: a face only next
-- to the face row's 88 or under a partition's top.
local INTERIOR = { [31] = 1, [68] = 1, [45] = 42, [46] = 42, [87] = 42, [89] = 42, [90] = 42,
                   [88] = 58, [52] = 58, [16] = 87, [5] = 87, [6] = 87, [21] = 87, [22] = 87,
                   [3] = 86, [4] = 88 }
Kit.TRANSLATE = { SILPH_CO_11F = function(v, up, west, east)
  if v == 91 or v == 92 then
    if west == 88 or east == 88 or up == 45 or up == 46 or up == 89 or up == 90 then return 58 end
    return 0
  end
  return INTERIOR[v] or 0
end }

local function build(t, style)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local function cls(c, r) local v = tile(c, r); return v and C[v] end
  local W, D = cols * 8, rows * 8

  -- the furniture: each connected group of furn tiles is one piece; a group
  -- holding a panel (74..77) is a cabinet, else a desk
  local piece = {}
  local pieces = {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      if cls(c, r) == "furn" and not piece[c + r * cols] then
        local p = { c0 = c, c1 = c, r0 = r, r1 = r, cabinet = false }
        local stack = { { c, r } }
        piece[c + r * cols] = p
        while #stack > 0 do
          local q = table.remove(stack)
          local v = tile(q[1], q[2])
          if v == 74 or v == 75 or v == 76 or v == 77 then p.cabinet = true end
          p.c0, p.c1 = min(p.c0, q[1]), max(p.c1, q[1])
          p.r0, p.r1 = min(p.r0, q[2]), max(p.r1, q[2])
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nc, nr = q[1] + d[1], q[2] + d[2]
            if cls(nc, nr) == "furn" and not piece[nc + nr * cols] then
              piece[nc + nr * cols] = p
              stack[#stack + 1] = { nc, nr }
            end
          end
        end
        pieces[#pieces + 1] = p
      end
    end
  end

  -- a wall column's face: the south side of a wall is lit where the plan
  -- draws the face row (58) below its top row (42)
  local function wallSkin(u, y, h)
    if y >= h then return sw(WALL_DK, 3) end                       -- the coping
    if style == "hideout" then
      if y >= 9 and y <= 10 then return sw(RED, 3) end             -- the stripe
      if u % 12 == 0 or y % 8 == 0 then return sw(STEEL_DK, 2) end
      return sw(STEEL_DK, 4 + hash(floor(u / 12), floor(y / 8), 2) % 2)
    end
    if style == "mansion" then
      if y <= 9 then                                                -- the panelled dado
        if u % 10 == 0 or y == 9 or y <= 1 then return sw(WOOD, 2) end
        return sw(WOOD, 4 + hash(floor(u / 10), 0, 3) % 2)
      end
      if (u * 7 + y * 3) % 23 == 0 then return sw(FLOOR_B, 3) end  -- stains of age
      return sw(DESK, 5 + hash(floor(u / 8), floor(y / 5), 2) % 2)
    end
    if y <= 1 then return sw(TRIM, 3) end
    if y == 2 then return sw(TRIM, 5) end
    if u % 16 == 0 then return sw(WALL, 3) end
    return sw(WALL, 4 + hash(floor(u / 16), floor(y / 6), 2) % 2)
  end

  return function(x, y, z)
    if x < 0 or x >= W or z < 0 or z >= D or y < 0 then return nil end
    local c, r = floor(x / 8), floor(z / 8)
    local v = tile(c, r)
    local k = C[v]
    local lx, lz = x % 8, z % 8
    if not k then return nil end

    if k == "wall" or k == "face" then
      if y > WALL_H then return nil end
      if y == WALL_H then return sw(WALL_DK, 3 + hash(floor(x / 8), 0, floor(z / 8)) % 2) end
      return wallSkin(x + z, y, WALL_H)
    end
    if k == "band" then
      if y > BAND_H then return nil end
      if y == BAND_H then return sw(WALL_DK, 4) end
      -- the lift doors: two steel leaves meeting in the middle, a frame,
      -- the floor lamp over them
      if (v == 86 or v == 88) and y <= 22 then
        local pair = (tile(c - 1, r) == v) and 1 or 0          -- 0 the west leaf
        if y == 22 or (pair == 0 and lx == 0) or (pair == 1 and lx == 7) then return sw(STEEL_DK, 3) end
        if y >= 19 and y <= 20 and ((pair == 0 and lx == 7) or (pair == 1 and lx == 0)) then
          return sw(LAMP, 6)
        end
        if (pair == 0 and lx == 7) or (pair == 1 and lx == 0) then return sw(STEEL_DK, 2) end   -- the seam
        return sw(STEEL, 4 + (y % 6 == 0 and 1 or 0))
      end
      return wallSkin(x, y, BAND_H)
    end
    if k == "furn" then
      local p = piece[c + r * cols]
      local px0, px1 = p.c0 * 8, p.c1 * 8 + 7
      local pz0, pz1 = p.r0 * 8, p.r1 * 8 + 7
      local south = z >= pz1 - 1
      if p.cabinet then
        -- a steel cabinet, 22 tall, its front a panel of screens and dials
        if y > 22 then return nil end
        if x == px0 or x == px1 then return sw(STEEL_DK, 3) end
        if y == 22 then return sw(STEEL, 6) end
        if south then
          local u = x - px0
          if y >= 14 and y <= 19 and u % 16 >= 2 and u % 16 <= 13 then
            return sw(SCREEN, 3 + ((y + u) % 3 == 0 and 2 or 0))               -- screens
          end
          if y >= 8 and y <= 10 and u % 6 == 3 then return sw(LAMP, 5 + (u % 12 == 3 and 1 or 0)) end
          if y <= 2 then return sw(STEEL_DK, 2) end
          return sw(STEEL, 3 + (y % 4 == 0 and 1 or 0))
        end
        return sw(STEEL, 4)
      end
      -- a desk: laminate top at 10, a steel frame, legs at its corners
      if y > 10 then
        -- a monitor and papers on top, by the piece's own hash
        local cx = px0 + 6 + hash(p.c0, p.r0, 4) % max(1, (px1 - px0 - 12))
        if y <= 15 and abs(x - cx) <= 2 and abs(z - (pz0 + 4)) <= 1 then
          if z == pz0 + 5 and y >= 12 then return sw(SCREEN, 4) end
          return sw(STEEL_DK, 3)
        end
        if y == 11 and x >= px1 - 9 and x <= px1 - 3 and z >= pz0 + 3 and z <= pz0 + 8 then
          return sw(FLOOR_A, 6)
        end
        return nil
      end
      if y >= 9 then return sw(DESK, y == 10 and 5 or 3) end
      local leg = (x <= px0 + 1 or x >= px1 - 1) and (z <= pz0 + 1 or z >= pz1 - 1)
      if leg then return sw(STEEL_DK, 3) end
      if y == 0 then return sw(FLOOR_B, 3) end
      return nil
    end
    if k == "island" then
      -- the foyer's island: a blue carpet with a cross pattern, a gold edge
      if y > 0 then return nil end
      local edge = cls(floor((x - 1) / 8), r) ~= "island" and lx == 0
                or cls(floor((x + 1) / 8), r) ~= "island" and lx == 7
                or cls(c, floor((z - 1) / 8)) ~= "island" and lz == 0
                or cls(c, floor((z + 1) / 8)) ~= "island" and lz == 7
      if edge then return sw(YELLOW, 4) end
      local u, w = (x % 8) - 3.5, (z % 8) - 3.5
      if abs(u) < 1 or abs(w) < 1 then return sw(TRIM, 5) end
      return sw(TRIM, 3)
    end
    if k == "mat" then
      if y > 0 then return nil end
      if lx == 0 or lz == 0 then return sw(DARK, 3) end
      return sw(TRIM, 3 + (x + z) % 2)
    end
    if k == "term" then
      local c0 = (v == 9 or v == 25) and c or c - 1
      local r0 = (v == 9 or v == 10) and r or r - 1
      local tx, tz = x - c0 * 8, z - r0 * 8
      if tx < 1 or tx > 14 or tz < 1 or tz > 14 then return (y == 0) and sw(FLOOR_B, 3) or nil end
      if y <= 8 then
        if tz == 14 and y >= 3 and y <= 5 and tx % 3 == 1 then return sw(LAMP, 6) end
        return sw(STEEL, 3 + (y == 8 and 2 or 0))
      end
      if y <= 14 and tz <= 6 + (14 - y) then
        if tz >= 3 + (14 - y) and tx >= 3 and tx <= 12 then return sw(SCREEN, 4 + (y % 2)) end
        if tz >= 2 + (14 - y) then return sw(STEEL_DK, 3) end
      end
      return nil
    end
    if k == "gen" then
      -- rubble: two rough boulders to a cell on a grey ground, as drawn
      local c0 = (v == 83 or v == 54) and c or c - 1
      local r0 = (v == 83 or v == 84) and r or r - 1
      local bx, bz = c0 * 8, r0 * 8
      for i, b in ipairs({ { 4.5, 5.5, 4.2 }, { 11, 10.5, 4.6 } }) do
        local dx, dz = x - bx - b[1], z - bz - b[2]
        local wob = ((x * 7 + z * 13 + y * 5) % 5 - 2) * 0.25
        local rr = b[3] * sqrt(max(0, 1 - (y / (b[3] * 1.2)) ^ 2)) + wob
        if y <= b[3] * 1.2 and dx * dx + dz * dz <= rr * rr then
          if y >= b[3] * 1.2 - 1 then return sw(FLOOR_B, 5) end
          return sw(style == "mansion" and WOOD or STEEL, 2 + hash(floor(x / 2), y, floor(z / 2)) % 3)
        end
      end
      if y == 0 then
        if style == "mansion" then return sw(WOOD, 2 + hash(x, 0, z) % 2) end
        return sw(FLOOR_B, 2 + hash(x, 0, z) % 3)
      end
      return nil
    end
    if k == "floor" then
      if y > 0 then return nil end
      local gx, gz = floor(x / 8), floor(z / 8)
      if style == "mansion" then
        -- old oak boards running east-west, worn, the second tone darker
        local dk = (v == 17) and -2 or 0
        if z % 4 == 0 then return sw(WOOD, 1 + max(0, dk + 1)) end
        local plank = floor(z / 4)
        if (x + plank * 9) % 24 == 0 then return sw(WOOD, 2) end
        return sw(WOOD, 4 + dk + hash(floor((x + plank * 9) / 24), plank, 5) % 2)
      end
      if style == "hideout" then
        if lx == 0 or lz == 0 then return sw(DARK, 4) end
        return sw(STEEL_DK, 3 + hash(gx, 0, gz) % 2 + (hash(x, 1, z) % 9 == 0 and 1 or 0))
      end
      if lx == 0 or lz == 0 then return sw(FLOOR_B, 2) end
      local alt = (gx + gz) % 2
      return sw(alt == 0 and FLOOR_A or FLOOR_B, 4 + hash(gx, 0, gz) % 2 + (hash(x, 1, z) % 7 == 0 and -2 or 0))
    end
    return nil
  end, W, D, function(x, z)
    -- the highest y at() above can answer in this column (emit's colTop),
    -- read off the same branches: a wall to WALL_H, a band to BAND_H, a
    -- cabinet to 22 (a desk's monitor only to 15), a terminal to 14, the
    -- rubble's boulders to 5 (b[3] * 1.2 for the taller, 4.6), and every
    -- flat kind -- floor, mat, island -- its one voxel at 0
    if x < 0 or x >= W or z < 0 or z >= D then return -1 end
    local k = C[tile(floor(x / 8), floor(z / 8))]
    if not k then return -1 end
    if k == "wall" or k == "face" then return WALL_H end
    if k == "band" then return BAND_H end
    if k == "furn" then return 22 end
    if k == "term" then return 14 end
    if k == "gen" then return 5 end
    return 0
  end
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not a facility room: " .. tostring(mapId) end
  local tr = Kit.TRANSLATE[mapId]
  if tr then
    -- read the plan into this tileset's parts (0: not ours, left open)
    local rows = {}
    for r = 1, #t.tiles do
      local src, row = t.tiles[r], {}
      for c = 1, #src do
        row[c] = tr(src[c], t.tiles[r - 1] and t.tiles[r - 1][c], src[c - 1], src[c + 1])
      end
      rows[r] = row
    end
    t = { tiles = rows }
  end
  local at, W, D, colTop = build(t, Kit.STYLE[mapId])
  local open = {}
  for r = 1, #t.tiles do
    for c = 1, #t.tiles[1] do
      local v = t.tiles[r][c]
      if not C[v] then open[v] = true end
    end
  end
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, BAND_H + 1
  m.colTop = colTop
  return m
end

return Kit
