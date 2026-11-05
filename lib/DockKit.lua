-- Voxel world mode: VERMILION's harbour (VERMILION_DOCK) and the S.S. Anne
-- lying at it, built as a quay and a ship.
--
-- The drawing (SHIP_PORT tileset): the quay's concrete (10) with its edge
-- kerb (58), cargo crates (86/87 over 1/80, one to a cell), the breakwater's
-- rocks along the west and south (49), the gangway down to the ship (50/59),
-- the water (20, the developer's basin) -- and the liner itself, drawn from
-- above in one block of tiles at rows 6..11, cols 20..35: a pointed bow to
-- the west, a white superstructure, two funnels, lifeboats, a square stern.
-- What stands here:
--
--   the quay       concrete slabs, joints, a dark kerb of dressed stone
--   the crates     timber crates with battens, stacked where they are drawn
--   breakwater     a bank of rough rocks, wet at the foot
--   the gangway    a plank way on two stringers, a rope rail either side
--   the ship       the hull rising out of the water (it starts below the
--                  floor, `sink`): red boot-topping, a navy band, white
--                  topsides with a row of portholes, a sheer to the bow; a
--                  teak deck; the superstructure in two tiers with windows;
--                  two red funnels with black tops; lifeboats in davits
--
-- The truck by the quay is a plain lorry (no particular one); the water is
-- the profile's. One model,
-- the whole plan (data/voxel_heights.lua SHIP_PORT). x east, z south. Once
-- the ship has sailed the plan is drawn without her and this template no
-- is drawn without her and a second template (`dock_room_empty`) stands
-- the quay alone. Nothing here is
-- extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/dock_kit.png", SHEET_W = 8, SHEET_H = 16, SINK = 6 }
Kit.MAPS = { VERMILION_DOCK = 1 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local CONCRETE, CONC_DK, KERB, CRATE, CRATE_DK, ROCK, ROCK_DK, PAINT, PAINT_DK, NAVY, RED,
      OAK, WALNUT, DARK, GLASS, STEEL = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

-- the ship's box in the plan (tiles) and in voxels
local SC0, SC1, SR0, SR1 = 20, 35, 6, 11
local SX0, SX1, SZ0, SZ1 = SC0 * 8, SC1 * 8 + 7, SR0 * 8, SR1 * 8 + 7
local DECK_Y = 14                         -- the main deck above the quay's floor
local FUNNELS = { { 28 * 8 + 4, 70 }, { 31 * 8 + 4, 70 } }

local TRUCK = {}
for _, v in ipairs({ 72, 73, 74, 75, 76, 88, 89, 60 }) do TRUCK[v] = true end
local LIGHT_ROW = 14                      -- (the glass row stands for a lamp)

local function build(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  local SINK = Kit.SINK
  -- is she here? (the plan draws her bridge at 24/7; water once she sails)
  local moored = tile(24, 7) ~= 20
  local cz = (SZ0 + SZ1) / 2

  -- the hull's half-beam at x: full aft, tapering to a point at the bow
  local function beam(x)
    local L = SX1 - SX0
    local u = (x - SX0) / L                    -- 0 at the bow, 1 at the stern
    if u < 0 or u > 1 then return -1 end
    local half = (SZ1 - SZ0) / 2 - 2
    if u < 0.32 then return half * sqrt(u / 0.32) end
    if u > 0.97 then return half - (u - 0.97) * 60 end
    return half
  end

  local function ship(x, y, z)
    local b = beam(x)
    if b < 0 then return nil end
    local dz = abs(z - cz)
    if dz > b + 0.5 then return nil end
    local u = (x - SX0) / (SX1 - SX0)
    local sheer = DECK_Y + floor(max(0, 0.25 - u) * 12)  -- the deck rises to the bow
    local edge = dz > b - 1.5
    if y < sheer then
      if not edge then return (y == sheer - 1) and nil or sw(DARK, 1) end
      -- the topsides
      if y <= 1 then return sw(RED, 3 + (x % 2)) end      -- boot-topping at the waterline
      if y <= 4 then return sw(NAVY, 3) end
      if y == sheer - 1 then return sw(PAINT, 6) end       -- the rail's cap
      if y == 9 and x % 8 == 4 and u > 0.25 and u < 0.92 then return sw(GLASS, 3) end   -- portholes
      return sw(PAINT, 4 + hash(floor(x / 16), 0, 1) % 2)
    end
    -- the deck: teak planks along the length, a white bulwark at the edge
    if y == sheer then
      if edge then return sw(PAINT, 6) end
      if z % 3 == 0 then return sw(WALNUT, 3) end
      return sw(OAK, 3 + hash(floor(x / 12), floor(z / 3), 2) % 3)
    end
    if edge and y <= sheer + 3 then
      if y == sheer + 3 then return sw(OAK, 5) end         -- the bulwark's rail
      return sw(PAINT, 5)
    end
    -- the superstructure: two tiers, set back from the sides
    local sx0, sx1 = 24 * 8 + 4, 34 * 8 + 2
    local sb = b - 6
    if x >= sx0 and x <= sx1 and dz <= sb and y > sheer then
      local h1 = sheer + 10
      if y <= h1 then
        local face = dz >= sb - 0.5 or x == sx0 or x == sx1
        if y == h1 then return sw(PAINT, 6) end
        if face and (y >= sheer + 4 and y <= sheer + 7) and (x % 6 < 4) then return sw(GLASS, 4) end
        return sw(PAINT, face and 5 or 4)
      end
      -- the upper tier and the bridge forward
      local ux0, ux1 = sx0 + 8, sx1 - 16
      if x >= ux0 and x <= ux1 and dz <= sb - 4 and y <= h1 + 8 then
        local face = dz >= sb - 4.5 or x == ux0 or x == ux1
        if y == h1 + 8 then return sw(PAINT, 6) end
        if face and y >= h1 + 3 and y <= h1 + 5 and (x == ux0 or x % 5 < 3) then return sw(GLASS, 5) end
        return sw(PAINT, face and 5 or 4)
      end
    end
    -- the funnels: red, a black top
    for _, f in ipairs(FUNNELS) do
      local fx, fz = x - f[1], z - f[2]
      local d2 = (fx / 1.4) ^ 2 + fz * fz
      if d2 <= 16 and y > sheer + 10 and y <= sheer + 30 then
        if d2 <= 8 and y >= sheer + 22 then                          -- the open top
          return (y == sheer + 22) and sw(DARK, 2) or nil
        end
        if y >= sheer + 29 then return sw(DARK, 3) end                 -- a thin black rim
        if y == sheer + 25 then return sw(PAINT, 6) end               -- a white band
        return sw(RED, 4 + (fx < 0 and 1 or 0))
      end
    end
    -- lifeboats on the deck either side of the superstructure
    for _, side in ipairs({ -1, 1 }) do
      for i = 0, 2 do
        local bx = 26 * 8 + i * 22
        local bz = cz + side * (b - 3.5)
        local ex, ez = (x - bx) / 8, (z - bz) / 2.2
        if ex * ex + ez * ez <= 1 and y > sheer and y <= sheer + 5 then
          if y >= sheer + 4 then return sw(PAINT, 6) end
          if y == sheer + 3 then return sw(RED, 4) end
          return sw(PAINT, 4)
        end
      end
    end
    return nil
  end

  return function(x, y0, z)
    local y = y0 - SINK
    if x < 0 or x >= W or z < 0 or z >= D then return nil end
    if moored and x >= SX0 and x <= SX1 and z >= SZ0 and z <= SZ1 then
      local v = ship(x, y, z)
      if v then return v end
    end
    local c, r = floor(x / 8), floor(z / 8)
    local v = tile(c, r)
    local lx, lz = x % 8, z % 8
    if v == 10 then
      if y > 0 then return nil end
      if y < 0 then return (y >= -2) and sw(CONC_DK, 2) or nil end
      if x % 16 == 0 or z % 16 == 0 then return sw(CONC_DK, 3) end
      return sw(CONCRETE, 3 + hash(floor(x / 16), 0, floor(z / 16)) % 3)
    end
    if v == 58 then
      -- the kerb: dressed stone, its face down to the water
      if y > 1 then return nil end
      if y < -SINK + 1 then return nil end
      if x % 12 == 0 then return sw(ROCK_DK, 3) end
      return sw(KERB, 3 + (y == 1 and 2 or 0) + hash(floor(x / 12), 0, 2) % 2)
    end
    if v == 86 or v == 87 or v == 1 or v == 80 then
      -- a crate, one to a cell: battens, a stencil band
      if y < 0 then return nil end
      local ux, uz = x % 16, z % 16
      if ux < 1 or ux > 14 or uz < 1 or uz > 14 then return (y == 0) and sw(CONCRETE, 3) or nil end
      if y > 13 then return nil end
      if y == 13 then return sw(CRATE, 5 + (ux % 4 == 0 and -2 or 0)) end
      if ux == 1 or ux == 14 or uz == 1 or uz == 14 or y == 1 or y == 7 then return sw(CRATE_DK, 3) end
      return sw(CRATE, 3 + (ux + uz) % 2)
    end
    if v == 49 then
      -- the breakwater: rough rocks heaped, wet at the waterline
      local n = hash(floor(x / 3), floor(z / 3), 5)
      local h = 3 + n % 5
      if y > h or y < -SINK then return nil end
      if y <= -1 then return sw(ROCK_DK, 2) end
      if y == h then return sw(ROCK, 5) end
      return sw(ROCK, 2 + hash(floor(x / 2), y, floor(z / 2)) % 3)
    end
    if TRUCK[v] then
      -- the lorry parked on the quay (tiles 72..75 over 88/89/60/76, x 320..351,
      -- z 0..15): a cab to the west, a flatbed with low sides, four wheels
      if y < 0 then return nil end
      local tx, tz = x - 40 * 8, z
      if y == 0 and not (tx >= 1 and tx <= 30 and tz >= 1 and tz <= 14) then return sw(CONCRETE, 3) end
      for _, wx in ipairs({ 6, 23 }) do
        for _, wz in ipairs({ 1, 14 }) do
          if (tx - wx) ^ 2 + (y - 3) ^ 2 <= 9 and abs(tz - wz) <= 1 then
            return sw((tx - wx) ^ 2 + (y - 3) ^ 2 <= 1.5 and STEEL or DARK, 3)
          end
        end
      end
      if tz < 2 or tz > 13 or tx < 1 or tx > 30 then return nil end
      if y >= 3 and y <= 5 then return sw(DARK, 2) end                     -- the chassis
      if tx <= 10 then
        -- the cab: white, a windscreen to the west, side windows
        if y > 16 then return nil end
        if y == 16 then return sw(PAINT, 6) end
        if y >= 11 and y <= 14 and (tx == 1 or ((tz == 2 or tz == 13) and tx >= 3 and tx <= 8)) then
          return sw(GLASS, 4 + (y >= 13 and 1 or 0))
        end
        if y == 6 and tx == 1 and (tz == 3 or tz == 12) then return sw(LIGHT_ROW, 6) end
        return sw(PAINT, 4 + (tx == 1 and 1 or 0))
      end
      -- the flatbed: boards, low sides
      if y == 6 then return sw(OAK, 3 + (tx % 3 == 0 and -1 or 1)) end
      if y <= 8 and (tz == 2 or tz == 13 or tx == 30 or tx == 11) then return sw(RED, 4) end
      return nil
    end
    if v == 50 or v == 59 then
      -- the gangway: planks across, stringers, a rope rail each side
      local gx = x - 28 * 8
      local onWater = tile(c, r) and (tile(c - 1, r) == 20 or tile(c + 2, r) == 20 or r >= 2)
      local py = 1
      if gx == 0 or gx == 15 then
        if y >= py and y <= py + 8 and z % 8 == 0 then return sw(WALNUT, 3) end      -- stanchions
        if y == py + 8 then return sw(OAK, 2) end                                   -- the rope
      end
      if y == py then return sw((z % 3 == 0) and WALNUT or OAK, 4) end
      if y == py - 1 and (gx <= 1 or gx >= 14) then return sw(WALNUT, 2) end
      return nil
    end
    return nil
  end, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not the dock: " .. tostring(mapId) end
  local at, W, D = build(t)
  -- the water stays the profile's
  local open = { [20] = true }
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, Kit.SINK + DECK_Y + 34
  m.sink = Kit.SINK
  return m
end

return Kit
