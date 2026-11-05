-- Voxel world mode: Brock's Gym in Pewter INSIDE -- a hall of rock.
--
-- The drawing is a maze of boulders (7/8 over 23/24, one to a cell) on a
-- striped floor, two statues on plinths before the arena, the mat at the
-- door. What stands here: each boulder a rounded rock of its own -- a
-- lumpy dome in warm grey, ochre and rust veins, a little moss at its foot,
-- its height and shape by hash so the maze is not a stamp -- the ring
-- round the hall taller than the boulders inside it, so the player in the
-- maze still shows; the floor sand-coloured boards with sand in the seams.
-- The statues are the profile's own (RoomKit `statue`, data/voxel_heights.lua
-- GYM `gym_statue`): their cells are left to it.
--
-- One room on the homes' shell (lib/HomeLib.lua): its side walls cut down
-- toward the camera, no south wall, no ceiling -- but the walls are the
-- boulder ring itself, so no wall is drawn. 160 x 224 voxels, x east, z
-- south. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/pewter_gym.png", SHEET_W = 8, SHEET_H = 12 }
-- Bruno's room at the Plateau is drawn from the same boulders on the same
-- floor, his back wall the gym's band (5 over 16): it is built here too
Kit.MAPS = { PEWTER_GYM = 1, BRUNOS_ROOM = 1 }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local ROCK, ROCK_DK, ROCK_LT, OCHRE, RUST, MOSS, BOARD, BOARD_DK, SAND, IRON, DARK, TRIM =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local function hash(a, b, c) return (a * 73856093 + b * 19349663 + c * 83492791) % 4093 end

local function vn(x, z, s, seed)
  local gx, gz = x / s, z / s
  local x0, z0 = floor(gx), floor(gz)
  local fx, fz = gx - x0, gz - z0
  fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
  local function h(a, b) return hash(a, b, seed) / 4093 end
  return (h(x0, z0) * (1 - fx) + h(x0 + 1, z0) * fx) * (1 - fz)
       + (h(x0, z0 + 1) * (1 - fx) + h(x0 + 1, z0 + 1) * fx) * fz
end

