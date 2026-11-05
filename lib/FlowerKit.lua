-- Voxel world mode: the FLOWERS of a flowerbed, built as flowers.
--
-- The overworld draws its bed as a tile of little blossoms ($03), and the
-- profile stood each as a one-pixel cutout of the drawing: under a town's
-- palette a field of pale blots that read as puddles. What stands here is
-- the bed: on every flower tile four plants, each a stem with two leaves
-- and a blossom -- a heart and four petals -- at its own height and in one
-- of the town's three colours, placed by hash so a bed is not a stamp.
--
-- One cell (2x2 tiles) at a time, like the reef (lib/ReefKit.lua): the
-- template matches any cell of the town's maps (`wild`), the spec says which
-- of its four tiles are flowers (bits) and the cell's place (for the hash),
-- and only the flower tiles are claimed -- grass beside them keeps its own
-- drawing, and the ground under the flowers is the neighbours' vote, as it
-- was under the cutout. Flowers stand in walkable cells: nothing is taller
-- than a shin.
--
-- Nothing here is extracted from the ROM; the colours are the sheet's
-- (tools/flower_kit.py), each town's three listed in TOWNS.
local V = ...

local Kit = { SHEET = "assets/buildings/flower_kit.png", SHEET_W = 8, SHEET_H = 10,
              FLOWER = { [3] = true },
              -- keyed on the cell: kept per map, not per session (CaveKit)
              PER_CELL = true }

local STEM, LEAF, CENTRE, RED, WHITE, YELLOW, PINK, LILAC, BLUE, ORANGE =
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9
local function sw(row, n) return row * 8 + n % 8 end

-- each town's beds: three petal colours
Kit.TOWNS = {
  PALLET_TOWN = { RED, WHITE, YELLOW },
  ROUTE_1 = { RED, WHITE, YELLOW },
  -- the forest's edge: buttercup yellow, white, a little orange
  VIRIDIAN_CITY = { YELLOW, WHITE, ORANGE },
  ROUTE_22 = { YELLOW, WHITE, LILAC },
  ROUTE_2 = { YELLOW, WHITE, ORANGE },
  -- the city of stone: pink, white and lilac in its granite beds
  PEWTER_CITY = { PINK, WHITE, LILAC },
  ROUTE_3 = { YELLOW, WHITE, LILAC },
  ROUTE_4 = { YELLOW, WHITE, LILAC },
  -- the city on the water: yellow, white and sky blue
  CERULEAN_CITY = { YELLOW, WHITE, BLUE },
  ROUTE_24 = { YELLOW, WHITE, BLUE },
  ROUTE_25 = { YELLOW, WHITE, BLUE },
  ROUTE_5 = { RED, WHITE, YELLOW },
  ROUTE_9 = { YELLOW, WHITE, LILAC },
  SAFFRON_CITY = { YELLOW, WHITE, ORANGE },
  CELADON_CITY = { PINK, WHITE, LILAC },
  FUCHSIA_CITY = { PINK, WHITE, RED },
  CINNABAR_ISLAND = { RED, WHITE, ORANGE },
}
local DEFAULT = { RED, WHITE, YELLOW }

local floor, abs = math.floor, math.abs
local function hash(a, b, c) return (a * 73856093 + b * 19349663 + c * 83492791) % 4093 end

-- "<bits>:<cx>:<cy>:<town>", or nil when no tile of the cell is a flower
function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false then return nil end
  local bits = 0
  for i, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    if Kit.FLOWER[tileAt(tx + d[1], ty + d[2])] then bits = bits + 2 ^ (i - 1) end
  end
  if bits == 0 then return nil end
  return ("%d:%d:%d:%s"):format(bits, tx, ty, tostring(mapId))
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local bits, tx, ty, mapId = key:match("^(%d+):(%-?%d+):(%-?%d+):(.*)$")
  bits, tx, ty = tonumber(bits), tonumber(tx), tonumber(ty)
  local colours = Kit.TOWNS[mapId] or DEFAULT

  -- the plants: three per flower tile, each { x, z, h, colour, turn }
  local plants = {}
  local mask = {}
  for i, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local on = floor(bits / 2 ^ (i - 1)) % 2 == 1
    mask[i] = on
    if on then
      local ox, oz = d[1] * 8, d[2] * 8
      local wx, wz = (tx + d[1]) * 8, (ty + d[2]) * 8
      -- four, one to each quarter of the tile and jittered in it, so the bed
      -- is full without two plants growing through each other
      for p = 1, 4 do
        local h0 = hash(wx + p, wz, p * 7)
        local qx, qz = (p - 1) % 2, floor((p - 1) / 2)
        plants[#plants + 1] = {
          x = ox + 1 + qx * 4 + (h0 % 3),
          z = oz + 1 + qz * 4 + floor(h0 / 3) % 3,
          h = 3 + floor(h0 / 36) % 3,                       -- 3..5
          c = colours[(floor(h0 / 108) + p) % 3 + 1],
          turn = floor(h0 / 324) % 2,                       -- which way the leaves go
        }
      end
    end
  end

  local function at(x, y, z)
    for _, pl in ipairs(plants) do
      local px, pz = floor(pl.x), floor(pl.z)
      local dx, dz = x - px, z - pz
      if abs(dx) <= 1 and abs(dz) <= 1 then
        local h = pl.h
        -- the blossom: a heart and four petals, a petal tip under each
        if y == h + 1 then
          if dx == 0 and dz == 0 then return sw(CENTRE, 5) end
          if abs(dx) + abs(dz) == 1 then return sw(pl.c, 5 + (dx + dz + 2) % 2) end
        end
        if y == h and abs(dx) + abs(dz) == 1 and (dx == 1 or dz == 1) then
          return sw(pl.c, 3)                                  -- the cup's shadow side
        end
        -- the stem, and a leaf each side low down
        if dx == 0 and dz == 0 and y >= 0 and y <= h then return sw(STEM, 3 + y % 2) end
        if y == 1 and ((pl.turn == 0 and dx ~= 0 and dz == 0) or (pl.turn == 1 and dz ~= 0 and dx == 0)) then
          return sw(LEAF, 4)
        end
      end
    end
    return nil
  end

  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15, ytop = 7,
           claimMask = mask, standH = 0 }
end

return Kit
