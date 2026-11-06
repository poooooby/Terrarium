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

-- ------- THE FACES BETWEEN TWO CELLS
--
-- Each cell is its own model, so the side of one that stands against the
-- next was emitted in full -- a wall twenty voxels tall inside solid rock,
-- on every side of every inland cell. It is never seen, and it was most of
-- the massif's quads. The ring of voxels just past the cell (x or z of -1
-- or 16) now answers Buildings.CULL where the NEXT cell is certainly solid:
-- that hides the face and changes nothing else -- emit leaves CULL out of
-- the AO and the crisp-top ring, so every face still drawn keeps its
-- light. Exactly CaveKit's seam.
--
-- "Certainly" is two things the spec can vouch for:
--   * that the next cell IS a massif model: all four of its tiles are $11
--     on this map. The massif template's `allowSkip` is $11
--     (data/voxel_heights.lua), so such a cell is never refused for a
--     claim another template made first -- a cell with any other tile in
--     it may be (a ledge's bank), and is never culled against. Nor is the
--     map's edge (the next map's rock is not built here) nor the Safari
--     Zone's hills (their tiles are not in allowSkip).
--   * how tall it stands at the shared edge. Its distance-to-the-end there
--     reads only tiles inside THIS cell's 4x4 window, so it is computed
--     exactly; its top's one voxel of noise is its own variant's, which is
--     not, so the cull stops at the lowest that noise can make it.
local CULL = -2                 -- Buildings.CULL (no require: a kit loads alone)
local CULL_TILE = 17            -- = the massif template's allowSkip
local NEIGHBOURS = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }   -- e w s n
local OWN = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }

function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false or Kit.SKIP[mapId] then return nil end
  local MASSIF = Kit.BY_MAP[mapId] or Kit.MASSIF
  local own = false
  for _, d in ipairs(OWN) do
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
  -- which of the four next cells are certainly built massif (see above)
  local nb = {}
  local cullable = MASSIF[CULL_TILE] and not Kit.BY_MAP[mapId]
  for i, n in ipairs(NEIGHBOURS) do
    local all = cullable
    if all then
      for _, d in ipairs(OWN) do
        if tileAt(tx + n[1] + d[1], ty + n[2] + d[2]) ~= CULL_TILE then
          all = false
          break
        end
      end
    end
    nb[i] = all and "1" or "0"
  end
  return table.concat(s) .. ":" .. (hash(tx, ty, 5) % VARIANTS) .. ":" .. table.concat(nb)
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local grid, var, nbits = key:match("^(%d+):(%d+):?([01]*)$")
  var = tonumber(var)
  local nE, nW, nS, nN = false, false, false, false
  if nbits and #nbits == 4 then
    nE, nW = nbits:sub(1, 1) == "1", nbits:sub(2, 2) == "1"
    nS, nN = nbits:sub(3, 3) == "1", nbits:sub(4, 4) == "1"
  end
  local function m(gx, gz)               -- the 4x4 tiles, 0..3
    if gx < 0 or gz < 0 or gx > 3 or gz > 3 then return true end
    return grid:sub(gz * 4 + gx + 1, gz * 4 + gx + 1) == "1"
  end
  -- a voxel's distance to the massif's end, over the 32x32 window the
  -- spec read (voxel -8..23), capped
  local CAP = 6
  -- (x, z) in this cell's frame; also asked one voxel past each side, where
  -- it is the NEXT cell's own distance at its edge -- the window it reads
  -- (CAP = 6 voxels either way) is still inside this cell's 4x4 tiles
  local function distAt(x, z)
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
    return d
  end
  local dist = {}
  for z = 0, 15 do
    for x = 0, 15 do
      dist[z * 16 + x] = distAt(x, z)
    end
  end
  -- the next cell's height at the shared edge, at its LOWEST: heightAt's
  -- steps by distance, less the one voxel its variant's noise can take
  local function lowest(d)
    if d <= 0 then return 0 end
    if d < 1.5 then return H - 7 end
    if d < 2.5 then return H - 3 end
    return H - 1
  end
  local ringE, ringW, ringS, ringN = {}, {}, {}, {}
  for i = 0, 15 do
    ringE[i] = nE and lowest(distAt(16, i)) or 0
    ringW[i] = nW and lowest(distAt(-1, i)) or 0
    ringS[i] = nS and lowest(distAt(i, 16)) or 0
    ringN[i] = nN and lowest(distAt(i, -1)) or 0
  end
  local anyRing = nE or nW or nS or nN
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
    if y < 0 then return nil end
    if x < 0 or x > 15 or z < 0 or z > 15 then
      -- the ring: the next cell's rock, there only to hide the face
      if z >= 0 and z <= 15 then
        if x == 16 then return (y < ringE[z]) and CULL or nil end
        if x == -1 then return (y < ringW[z]) and CULL or nil end
      elseif x >= 0 and x <= 15 then
        if z == 16 then return (y < ringS[x]) and CULL or nil end
        if z == -1 then return (y < ringN[x]) and CULL or nil end
      end
      return nil
    end
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
  -- the box takes in the ring only when there is one to answer
  -- (-1 or 0, never -r: -0 would land in the quads as -0)
  local lo, hi = anyRing and -1 or 0, anyRing and 16 or 15
  return { at = at, W = 16, xmin = lo, xmax = hi, zmin = lo, zmax = hi, ytop = H + 2,
           claimMask = mask, standH = 0 }
end

return Kit
