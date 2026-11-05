-- Voxel world mode: a ROCKY SHORE round the water, built as rocks.
--
-- The overworld rims its water with tiles drawn wholly as rocks -- dark
-- stones with black joints, the sea's edge (50 on the west side, 51 along
-- the north, 84 on the east) -- and the profile laid them flat on one side
-- and stood them as a lattice wall on another. What lies here is the rim:
-- each rock tile a bed of rubble up to the ground and three rounded
-- boulders on it, wet and dark at the waterline, dry above, a little moss
-- on top. The model starts below the ground plane (`sink`, as the bridge's
-- piles do), so the stones stand IN the water rather than on it.
--
-- One cell at a time (Buildings' `cellKit`): the spec says which of the
-- cell's tiles are rock and where the cell is (for the hash), and only
-- those tiles are claimed. Nothing here is extracted from the ROM.
local V = ...

local Kit = { SHEET = "assets/buildings/rock_kit.png", SHEET_W = 8, SHEET_H = 4,
              ROCK = { [50] = true, [51] = true, [84] = true }, SINK = 4,
              -- keyed on the cell: kept per map, not per session (CaveKit)
              PER_CELL = true }

local STONE, STONE_DK, WET, MOSS = 0, 1, 2, 3
local function sw(row, n) return row * 8 + n % 8 end
local floor = math.floor
local function hash(a, b, c) return (a * 73856093 + b * 19349663 + c * 83492791) % 4093 end

function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false then return nil end
  local bits = 0
  for i, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    if Kit.ROCK[tileAt(tx + d[1], ty + d[2])] then bits = bits + 2 ^ (i - 1) end
  end
  if bits == 0 then return nil end
  return ("%d:%d:%d"):format(bits, tx, ty)
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local bits, tx, ty = key:match("^(%d+):(%-?%d+):(%-?%d+)$")
  bits, tx, ty = tonumber(bits), tonumber(tx), tonumber(ty)
  local SINK = Kit.SINK
  local GROUND = SINK                 -- model y of the ground plane
  local WATER = SINK - 2              -- of the water's surface

  local mask, boulders = {}, {}
  local tiles = {}
  for i, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local on = floor(bits / 2 ^ (i - 1)) % 2 == 1
    mask[i] = on
    if on then
      local ox, oz = d[1] * 8, d[2] * 8
      tiles[#tiles + 1] = { ox, oz }
      local wx, wz = (tx + d[1]) * 8, (ty + d[2]) * 8
      for b = 1, 3 do
        local h0 = hash(wx + b * 3, wz + b, b)
        boulders[#boulders + 1] = {
          x = ox + 1.5 + (h0 % 5),
          z = oz + 1.5 + floor(h0 / 5) % 5,
          r = 2.4 + (floor(h0 / 25) % 4) * 0.35,          -- 2.4 .. 3.45
          ry = 3 + floor(h0 / 100) % 2,                   -- 3 .. 4 above the ground
          salt = h0,
        }
      end
    end
  end

  local function inTile(x, z)
    for _, t in ipairs(tiles) do
      if x >= t[1] and x <= t[1] + 7 and z >= t[2] and z <= t[2] + 7 then return true end
    end
    return false
  end

  local function at(x, y, z)
    -- the boulders
    for _, b in ipairs(boulders) do
      local dx, dz = x - b.x + 0.5, z - b.z + 0.5
      local dy = y - GROUND
      local e = (dx * dx + dz * dz) / (b.r * b.r) + (dy >= 0 and (dy / b.ry) ^ 2 or 0)
      if e <= 1 and y >= 0 then
        if y <= WATER + 1 then return sw(WET, 2 + (x + z) % 3) end
        local top = (dy / b.ry) > 0.65
        if top and hash(x, y, z + b.salt) % 5 == 0 then return sw(MOSS, 3 + (x + z) % 3) end
        local shaded = dx > 0.5 or dz > 0.5                 -- the faces away from the sun
        return sw(shaded and STONE_DK or STONE, 3 + hash(floor(x / 2), y, floor(z / 2)) % 4)
      end
    end
    -- the rubble bed between them, up to the ground
    if y <= GROUND and inTile(x, z) then
      if y <= WATER + 1 then return sw(WET, 1 + hash(x, y, z) % 3) end
      return sw(STONE_DK, 2 + hash(x, y, z) % 4)
    end
    return nil
  end

  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15,
           ytop = GROUND + 5, sink = SINK, claimMask = mask, standH = 0 }
end

return Kit
