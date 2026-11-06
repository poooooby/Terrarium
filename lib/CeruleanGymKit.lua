-- Voxel world mode: Misty's Gym in Cerulean INSIDE -- a swimming hall.
--
-- The drawing is a pool (20, the water) crossed by a walkway of boards (17,
-- its north lip 1), white rails on the pool side of the walkways (4, the top
-- half of a water cell), the hall's edge in big square tiles (9/10 over
-- 25/26) and the north wall band (5 over 16); two statues before the
-- arena, the mat at the door. What stands here, on the homes' shell
-- (lib/HomeLib.lua: no south wall, no ceiling):
--
--   the band     a wall of white glazed tiles with a sea-blue stripe and a
--                deep blue skirting, 28 tall
--   the edge     the hall's tiled surround: a raised ledge of white and blue
--                tiles in a checker, eight voxels tall, cut down toward the
--                camera like the homes' side walls
--   the deck     teak boards running north-south, a stone coping a voxel
--                proud along every side that meets the water
--   the rails    chrome posts every four with a top rail and a mid rail,
--                along the walkway's water side
--
-- The water is the developer's (the profile's basin, Water.BED), so its
-- cells are left to it; so are the statues (`gym_statue`) and the mat.
-- 160 x 224 voxels, x east, z south. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/cerulean_gym.png", SHEET_W = 8, SHEET_H = 10 }
Kit.MAPS = { CERULEAN_GYM = 1 }

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local sw = Lib.sw
local TILE_W, TILE_B, GROUT, BOARD, BOARD_DK, CHROME, STEEL, COPING, DARK, TILE_D =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local EDGE = { [9] = true, [10] = true, [25] = true, [26] = true }
local DECK = { [17] = true, [1] = true }
local BAND = { [5] = true, [16] = true }
local LEDGE_H, WALL_H = 8, 28

local function build(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  local function tileAt(x, z) return tile(floor(x / 8), floor(z / 8)) end
  local function water(x, z)
    local v = tileAt(x, z)
    return v == 20 or v == 4
  end

  return function(x, y, z)
    if x < 0 or x > W - 1 or z < 0 or z > D - 1 or y < 0 then return nil end
    local v = tileAt(x, z)
    if BAND[v] then
      if y > WALL_H then return nil end
      if y <= 2 then return sw(TILE_D, 3) end
      if y >= 18 and y <= 20 then return sw(TILE_B, 4) end
      if y == WALL_H then return sw(TILE_W, 6) end
      if x % 6 == 0 or y % 6 == 3 then return sw(GROUT, 4) end
      return sw(TILE_W, 4 + hash(floor(x / 6), floor(y / 6), 1) % 2)
    end
    if EDGE[v] then
      local h = LEDGE_H
      if y > h then return nil end
      if y == 0 then return sw(GROUT, 3) end
      local face = y < h
      local gx, gz = floor(x / 8), floor(z / 8)
      if not face then
        if x % 8 == 0 or z % 8 == 0 then return sw(GROUT, 5) end
        return sw((gx + gz) % 2 == 0 and TILE_W or TILE_B, (gx + gz) % 2 == 0 and 5 or 4)
      end
      if y == 1 then return sw(TILE_D, 3) end
      if x % 8 == 0 or z % 8 == 0 or y == 4 then return sw(GROUT, 3) end
      return sw((gx + gz + (y > 4 and 1 or 0)) % 2 == 0 and TILE_W or TILE_B, 3)
    end
    if v == 4 then
      -- the rail: on the walkway's edge (the north strip of this water
      -- tile's cell), chrome posts every four, a top rail and a mid rail
      local lz = z % 8
      if lz < 6 then
        -- the coping the rail stands on, the deck carried out over the edge
        if y == 0 then return sw(COPING, 4 + (lz == 5 and 1 or 0)) end
        if lz == 2 or lz == 3 then
          if y >= 1 and y <= 9 and x % 4 == 0 then return sw(STEEL, 3 + (y == 9 and 2 or 0)) end
          if y == 9 or y == 5 then return sw(CHROME, y == 9 and 6 or 4) end
        end
        return nil
      end
      return nil
    end
    if DECK[v] then
      if y > 1 then return nil end
      -- the coping along any side that meets the water
      local nearW = water(x - 1, z) or water(x + 1, z) or water(x, z - 1) or water(x, z + 1)
      if nearW then return sw(COPING, y == 1 and 5 or 3) end
      if y == 1 then return nil end
      local plank = floor(x / 4)
      if x % 4 == 0 then return sw(BOARD_DK, 3) end
      if (z + plank * 11) % 28 == 0 then return sw(BOARD_DK, 4) end
      return sw(BOARD, 3 + hash(plank, floor((z + plank * 11) / 28), 3) % 4)
    end
    return nil
  end, W, D
end

function Kit.model(sp, t, mapId)
  if not Kit.MAPS[mapId] then return nil, "not Misty's Gym: " .. tostring(mapId) end
  local at, W, D = build(t)
  -- the water, the statues and the mat stay unclaimed: the profile builds
  -- the basin and stands the statues, the mat is drawn
  local open = { [20] = true, [2] = true, [56] = true, [18] = true, [19] = true,
                 [34] = true, [35] = true, [50] = true, [51] = true, [6] = true, [22] = true }
  local m, why = Lib.model(Kit, sp, t, at, open)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, 30
  return m
end

return Kit
