-- Voxel world mode: a CAVE's ground and rock (Mt. Moon), built as terrain.
--
-- The cave tileset draws two floors and the rock between them, and the
-- profile already says what each is (data/voxel_heights.lua CAVERN, the
-- developer's reading, which this follows): $20/$21/$2A the dark lower
-- floor; $05 the lit SHELF over it with $29 its shaded north row; $15/$16
-- the stair off the shelf, climbing NORTH onto it; the cobble faces round
-- every shelf ($10/$11 south, $31 west, $17 east, the caps and corners);
-- the speckled, boulder and "ceiling" masses; $3C the unlit rock, solid
-- black; $08 the ladder down and $0A the ladder up. Here they stand as
-- one piece of ground instead of a field of hoisted tiles:
--
--   the floor      trodden earth, darker in patches, pebbles, a little
--                  scree at the foot of every rock face
--   the shelf      a level of pale dust LIT voxels up, its faces rough
--                  rock falling to the floor, the stair four real treads
--   the faces      rock to the shelf's height with a ragged lip, steep and
--                  jointed, paler where they weather
--   the masses     taller rock, lumpy, the cave's walls proper
--   the dark rock  the unlit mass, tall and nearly black
--   the ladders    DOWN: a square shaft into the floor, two rails and rungs
--                  going down into the dark; UP: a timber ladder standing
--                  out of a rocky collar, climbing out of sight
--
-- A map with no lower floor (Mt. Moon B1F) has its lit floor at the floor
-- plane. One cell at a time (Buildings' `cellKit`): the spec reads the
-- tiles round the cell (two either side, so a face knows how far the floor
-- is), the model builds the cell's 16 x 16 and stands everything on it at
-- its level (`standH`). Ladders' warps and the exit mat are the game's;
-- the mat ($21 in the mouth) is claimed and painted as daylit floor.
--
-- Nothing here is extracted from the ROM.
local V = ...

-- Buildings.CULL, the half-phantom (see lib/Buildings.lua); a literal so this
-- kit loads without Buildings (the offline checks run it alone)
local Buildings_CULL = -2

local Kit = { SHEET = "assets/buildings/cave_kit.png", SHEET_W = 8, SHEET_H = 12,
              SINK = 10,
              -- the key carries the cell (tx, ty): no other cell, and no
              -- other map, ever asks for the same model -- Buildings keeps it
              -- only as long as this map is recent (Buildings.SCOPED_MAPS)
              PER_CELL = true }

local ROCK, ROCK_DK, ROCK_LT, EARTH, EARTH_DK, DUST, PEBBLE, VOID, WOOD, WOOD_DK, IRON, LIGHT =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local function sw(row, n) return row * 8 + math.max(0, math.min(7, math.floor(n))) end
local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
-- (the sine hash: nonlinear, so neighbouring voxels do not line up in
-- streaks the way a sum of products modulo a prime does)
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 4093)
end
local function vn(x, z, s, seed)
  local gx, gz = x / s, z / s
  local x0, z0 = floor(gx), floor(gz)
  local fx, fz = gx - x0, gz - z0
  fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
  local function h(a, b) return hash(a, b, seed) / 4093 end
  return (h(x0, z0) * (1 - fx) + h(x0 + 1, z0) * fx) * (1 - fz)
       + (h(x0, z0 + 1) * (1 - fx) + h(x0 + 1, z0 + 1) * fx) * fz
end

-- the tile classes, one letter each in the spec
--   L low floor   M the mouth   H lit shelf   S stair   F face   R mass
--   C ceiling mass   V unlit rock   D ladder down   U ladder up   O open
local CLASS = {}
for _, t in ipairs({ 32, 42 }) do CLASS[t] = "L" end
CLASS[33] = "M"
for _, t in ipairs({ 5, 41 }) do CLASS[t] = "H" end
for _, t in ipairs({ 21, 22 }) do CLASS[t] = "S" end
for _, t in ipairs({ 16, 17, 49, 23, 4, 7, 40, 37, 38 }) do CLASS[t] = "F" end
for _, t in ipairs({ 2, 3, 18, 19, 12, 13, 28, 29 }) do CLASS[t] = "R" end
for _, t in ipairs({ 6, 39, 36, 1 }) do CLASS[t] = "C" end
CLASS[60] = "V"
for _, t in ipairs({ 8, 9, 24, 25 }) do CLASS[t] = "D" end
for _, t in ipairs({ 10, 11, 26, 27 }) do CLASS[t] = "U" end
-- left to the profile: the water, the drop hole, the barred shelf, the
-- boulder switches (O: not this kit's, and a cell holding one is not built)
for _, t in ipairs({ 20, 47, 34, 14, 15, 30, 31, 43, 44, 45, 46 }) do CLASS[t] = "O" end

-- the lit shelf's height, per map: none where there is no floor under it
Kit.LIT = { MT_MOON_B1F = 0, DIGLETTS_CAVE = 0 }
local LIT_DEFAULT = 12
local FACE_H, MASS_H, VOID_H = 12, 20, 15

-- (the lit floor and the dark one are never stepped between in any cave --
-- the tileset's collision pairs forbid $05 <-> $20/$21/$2A/$41 -- so the
-- shelf is a level of its own wherever it is drawn: Diglett's Cave and the
-- Rock Tunnel too)
Kit.MAPS = { MT_MOON_1F = true, MT_MOON_B1F = true, MT_MOON_B2F = true,
             DIGLETTS_CAVE = true, DIGLETTS_CAVE_ROUTE_2 = true, DIGLETTS_CAVE_ROUTE_11 = true,
             ROCK_TUNNEL_1F = true, ROCK_TUNNEL_B1F = true,
             SEAFOAM_ISLANDS_1F = true,
             SEAFOAM_ISLANDS_B1F = true,
             SEAFOAM_ISLANDS_B2F = true,
             SEAFOAM_ISLANDS_B3F = true,
             SEAFOAM_ISLANDS_B4F = true,
             VICTORY_ROAD_1F = true,
             VICTORY_ROAD_2F = true,
             VICTORY_ROAD_3F = true,
             CERULEAN_CAVE_1F = true,
             CERULEAN_CAVE_2F = true,
             CERULEAN_CAVE_B1F = true,
           }

function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false or not Kit.MAPS[mapId] then return nil end
  local own = ""
  for _, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local c = CLASS[tileAt(tx + d[1], ty + d[2])]
    if c == nil or c == "O" then return nil end
    own = own .. c
  end
  -- the window the model reads, tiles -4..5 round the cell: its own 6x6
  -- (-2..3) and each edge neighbour's (whose cell starts 2 tiles over), so
  -- the faces between two cells can be culled against the neighbour's real
  -- rock (see Kit.model). Raw here -- X off the map or a tile this kit does
  -- not know, O the profile's -- and mapped to the old window's letters
  -- (V, L) only where a window is cut from it.
  local win = {}
  for y = -4, 5 do
    for x = -4, 5 do
      local t = tileAt(tx + x, ty + y)
      win[#win + 1] = (t and CLASS[t]) or "X"
    end
  end
  local lit = Kit.LIT[mapId] or LIT_DEFAULT
  return ("%d|%d|%d|%s"):format(lit, tx, ty, table.concat(win))
end

-- ------- the ground of one cell, from its 6x6 window of tile classes
--
-- Kit.model's height machinery, lifted out whole so a model can run it for
-- its NEIGHBOURS too: the class lookups, the levels, the distance field and
-- the memoised ground(x, z). `win` is the old 36-letter window (-2..3), OX,
-- OZ the cell's world voxel origin (the noise is in world coordinates).
local function cellGround(lit, win, OX, OZ)
  -- the class of the tile at window position (i, j), -2..3
  local function cls(i, j) return win:sub((j + 2) * 6 + (i + 2) + 1, (j + 2) * 6 + (i + 2) + 1) end
  -- the class under a local voxel (x, z may run -16..31)
  local function clsAt(x, z) return cls(floor(x / 8), floor(z / 8)) end

  local function level(c)
    if c == "L" or c == "M" then return 0 end
    if c == "H" then return lit end
    if c == "F" then return max(FACE_H, lit) end
    if c == "R" or c == "C" then return MASS_H end
    if c == "V" then return VOID_H end
    return nil                                  -- S, D, U: decided below
  end
  local WALK = { L = true, M = true, H = true, S = true, D = true, U = true }

  -- distance from a local voxel to the nearest tile of a set, in voxels
  local function distTo(x, z, test)
    local best = 99
    for j = -2, 3 do
      for i = -2, 3 do
        if test(cls(i, j)) then
          local x0, z0 = i * 8, j * 8
          local dx = max(x0 - x, 0, x - (x0 + 7))
          local dz = max(z0 - z, 0, z - (z0 + 7))
          local d = sqrt(dx * dx + dz * dz)
          if d < best then best = d end
        end
      end
    end
    return best
  end

  -- the floor a ladder (or a stair's foot) stands on: the walkable level
  -- most of its neighbours have
  local function floorOf(ci, cj)
    local hi, lo = 0, 0
    for j = cj - 1, cj + 1 do
      for i = ci - 1, ci + 1 do
        local c = cls(i, j)
        if c == "H" then hi = hi + 1 elseif c == "L" or c == "M" then lo = lo + 1 end
      end
    end
    return (hi > lo) and lit or 0
  end

  -- the ground's top at a local voxel (the y of the highest solid voxel + 1,
  -- above the floor plane), and what it is
  local H, K = {}, {}
  local function ground(x, z)
    local k = (z + 16) * 64 + (x + 16)
    if H[k] then return H[k], K[k] end
    local c = clsAt(x, z)
    local wx, wz = OX + x, OZ + z
    local h, kind
    if c == "S" then
      -- the stair: four treads climbing north, foot at the floor south of
      -- it, top at the shelf
      local tread = 3 - floor(z / 4)                 -- 3 along the north edge
      h, kind = floor(lit * (tread + 1) / 4 + 0.5), "stair"
    elseif c == "D" or c == "U" then
      h, kind = floorOf(floor(x / 8), floor(z / 8)), c
    else
      local top = level(c)
      if WALK[c] then
        h, kind = top, (c == "H") and "shelf" or ((c == "M") and "mouth" or "floor")
        -- scree at the foot of the rock: a stone or two by the face
        if top == 0 then
          local dr = distTo(x, z, function(q) local l = level(q); return l and l > 0 and not WALK[q] end)
          if dr < 2.5 and vn(wx, wz, 1.7, 61) > 0.62 then h, kind = 1, "scree" end
        end
      else
        -- rock: its own top, ragged, falling steeply toward any walkable
        -- tile lower than it
        local lump = (c == "F") and floor(vn(wx, wz, 3.0, 7) * 4) or floor(vn(wx, wz, 4.0, 9) * 6)
        if c == "V" then lump = floor(vn(wx, wz, 5.0, 11) * 3) end
        top = top + lump
        local fall = 99
        for _, lvl in ipairs({ 0, lit }) do
          if lvl < top then
            local d = distTo(x, z, function(q)
              if not WALK[q] then return false end
              if q == "H" then return lvl == lit end
              if q == "S" then return lvl == 0 end
              return lvl == 0 end)
            local face = lvl + 2 + d * 3.4 + (vn(wx, wz, 1.6, 13) - 0.5) * 4
            if face < fall then fall = face end
          end
        end
        h = max(1, min(top, floor(fall)))
        kind = (c == "V") and "void" or ((c == "C") and "ceil" or "rock")
      end
    end
    H[k], K[k] = h, kind
    return h, kind
  end

  return ground, cls, level, floorOf
end

-- the 10x10 raw window (tiles -4..5) of Kit.spec: one letter at tile (i, j)
local function at10(w, i, j)
  return w:sub((j + 4) * 10 + (i + 4) + 1, (j + 4) * 10 + (i + 4) + 1)
end
-- the 6x6 window (-2..3) round the cell whose top-left tile is (ox, oz),
-- in the letters the old spec wrote: V off the map, L for a profile tile
local function cut6(w, ox, oz)
  local out = {}
  for j = -2, 3 do
    for i = -2, 3 do
      local c = at10(w, ox + i, oz + j)
      if c == "X" then c = "V" elseif c == "O" then c = "L" end
      out[#out + 1] = c
    end
  end
  return table.concat(out)
end
-- would Kit.spec build the cell whose top-left tile is (ox, oz)?
local function built2x2(w, ox, oz)
  for j = 0, 1 do
    for i = 0, 1 do
      local c = at10(w, ox + i, oz + j)
      if c == "X" or c == "O" then return false end
    end
  end
  return true
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local lit, tx, ty, win10 = key:match("^(%d+)|(%-?%d+)|(%-?%d+)|(%u+)$")
  lit, tx, ty = tonumber(lit), tonumber(tx), tonumber(ty)
  local SINK = Kit.SINK
  local OX, OZ = tx * 8, ty * 8              -- the cell's world voxel origin

  local ground, cls, level, floorOf = cellGround(lit, cut6(win10, 0, 0), OX, OZ)

  -- the four edge neighbours, rebuilt from the same rules their own models
  -- use (cellGround over their own 6x6 window, their own world origin), so
  -- this cell can tell exactly where theirs is rock: nil where there is no
  -- neighbour model (off the map, a tile not this kit's, a profile tile --
  -- Kit.spec refuses those) or where it is a ladder, whose rails this does
  -- not reproduce (its faces are kept: a seam drawn twice, as before)
  local nb = {}
  for dir, o in pairs({ e = { 2, 0 }, w = { -2, 0 }, s = { 0, 2 }, n = { 0, -2 } }) do
    if built2x2(win10, o[1], o[2]) then
      local c0 = at10(win10, o[1], o[2])
      if c0 ~= "D" and c0 ~= "U" then
        nb[dir] = cellGround(lit, cut6(win10, o[1], o[2]), OX + o[1] * 8, OZ + o[2] * 8)
      end
    end
  end
  local CULL = Buildings_CULL

  -- a ladder's frame in its cell: the cell's own local box
  local cellC = cls(0, 0)
  local ladder = (cellC == "D" or cellC == "U") and cellC or nil

  local function at(x, y0, z)
    -- y above the floor plane, which is a voxel over the drawing's own (so
    -- the two never lie in one plane and fight)
    local y = y0 - SINK - 1
    if x < 0 or x > 15 or z < 0 or z > 15 then
      -- the ring one voxel round the cell: the edge neighbour's voxel, as
      -- CULL (Buildings.CULL) where its model is solid -- a face of this
      -- cell against it is inside the rock -- and nothing at the corners.
      -- Its model is solid exactly where a non-ladder cell's at() is: from
      -- the floor plane's voxel (y -1) up to its ground, and below that too
      -- for the void.
      local g, lx, lz = nil, x, z
      if x == 16 and z >= 0 and z <= 15 then g, lx = nb.e, 0
      elseif x == -1 and z >= 0 and z <= 15 then g, lx = nb.w, 15
      elseif z == 16 and x >= 0 and x <= 15 then g, lz = nb.s, 0
      elseif z == -1 and x >= 0 and x <= 15 then g, lz = nb.n, 15 end
      if not g then return nil end
      local h, kind = g(lx, lz)
      if y < h and (y >= -1 or kind == "void") then return CULL end
      return nil
    end
    local h, kind = ground(x, z)
    local wx, wz = OX + x, OZ + z

    if ladder then
      local cx, cz = x - 7.5, z - 7.5
      if ladder == "D" then
        -- the shaft: a ring of rock round a dark opening, the ladder's
        -- rails and two rungs standing out of it (the engine's own floor
        -- plane lies under every cell, so the hole is shown, not dug)
        local r2 = cx * cx + cz * cz
        if y < h - 1 then return sw(ROCK, 3) end
        if r2 <= 16 then
          if y == h - 1 or y == h then
            local rail = abs(abs(cx) - 2) < 0.6 and abs(cz + 1) < 2.6
            if rail and y == h then return sw(WOOD_DK, 4) end
            if y == h then return nil end
            return sw(VOID, 0)
          end
          local rail = abs(abs(cx) - 2) < 0.6 and abs(cz + 1) < 0.6
          if rail and y <= h + 4 then return sw(WOOD_DK, 3 + (y % 2)) end
          if abs(cx) < 2 and abs(cz + 1) < 0.6 and (y == h + 1 or y == h + 3) then return sw(WOOD, 4) end
          return nil
        end
        if r2 <= 36 and y >= h - 1 and y <= h + 1 then
          if y == h + 1 and hash(wx, y, wz) % 3 == 0 then return nil end
          return sw(y == h + 1 and ROCK_LT or ROCK, 3 + hash(wx, y, wz) % 3)
        end
        if y == h - 1 then return sw(h > 1 and DUST or EARTH, 4 + hash(wx, 1, wz) % 3) end
        return nil
      else
        -- a rocky collar on the floor, the ladder standing out of it
        local rail = (abs(cx + 2.5) < 0.6 or abs(cx - 2.5) < 0.6) and abs(cz + 1.5) < 0.6
        local rung = abs(cx) < 2.5 and abs(cz + 1.5) < 0.6 and ((y - h) % 3 == 1)
        if y >= h and y <= h + 22 and (rail or rung) then
          return sw((rail and WOOD_DK) or WOOD, 3 + ((y - h) > 16 and -1 or 1) + (y % 2))
        end
        local r2 = cx * cx + (cz + 1.5) * (cz + 1.5)
        if y >= h and y <= h + 1 and r2 <= 14 and r2 >= 7 and hash(wx, y, wz) % 3 ~= 0 then
          return sw(ROCK, 3 + hash(wx, y, wz) % 3)
        end
        if y < h - 1 then return sw(ROCK, 3) end
        if y == h - 1 then return sw(h > 0 and DUST or EARTH, 4 + hash(wx, 1, wz) % 3) end
        return nil
      end
    end

    if y >= h then return nil end
    if y < -1 then
      return (kind == "void" and sw(VOID, 1)) or nil
    end
    local top = y == h - 1
    if kind == "floor" or kind == "mouth" then
      if not top then return sw(EARTH_DK, 2) end
      if kind == "mouth" then return sw(LIGHT, 3 + hash(wx, 0, wz) % 3) end
      if hash(wx, 7, wz) % 23 == 0 then return sw(PEBBLE, 3 + hash(wx, 8, wz) % 3) end
      local n = vn(wx, wz, 5.0, 21) * 0.65 + vn(wx, wz, 2.0, 22) * 0.35
                + (hash(wx, 6, wz) % 7 - 3) * 0.02
      if n < 0.30 then return sw(EARTH_DK, 4 + hash(wx, 2, wz) % 2) end
      -- a fine speckle over a slow mottle, as the drawing's floor is speckled
      return sw(EARTH, 1 + floor(n * 3) + hash(wx, 3, wz) % 4)
    end
    if kind == "scree" then
      if not top then return sw(EARTH_DK, 2) end
      return sw(ROCK, 3 + hash(wx, 4, wz) % 3)
    end
    if kind == "shelf" or kind == "stair" then
      if top then
        if kind == "stair" and z % 2 == 1 then return sw(ROCK_DK, 3) end   -- the tread's nosing shadow
        if hash(wx, 9, wz) % 19 == 0 then return sw(PEBBLE, 4) end
        local n = vn(wx, wz, 4.0, 23) * 0.7 + vn(wx, wz, 1.6, 24) * 0.3
        -- broad drifts of darker earth across a wide dust floor, so a
        -- cave that is all shelf (Diglett's) does not read as one colour
        local drift = vn(wx, wz, 14.0, 25)
        if drift < 0.30 then return sw(EARTH, 2 + floor(n * 3) + hash(wx, 6, wz) % 3) end
        if drift < 0.38 and hash(wx, 7, wz) % 2 == 0 then return sw(EARTH, 4 + hash(wx, 8, wz) % 2) end
        return sw(DUST, 1 + floor(n * 3) + hash(wx, 5, wz) % 4)
      end
      -- the shelf's own body, seen at a stair's side
      return sw(ROCK, 2 + hash(floor(wx / 2), floor(y / 2), floor(wz / 2)) % 4)
    end
    -- rock
    if kind == "void" then
      if y >= h - 2 then return sw(VOID, 3 + hash(wx, y, wz) % 2) end
      if y >= h - 8 then return sw(VOID, 2) end
      return sw(VOID, 1 + (hash(wx, y, wz) % 5 == 0 and 2 or 0))
    end
    -- (the "ceiling" mass, the drawing's pale block grid, is the same rock a
    -- shade paler: pale outcrops, not masonry)
    local pale = kind == "ceil" and 1 or 0
    if top then return sw(ROCK_LT, 2 + pale + hash(wx, y, wz) % 3) end
    -- jointed faces: courses that wander, darker low down, paler joints of
    -- weathering up top
    local course = floor((y + floor(vn(wx, wz, 3.0, 31) * 3)) / 3)
    if (y + floor(wx / 3) + floor(wz / 3) * 2) % 7 == 0 then return sw(ROCK_DK, 2) end
    local shade = 2 + floor(min(y, 14) / 5) + hash(floor(wx / 2), course, floor(wz / 2)) % 2
    return sw(pale == 1 and ROCK_LT or ROCK, shade - pale * 2)
  end

  -- the cell stands at its walkable level
  -- (the collision tile is the cell's bottom-left: its class decides)
  local cc = cls(0, 1)
  local stand = level(cc) or 0
  if cc == "S" then stand = floor(lit / 2) end
  if cc == "D" or cc == "U" then stand = floorOf(0, 1) end
  stand = stand + 1
  local mask = { true, true, true, true }
  -- The box's top is the highest voxel this cell can answer, not a bound
  -- for every cave: emit walks the whole box about eight times, and the old
  -- `max(lit, VOID_H) + 26` (52 voxels) left 40-60% of it air above Mt.
  -- Moon's rock (kanto_shots_probe: cave_ground 11.5 s for MT_MOON_1F).
  -- at() is solid only below the column's ground (y < h) -- a ladder adds
  -- its rails, h + 22 up and h + 4 down -- and emit reads past ytop as air,
  -- so cutting the box exactly there changes no voxel and no face.
  local hmax = 0
  for z = 0, 15 do
    for x = 0, 15 do
      local h = ground(x, z)
      if h > hmax then hmax = h end
    end
  end
  local reach = hmax - 1
  if ladder == "U" then reach = hmax + 22 elseif ladder == "D" then reach = hmax + 4 end
  local ytop = SINK + 1 + reach
  -- emit's colTop: the highest y0 at() can answer in a column. A plain
  -- column is solid to its ground and no higher (y < h, y0 = y + SINK + 1,
  -- so y0 <= SINK + h); a ladder cell's rails stand over its ground, so it
  -- keeps the whole box. The ring follows the neighbour's ground the same
  -- way, and a corner -- or a side with no neighbour model -- holds nothing.
  local function colTop(x, z)
    if x >= 0 and x <= 15 and z >= 0 and z <= 15 then
      if ladder then return ytop end
      local h = ground(x, z)
      return SINK + h
    end
    local g, lx, lz = nil, x, z
    if x == 16 and z >= 0 and z <= 15 then g, lx = nb.e, 0
    elseif x == -1 and z >= 0 and z <= 15 then g, lx = nb.w, 15
    elseif z == 16 and x >= 0 and x <= 15 then g, lz = nb.s, 0
    elseif z == -1 and x >= 0 and x <= 15 then g, lz = nb.n, 15 end
    if not g then return -1 end
    local h = g(lx, lz)
    return SINK + h
  end
  return { at = at, W = 16, xmin = -1, xmax = 16, zmin = -1, zmax = 16,
           ytop = ytop, sink = SINK, claimMask = mask, standH = stand,
           colTop = colTop }
end

return Kit
