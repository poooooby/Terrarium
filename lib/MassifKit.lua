-- Voxel world mode: the ROCK MASSIFS of the overworld, raised.
--
-- Gen 1 draws the mountains between the routes (Route 3's hills, the
-- ridges of 4, 8, 9, 10, 12, Viridian's west, Route 22's) as one speckled
-- tile, $11 (17), that is never walkable, its edges drawn as the ledge
-- banks ($24/$27/$37, lib/LedgeKit.lua). On the one ground plane it lay
-- flat as heath. What stands here instead: a block of weathered rock as
-- tall as a person and a bit, its sides falling steeply where the massif
-- ends -- strata in three tones, dark joints, the lit lip of each course --
-- and dry heath on its top with stones showing through. The banks stay at
-- its foot as the talus they are.
--
-- One cell at a time (Buildings' `cellKit`). The spec reads the 4x4 tiles
-- round the cell, so the cliff knows which way the massif ends, and adds a
-- variant by position so neighbouring cells do not repeat; only the cell's
-- own massif tiles are claimed. The ground beside it is the meadow world's
-- (tools/kanto_ground.py no longer lays $11). Nothing here is extracted
-- from the ROM.
local V = ...

local Kit = { SHEET = "assets/buildings/massif.png", SHEET_W = 8, SHEET_H = 8 }

local ROCK, ROCK_B, ROCK_DK, ROCK_LT, TURF, TURF_DK, STONE, EARTH = 0, 1, 2, 3, 4, 5, 6, 7
local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
local function sw(row, n) return row * 8 + max(0, min(7, floor(n))) end
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

Kit.MASSIF = { [17] = true }
-- the Safari Zone draws its hills on the FOREST sheet as $14 (20), never
-- walkable, the same block raised
local SAFARI = { [20] = true,
                 -- and the rock faces round its raised meadows (45/47 the
                 -- sides, 62 the front, 61/63 its corners)
                 [45] = true, [47] = true, [61] = true, [62] = true, [63] = true }
Kit.BY_MAP = { SAFARI_ZONE_CENTER = SAFARI, SAFARI_ZONE_EAST = SAFARI,
               SAFARI_ZONE_NORTH = SAFARI, SAFARI_ZONE_WEST = SAFARI }
Kit.SKIP = {}

local H = 20          -- the massif's top
local VARIANTS = 6

function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false or Kit.SKIP[mapId] then return nil end
  local MASSIF = Kit.BY_MAP[mapId] or Kit.MASSIF
  local own = false
  for _, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    if MASSIF[tileAt(tx + d[1], ty + d[2])] then own = true end
  end
  if not own then return nil end
  local s = {}
  for dz = -1, 2 do
    for dx = -1, 2 do
      local t = tileAt(tx + dx, ty + dz)
      -- off the map: the massif runs on (a map's edge is never a cliff)
      s[#s + 1] = (t == nil or MASSIF[t]) and "1" or "0"
    end
  end
  return table.concat(s) .. ":" .. (hash(tx, ty, 5) % VARIANTS)
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local grid, var = key:match("^(%d+):(%d+)$")
  var = tonumber(var)
  local function m(gx, gz)               -- the 4x4 tiles, 0..3
    if gx < 0 or gz < 0 or gx > 3 or gz > 3 then return true end
    return grid:sub(gz * 4 + gx + 1, gz * 4 + gx + 1) == "1"
  end
  -- a voxel's distance to the massif's end, over the 32x32 window the
  -- spec read (voxel -8..23), capped
  local CAP = 6
  local dist = {}
  for z = 0, 15 do
    for x = 0, 15 do
      local d = CAP
      if m(floor((x + 8) / 8), floor((z + 8) / 8)) then
        for oz = -CAP, CAP do
          for ox = -CAP, CAP do
            local wx, wz = x + ox, z + oz
            if not m(floor((wx + 8) / 8), floor((wz + 8) / 8)) then
              local dd = sqrt(ox * ox + oz * oz)
              if dd < d then d = dd end
            end
          end
        end
      else
        d = 0
      end
      dist[z * 16 + x] = d
    end
  end
  local function heightAt(x, z)
    local d = dist[z * 16 + x]
    if d <= 0 then return 0 end
    -- the cliff: steep to the top within two voxels of the end, a rounded
    -- shoulder, then the top rolling a voxel or two
    local h
    if d < 1.5 then h = H - 7
    elseif d < 2.5 then h = H - 3
    elseif d < 3.5 then h = H - 1
    else h = H end
    local n = hash(floor(x / 3) + var * 7, floor(z / 3), var) % 4
    if d >= 3.5 then h = h + (n == 0 and 1 or 0) - (n == 3 and 1 or 0) end
    return h
  end
  local mask = {
    m(1, 1), m(2, 1), m(1, 2), m(2, 2),
  }
  local function at(x, y, z)
    if x < 0 or x > 15 or z < 0 or z > 15 or y < 0 then return nil end
    local h = heightAt(x, z)
    if y >= h then return nil end
    local d = dist[z * 16 + x]
    local top = y == h - 1
    if top and d >= 2.5 then
      -- the heath on top: turf, darker in patches, stones through it
      local r = hash(x + var * 16, z, 3)
      if r < 6 then return sw(STONE, 3 + r % 3) end
      if r < 30 then return sw(TURF_DK, 3 + r % 3) end
      return sw(TURF, 3 + r % 3)
    end
    if top then return sw(ROCK_LT, 4 + hash(x, z, var) % 2) end      -- the lit lip
    if y <= 1 then return sw(EARTH, 3 + hash(x, z, 4) % 2) end       -- the foot
    -- the face: strata four courses deep, dark joints, a lit edge to each
    local course = floor((y + (var % 2)) / 4)
    local u = x + z
    if (y + (var % 2)) % 4 == 3 then return sw(ROCK_LT, 3) end
    if (u + course * 5 + var) % 9 == 0 then return sw(ROCK_DK, 3) end  -- the joints
    local row = (course % 2 == 0) and ROCK or ROCK_B
    return sw(row, 3 + hash(floor(u / 3), course, var) % 3)
  end
  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15, ytop = H + 2,
           claimMask = mask, standH = 0 }
end

return Kit