local function build(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  -- the boulder cells, and which are the ring (touch the plan's edge, or a
  -- run of boulders reaching it)
  local rock = {}
  local cw, ch = cols / 2, rows / 2
  for cy = 0, ch - 1 do
    for cx = 0, cw - 1 do
      if tile(cx * 2, cy * 2) == 7 and tile(cx * 2 + 1, cy * 2 + 1) == 24 then
        rock[cy * cw + cx] = true
      end
    end
  end
  -- the ring is the hall's own edge only: the partitions reaching in from
  -- it stay maze height, so nobody walking behind one is hidden
  local ring = {}
  for cy = 0, ch - 1 do
    for cx = 0, cw - 1 do
      if rock[cy * cw + cx] and (cx == 0 or cy == 0 or cx == cw - 1) then
        ring[cy * cw + cx] = true
      end
    end
  end

  -- a boulder's height at (x, z) inside its cell (lx, lz 0..15): a lumpy
  -- dome, rounder where it stands alone, joined to a neighbour boulder
  local function boulderH(cx, cy, lx, lz)
    local k = cy * cw + cx
    local base = ring[k] and 22 or 13
    local hx, hz = lx - 7.5, lz - 7.5
    -- reach toward a neighbouring boulder so a run reads as one outcrop
    local function joined(dx, dy)
      local nx, ny = cx + dx, cy + dy
      return nx >= 0 and ny >= 0 and nx < cw and ny < ch and rock[ny * cw + nx]
    end
    if hx > 0 and joined(1, 0) then hx = hx * 0.35 end
    if hx < 0 and joined(-1, 0) then hx = hx * 0.35 end
    if hz > 0 and joined(0, 1) then hz = hz * 0.35 end
    if hz < 0 and joined(0, -1) then hz = hz * 0.35 end
    local r = sqrt(hx * hx + hz * hz) / 8.2
    if r >= 1 then return 0 end
    local wx, wz = cx * 16 + lx, cy * 16 + lz
    local n = vn(wx, wz, 4, 1) * 0.7 + vn(wx, wz, 1.8, 2) * 0.3
    local h = base * sqrt(1 - r * r) * (0.80 + 0.35 * n)
    h = h + (hash(cx, cy, 3) % 5) - 2
    return max(0, floor(h + 0.5))
  end

  local H = {}
  local function heightAt(x, z)
    local key = z * W + x
    local v = H[key]
    if v == nil then
      local cx, cy = floor(x / 16), floor(z / 16)
      v = (rock[cy * cw + cx]) and boulderH(cx, cy, x % 16, z % 16) or 0
      H[key] = v
    end
    return v
  end

  local function at(x, y, z)
    if x < 0 or x > W - 1 or z < 0 or z > D - 1 or y < 0 then return nil end
    local h = heightAt(x, z)
    if h > 0 then
      if y >= h then return nil end
      local cx, cy = floor(x / 16), floor(z / 16)
      -- the side walls of the dollhouse: the ring's rocks cut down toward
      -- the camera, the way the homes' side walls are
      if ring[cy * cw + cx] and (x < 16 or x >= W - 16) and y > Lib.sideH(z) then return nil end
      local wx, wz = x, z
      -- the face: veins of ochre and rust, darker low down, moss at the foot
      local lo = h
      for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        local nx, nz = x + o[1], z + o[2]
        if nx >= 0 and nz >= 0 and nx < W and nz < D then lo = min(lo, heightAt(nx, nz)) end
      end
      local top = y == h - 1 and h - lo <= 2
      if y <= 1 and hash(wx, y, wz) % 3 == 0 then return sw(MOSS, 3 + hash(wx, 0, wz) % 3) end
      local vein = vn(wx + y * 2, wz - y, 3, 5)
      if vein > 0.78 then return sw(OCHRE, 3 + y % 3) end
      if vein < 0.12 then return sw(RUST, 3 + y % 2) end
      if top then return sw(ROCK_LT, 3 + hash(wx, y, wz) % 4) end
      if (y + floor(wx / 3) + floor(wz / 4)) % 5 == 0 then return sw(ROCK_DK, 4) end    -- cracks
      return sw(ROCK, 2 + hash(floor(wx / 2), floor(y / 2), floor(wz / 2)) % 5)
    end
    -- the back wall (Bruno's room): the band stood as a rock face the
    -- boulders' grey, coursed in rough blocks, a darker plinth
    local tb = tile(floor(x / 8), floor(z / 8))
    if tb == 5 or tb == 16 then
      if y > 27 then return nil end
      if y <= 1 then return sw(ROCK_DK, 3) end
      if y == 27 then return sw(ROCK_LT, 4 + hash(floor(x / 4), 0, 1) % 2) end
      local course = floor((y - 2) / 5)
      if (y - 2) % 5 == 4 or (x + course * 5) % 11 == 0 then return sw(ROCK_DK, 2) end
      return sw(ROCK, 2 + hash(floor((x + course * 5) / 11), course, 7) % 4)
    end
    if y > 0 then return nil end
    -- the floor: boards running east-west, four wide, sand in the seams
    local tl = tile(floor(x / 8), floor(z / 8))
    if tl == 6 or tl == 22 then return nil end                        -- the mat, drawn
    local row = floor(z / 4)
    local run = x + row * 17
    if z % 4 == 0 then return sw(SAND, 3 + hash(x, 0, z) % 2) end
    if run % 30 == 0 then return sw(BOARD_DK, 3) end
    return sw(BOARD, 3 + hash(floor(run / 30), row, 4) % 4)
  end
  return at, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not Brock's Gym: " .. tostring(mapId) end
  local at, W, D = build(t)
  -- the statues' tiles and the mat stay unclaimed: the profile stands
  -- those (gym_statue) and the mat is drawn
  local open = { [2] = true, [56] = true, [18] = true, [19] = true, [34] = true,
                 [35] = true, [50] = true, [51] = true, [6] = true, [22] = true }
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, 30
  return m
end

return Kit
