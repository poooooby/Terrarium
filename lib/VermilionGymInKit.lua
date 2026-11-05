-- Voxel world mode: Lt. Surge's Gym in Vermilion INSIDE -- an electrical hall.
--
-- The drawing: a striped floor (17), fifteen bins in rows (11/12 over 27/28,
-- the ones hiding the two switches), the black partitions that close the
-- leader's room off ($0F fill 15, its edges 36/38/39 and 37/53), their lit
-- south faces carrying the switch band (68 5 69 70 .. 71 over 84 86 .. 87:
-- white panels, the round switch housings 69/70), the barred gate through
-- them (13/14 over 29/30 under 41/42), two statues, the mat. What stands:
--
--   the floor     steel deck plates with a diamond tread, a yellow hazard
--                 line round the leader's dais
--   the bins      round steel bins with a lid and ribs, one to a cell --
--                the two that hide the switches look like every other
--   partitions    dark steel walls 24 tall, bolted seams, a lighter cap
--   switch band   on their south face: white panels, a black round switch
--                 in a housing where the drawing draws one, a yellow
--                 warning stripe at the foot
--   the gate      a steel grille in the gap, a lamp over it
--
-- Statues stay the profile's (`gym_statue`), the mat stays drawn. On the
-- homes' shell (no south wall, no ceiling); the side walls are the
-- partitions' own. 160 x 288 voxels, x east, z south. Nothing here is
-- extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/vermilion_gym.png", SHEET_W = 8, SHEET_H = 12 }
Kit.MAPS = { VERMILION_GYM = 1 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local DECK, DECK_DK, STEEL, STEEL_LT, PANEL, SWITCH, YELLOW, BIN, COPPER, LIGHT, RED, GREEN =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local WALLS = { [15] = true, [36] = true, [38] = true, [39] = true, [37] = true, [53] = true }
local FACE = { [68] = true, [5] = true, [69] = true, [70] = true, [71] = true,
               [84] = true, [86] = true, [87] = true }
local GATE = { [41] = true, [42] = true, [13] = true, [14] = true, [29] = true, [30] = true }
local WALL_H = 24

local function build(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  -- the bins: 11/12 over 27/28
  local bins = {}
  for r = 0, rows - 2 do
    for c = 0, cols - 2 do
      if tile(c, r) == 11 and tile(c + 1, r) == 12 and tile(c, r + 1) == 27 then
        bins[#bins + 1] = { c * 8 + 8, r * 8 + 9 }
      end
    end
  end
  -- the partitions' top: chequer plate in panels, a bolted seam between
  local function capAt(x, z)
    if x % 16 == 0 or z % 16 == 0 then return sw(STEEL, 3) end
    local tx, tz = x % 4, z % 4
    if (tx == 1 and tz == 1) or (tx == 3 and tz == 3) then return sw(STEEL_LT, 5) end
    return sw(STEEL_LT, 2 + hash(floor(x / 16), 1, floor(z / 16)) % 3)
  end
  local function at(x, y, z)
    if x < 0 or x >= W or z < 0 or z >= D or y < 0 then return nil end
    local c, r = floor(x / 8), floor(z / 8)
    local v = tile(c, r)
    local lx, lz = x % 8, z % 8
    if WALLS[v] then
      if y > WALL_H then return nil end
      if y == WALL_H then return capAt(x, z) end
      if x % 16 == 0 or (y % 8 == 0) then return sw(STEEL, 2) end          -- seams
      if (x % 16 == 2 or x % 16 == 14) and y % 8 == 4 then return sw(STEEL_LT, 2) end   -- bolts
      return sw(STEEL, 3 + hash(floor(x / 16), floor(y / 8), floor(z / 16)) % 3)
    end
    if FACE[v] then
      -- the face rows stand as the wall too, the panel on their south
      if y > WALL_H then return nil end
      if y == WALL_H then return capAt(x, z) end
      local south = tile(c, r + 1)
      local front = (not FACE[south] and not WALLS[south]) and lz >= 6
      if not front then return sw(STEEL, 3 + hash(floor(x / 16), floor(y / 8), 2) % 3) end
      if lz == 7 and y <= 2 then return sw(((x + y) % 6 < 3) and YELLOW or SWITCH, 4) end
      -- a switch where the drawing draws a housing (the face's upper row)
      local upper = tile(c, r - 1) and FACE[tile(c, r - 1)] and true or false
      local hv = tile(c, upper and r - 1 or r)
      if (hv == 69 or hv == 70) then
        local cx = (hv == 69) and (c * 8 + 8) or (c * 8)
        local d = sqrt((x - cx) ^ 2 + (y - 14) ^ 2)
        if d <= 2.2 and lz == 7 then return sw(SWITCH, 3) end
        if d <= 3.4 and lz >= 6 then return sw(STEEL_LT, 5) end
      end
      if lz == 7 and y >= 6 and y <= 22 then
        if x % 16 == 0 then return sw(STEEL_LT, 3) end
        return sw(PANEL, 4 + (y >= 20 and 1 or 0))
      end
      return sw(STEEL, 4)
    end
    if v == 32 or v == 33 or v == 48 or v == 49 then
      -- Surge's barrier: two hazard-striped posts at the gap's ends, an
      -- arc of current between them at three heights
      if y > WALL_H then return nil end
      local gx = x - 64                               -- the gap runs x 64..95
      if (gx <= 2 or gx >= 29) and lz >= 2 and lz <= 5 then
        if y == WALL_H then return sw(STEEL_LT, 5) end
        return sw(((y + gx) % 6 < 3) and YELLOW or SWITCH, 4)
      end
      if lz >= 3 and lz <= 4 and r % 2 == 0 and (y == 5 or y == 11 or y == 17) then
        if hash(x, y, 3) % 4 == 0 then return nil end
        return sw(LIGHT, 7)
      end
      if y == 0 then return sw(DECK_DK, 3) end
      return nil
    end
    if GATE[v] then
      -- the barred gate: posts either side, bars every two, a lamp over it
      if y > WALL_H then return nil end
      if v == 41 or v == 42 then
        if y >= 20 then
          if lz >= 5 and y <= 22 and (x % 16 >= 6 and x % 16 <= 9) then return sw(RED, 6) end
          return sw(STEEL, 4)
        end
      end
      if (lx == 0 and v % 2 == 1) or (lx == 7 and v % 2 == 0) then return sw(STEEL, 3) end
      if lz >= 3 and lz <= 4 and x % 3 == 0 and y <= 20 then return sw(STEEL_LT, 5) end
      if lz >= 3 and lz <= 4 and (y == 6 or y == 14) then return sw(STEEL_LT, 4) end
      if y == 0 then return sw(DECK_DK, 3) end
      return nil
    end
    if v == 11 or v == 12 or v == 27 or v == 28 then
      -- a bin: its centre the cell's, a drum 13 tall, ribs, a domed lid
      local c0 = (v == 11 or v == 27) and c or c - 1
      local r0 = (v == 11 or v == 12) and r or r - 1
      local dx, dz = x - (c0 * 8 + 7.5), z - (r0 * 8 + 7.5)
      local d = sqrt(dx * dx + dz * dz)
      if y <= 12 and d <= 5.6 then
        if d > 4.6 and y >= 1 then
          if y == 12 or y == 1 then return sw(STEEL, 3) end            -- the rims
          if y % 4 == 0 then return sw(STEEL_LT, 2) end                -- the ribs
          return sw(BIN, 3 + (dx > 0 and 1 or 0) + (dz > 2 and 1 or 0))
        end
        if y == 0 then return sw(DECK_DK, 2) end
        if y == 12 then return sw(BIN, 5) end
        return nil
      end
      if y >= 13 and y <= 14 and d <= 5.6 - (y - 13) * 2 then return sw(BIN, 6) end   -- the lid
      if y == 15 and abs(dx) <= 1 and abs(dz) <= 2 then return sw(STEEL, 5) end       -- its grip
      if y > 0 then return nil end
    end
    if y > 0 then return nil end
    if v == 6 or v == 22 then return nil end                             -- the mat
    -- (the deck runs on under the developer's bins and the statues too:
    -- their cells stay unclaimed, but the drawn floor there would show)
    -- steel deck plates, 16 square, a raised diamond tread
    if x % 16 == 0 or z % 16 == 0 then return sw(DECK_DK, 3) end
    local tx, tz = x % 4, z % 4
    if (tx == 1 and tz == 1) or (tx == 3 and tz == 3) then return sw(STEEL_LT, 4) end
    -- each plate its own shade, worn a little lighter along its middle
    local wear = (abs(x % 16 - 8) + abs(z % 16 - 8) < 6) and 1 or 0
    return sw(DECK, 2 + hash(floor(x / 16), 0, floor(z / 16)) % 3 + wear + hash(x, 9, z) % 2)
  end
  return at, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not Surge's Gym: " .. tostring(mapId) end
  local at, W, D = build(t)
  -- the statues are the profile's (gym_statue): left
  local open = { [2] = true, [56] = true, [18] = true, [19] = true, [34] = true,
                 [35] = true, [50] = true, [51] = true, [6] = true, [22] = true }
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, WALL_H + 1
  return m
end

return Kit
