-- Voxel world mode: the LOBBY rooms inside -- Celadon's department store,
-- its diner, the Game Corner and its prize room, the lifts -- read off
-- their own plans.
--
--   1 over 33, 91     the wall band          cream plaster, a burgundy dado,
--                                            a gold picture rail
--   16                the dark above a room  left unbuilt
--   32                the store's floor      pale marble slabs
--   55/69             the checker            a red and gold carpet (the
--                                            Game Corner, the diner, the roof
--                                            and the lift: marble there)
--   38 39 41 / 54 57 / 48 21 49   a counter  laminate on oak, the front panel
--                                            21, the sides 54/57
--   38 41 over 34/35 (..) over 50/51   a cabinet  a machine: in the Game
--                                            Corner a slot machine with a lit
--                                            screen, elsewhere a vending
--                                            machine or a prize case
--   54/57 runs in the Game Corner         banks of slot machines, standing
--   42..45 / 58..61 / 64..67 / 80..83     shop shelving: a gondola of goods
--   9 39 39 25 / 54 55 55 57 / 70 55 55 71 / 85 86 87   a table, white top
--   7/8 over 23/24    a stool                chrome, a red seat
--
-- The rest (the lift doors, the stairs, signs, posters, the roof's parapet
-- and its vending machines' tops) stays the profile's: `allowSkip`. On the
-- homes' shell. cols*8 x rows*8 voxels. Nothing here is extracted from the
-- ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/lobby_kit.png", SHEET_W = 8, SHEET_H = 18 }
Kit.MAPS = { CELADON_MART_1F = 1, CELADON_MART_2F = 1, CELADON_MART_3F = 1, CELADON_MART_4F = 1,
             CELADON_MART_5F = 1, CELADON_MART_ROOF = 1, CELADON_MART_ELEVATOR = 1,
             CELADON_DINER = 1, GAME_CORNER = 1, GAME_CORNER_PRIZE_ROOM = 1,
             ROCKET_HIDEOUT_ELEVATOR = 1, SILPH_CO_ELEVATOR = 1 }
-- the halls whose checker is carpet; whose 54/57 runs are slot banks
local CARPET = { GAME_CORNER = true, GAME_CORNER_PRIZE_ROOM = true, CELADON_DINER = true }
local SLOTS = { GAME_CORNER = true }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local WALL, DADO, MARBLE, MARBLE_D, CARPET_A, CARPET_B, GOLD, TOP, OAK, CHROME, SEAT,
      LACQUER, SCREEN, LIGHT, DARK, GOODS_A, GOODS_B, GOODS_C =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local BAND_H, COUNTER_H, CAB_H = 28, 10, 20
local SHELF = { [42] = 0, [43] = 1, [44] = 2, [45] = 3, [58] = 0, [59] = 1, [60] = 2, [61] = 3,
                [64] = 0, [65] = 1, [66] = 2, [67] = 3, [80] = 0, [81] = 1, [82] = 2, [83] = 3 }
local TABLE = { [9] = true, [25] = true, [70] = true, [71] = true, [85] = true, [86] = true, [87] = true }
local COUNTER = { [38] = true, [39] = true, [41] = true, [48] = true, [49] = true, [21] = true,
                  [54] = true, [57] = true }
Kit.OWN = {}
for _, t in ipairs({ 1, 33, 91, 16, 32, 55, 69, 34, 35, 50, 51, 7, 8, 23, 24 }) do Kit.OWN[t] = true end
for t in pairs(SHELF) do Kit.OWN[t] = true end
for t in pairs(TABLE) do Kit.OWN[t] = true end
for t in pairs(COUNTER) do Kit.OWN[t] = true end

local function build(t, mapId)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  local carpet, slots = CARPET[mapId], SLOTS[mapId]

  -- which tiles belong to a cabinet: a 38/41 pair over 34/35 down to 50/51
  local cab = {}
  for r = 0, rows - 2 do
    for c = 0, cols - 2 do
      if tile(c, r) == 38 and tile(c + 1, r) == 41 and tile(c, r + 1) == 34 then
        local r1 = r + 1
        while tile(c, r1) == 34 do r1 = r1 + 1 end
        local box = { c * 8, r * 8, (r1 + 1) * 8 - 1 }
        for rr = r, r1 do cab[c + rr * cols] = box; cab[c + 1 + rr * cols] = box end
      end
    end
  end
  -- the shelving gondolas: each 4x4 block of shelf tiles
  local gond = {}
  for r = 0, rows - 4 do
    for c = 0, cols - 4 do
      if tile(c, r) == 42 and tile(c + 3, r + 3) == 83 then
        local box = { c * 8, r * 8 }
        for i = 0, 3 do for j = 0, 3 do gond[c + i + (r + j) * cols] = box end end
      end
    end
  end
  -- the tables: 9 39 39 25 over three rows
  local tab = {}
  for r = 0, rows - 4 do
    for c = 0, cols - 4 do
      if tile(c, r) == 9 and tile(c + 3, r) == 25 then
        local box = { c * 8, r * 8 }
        for i = 0, 3 do for j = 0, 3 do tab[c + i + (r + j) * cols] = box end end
      end
    end
  end
  local function floorAt(x, z, v)
    if v == 32 or not carpet then
      if x % 16 == 0 or z % 16 == 0 then return sw(MARBLE_D, 4) end
      return sw(MARBLE, 4 + hash(floor(x / 16), 0, floor(z / 16)) % 3)
    end
    local gx, gz = floor(x / 8), floor(z / 8)
    local u, w = x % 8 - 3.5, z % 8 - 3.5
    if abs(u) + abs(w) <= 1.5 then return sw(GOLD, 4) end
    return sw((gx + gz) % 2 == 0 and CARPET_A or CARPET_B, 4 + hash(x, 0, z) % 2)
  end

  return function(x, y, z)
    if x < 0 or x >= W or z < 0 or z >= D or y < 0 then return nil end
    local c, r = floor(x / 8), floor(z / 8)
    local v = tile(c, r)
    if not v then return nil end
    local lx, lz = x % 8, z % 8
    if v == 16 then return nil end
    if v == 1 or v == 33 or v == 91 then
      -- the wall band; its face at the south of its lower row
      local below = tile(c, r + 1)
      if v == 1 and below ~= 33 and below ~= 1 and below ~= 91 and tile(c, r - 1) ~= 1 then
        return (y == 0) and floorAt(x, z, 32) or nil                    -- a stray band tile
      end
      if y > BAND_H then return nil end
      if y == BAND_H then return sw(DADO, 3) end
      if y <= 1 then return sw(DADO, 2) end
      if y <= 10 then return sw(DADO, 4 + (x % 12 == 0 and -1 or 0)) end
      if y == 11 then return sw(GOLD, 5) end
      return sw(WALL, 4 + hash(floor(x / 10), floor(y / 6), 1) % 2)
    end
    local box = cab[c + r * cols]
    if box then
      -- a machine: a lacquered cabinet, its face to the south
      local tx, tz = x - box[1], z - box[2]
      local front = z >= box[3] - 1
      if y > CAB_H then return nil end
      if tx == 0 or tx == 15 then return sw(DARK, 3) end
      if y == CAB_H then return sw(LACQUER, 6) end
      if front then
        if y >= 12 and y <= 17 and tx >= 2 and tx <= 13 then
          if slots then return sw((tx % 4 < 2) and SCREEN or LIGHT, 5 + (y % 2)) end    -- the reels
          return sw(SCREEN, 4 + (y >= 15 and 2 or 0))
        end
        if y >= 6 and y <= 8 and tx >= 4 and tx <= 11 then return sw(GOLD, 5) end    -- the tray
        if y <= 1 then return sw(DARK, 2) end
      end
      return sw(LACQUER, 3 + (tx < 8 and 1 or 0))
    end
    local g = gond[c + r * cols]
    if g then
      -- a gondola: a base, three shelves of goods both sides, a top
      local tx, tz = x - g[1], z - g[2]
      if tx < 1 or tx > 30 or tz < 2 or tz > 29 then return (y == 0) and floorAt(x, z, 32) or nil end
      if y > 18 then return nil end
      if y <= 1 then return sw(DARK, 3) end
      if y == 18 or y % 6 == 2 then return sw(CHROME, 4) end
      if tz >= 13 and tz <= 18 then return sw(CHROME, 3) end              -- the spine
      local bay = floor(tx / 5) + floor(y / 6) * 7
      return sw(({ GOODS_A, GOODS_B, GOODS_C, SEAT })[hash(g[1] + bay, floor(y / 6), tz > 15 and 1 or 0) % 4 + 1],
                3 + (tx % 5 == 0 and -1 or 1))
    end
    local tb = tab[c + r * cols]
    if tb then
      -- a table: a white top on a pedestal, 32 x 32
      local tx, tz = x - tb[1], z - tb[2]
      local d = (tx - 15.5) ^ 2 + (tz - 15.5) ^ 2
      if y <= 7 and d <= 3 then return sw(CHROME, 4) end
      if y == 0 and d <= 30 then return sw(CHROME, 3) end
      if y >= 8 and y <= 9 and tx >= 2 and tx <= 29 and tz >= 2 and tz <= 29 then
        if Lib.cornerCut(tx - 2, tz - 2, 28, 28, 4) then return nil end
        return sw(TOP, y == 9 and 6 or 4)
      end
      if y == 0 then return floorAt(x, z, 55) end
      return nil
    end
    if v == 7 or v == 8 or v == 23 or v == 24 then
      -- a stool: a chrome post, a red cushion, at the cell's middle
      local c0 = (v == 7 or v == 23) and c or c - 1
      local r0 = (v == 7 or v == 8) and r or r - 1
      local d = (x - c0 * 8 - 7.5) ^ 2 + (z - r0 * 8 - 7.5) ^ 2
      if y <= 6 and d <= 1.5 then return sw(CHROME, 4) end
      if y == 0 and d <= 12 then return sw(CHROME, 3) end
      if y >= 7 and y <= 8 and d <= 16 then return sw(SEAT, 4 + (y == 8 and 1 or 0)) end
      if y == 0 then return floorAt(x, z, 55) end
      return nil
    end
    if COUNTER[v] then
      if slots and (v == 54 or v == 57 or v == 38 or v == 41) then
        -- a bank of slot machines standing back to back
        if y > CAB_H then return nil end
        if y == CAB_H then
          -- the top: one machine to every eight, a lit sign along its front
          if z % 8 == 0 then return sw(DARK, 3) end
          local edge = (v == 54 and lx <= 1) or (v == 57 and lx >= 6)
          if edge then return sw(((z + x) % 3 == 0) and LIGHT or GOLD, 6) end
          return sw(LACQUER, 4 + (floor(z / 8) % 2))
        end
        local face = (v == 54 and lx == 0) or (v == 57 and lx == 7)
        if face and y >= 12 and y <= 17 and lz >= 1 and lz <= 6 then
          return sw((lz % 3 == 0) and LIGHT or SCREEN, 5)
        end
        if z % 8 == 0 then return sw(DARK, 3) end
        return sw(LACQUER, 3 + (lx < 4 and 1 or 0))
      end
      -- a counter: laminate top, oak body, the front panel in the dado's red
      if y > COUNTER_H then return nil end
      if y >= COUNTER_H - 1 then return sw(TOP, y == COUNTER_H and 6 or 4) end
      if y <= 1 then return sw(DARK, 3) end
      if v == 21 then return sw(DADO, 4 + (x % 16 == 0 and -1 or 0)) end
      return sw(OAK, 4)
    end
    if v == 32 or v == 55 or v == 69 then
      if y > 0 then return nil end
      return floorAt(x, z, v)
    end
    return nil
  end, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not a lobby room: " .. tostring(mapId) end
  local at, W, D = build(t, mapId)
  local open = {}
  -- 34/35/50/51 are ours only where every one is a cabinet's (under a 38/41
  -- head); elsewhere they are the profile's machines (store 1F's)
  local loose = false
  for r = 1, #t.tiles do
    for c = 1, #t.tiles[1] do
      local v = t.tiles[r][c]
      if v == 34 or v == 35 then
        local rr = r - 1
        while rr >= 1 and (t.tiles[rr][c] == 34 or t.tiles[rr][c] == 35) do rr = rr - 1 end
        local head = rr >= 1 and t.tiles[rr][c]
        if head ~= 38 and head ~= 41 then loose = true end
      end
    end
  end
  for r = 1, #t.tiles do
    for c = 1, #t.tiles[1] do
      local v = t.tiles[r][c]
      if not Kit.OWN[v] then open[v] = true end
      if loose and (v == 34 or v == 35 or v == 50 or v == 51) then open[v] = true end
    end
  end
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, BAND_H + 1
  return m
end

return Kit
