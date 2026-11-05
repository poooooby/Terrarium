-- Voxel world mode: the CAVE MOUTHS in the overworld's rock (Mt. Moon,
-- Diglett's Cave, Rock Tunnel, Seafoam, Cerulean Cave), built as mouths.
--
-- Gen 1 draws one: a round black hole in a ring of rock (72/73 over 88/89),
-- a cell of its own, walked into. On the flat ground it lay as a black disc.
-- What stands here: a rock face as tall as the massifs beside it
-- (lib/MassifKit.lua, 20), a round-headed opening in it two thirds of the
-- cell wide, its reveal of darker rock going back into the dark, a sill of
-- trodden earth in front. One cell at a time (Buildings' `cellKit`); the
-- four tiles are claimed. Nothing here is extracted from the ROM.
local V = ...

local Kit = { SHEET = "assets/buildings/massif.png", SHEET_W = 8, SHEET_H = 8 }

local ROCK, ROCK_B, ROCK_DK, ROCK_LT, TURF, TURF_DK, STONE, EARTH = 0, 1, 2, 3, 4, 5, 6, 7
local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
local function sw(row, n) return row * 8 + max(0, min(7, floor(n))) end
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local H = 20

function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false then return nil end
  if tileAt(tx, ty) == 72 and tileAt(tx + 1, ty) == 73 and tileAt(tx, ty + 1) == 88
     and tileAt(tx + 1, ty + 1) == 89 then
    return "mouth"
  end
  return nil
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  -- the opening's head: a round arch over x 3..12, springing at 6
  local function archTop(x)
    local u = (x - 7.5) / 5
    if u <= -1 or u >= 1 then return -1 end
    return 6 + 9 * sqrt(1 - u * u)
  end
  local function at(x, y, z)
    if x < 0 or x > 15 or z < 0 or z > 15 or y < 0 or y > H then return nil end
    -- in front of the face: the sill, trodden earth
    if z >= 10 then
      if y > 0 then return nil end
      return sw(EARTH, 3 + hash(x, z, 1) % 3)
    end
    local inOpening = y < archTop(x)
    if inOpening then
      -- the reveal: the face's rock turning in, darker with depth, then dark
      if y == 0 then return sw(ROCK_DK, max(0, 3 - floor((9 - z) / 3))) end
      if z <= 3 then return sw(ROCK_DK, 0) end
      return nil
    end
    if y == H then
      -- the top, heath like the massifs'
      local r = hash(x, z, 3)
      if r < 8 then return sw(STONE, 3 + r % 3) end
      return sw(TURF, 3 + r % 3)
    end
    -- the face: strata, joints, a lit ring round the opening
    local ring = (y >= archTop(x) and y < archTop(x) + 1.5)
              or ((x == 2 or x == 13) and y < 7)
    if ring and z == 9 then return sw(ROCK_LT, 5) end
    local course = floor(y / 4)
    if y % 4 == 3 then return sw(ROCK_LT, 3) end
    if (x + z + course * 5) % 9 == 0 then return sw(ROCK_DK, 3) end
    return sw((course % 2 == 0) and ROCK or ROCK_B, 3 + hash(floor(x / 3), course, 2) % 3)
  end
  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15, ytop = H + 1,
           claimMask = { true, true, true, true }, standH = 0 }
end

return Kit
