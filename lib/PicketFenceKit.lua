-- Voxel world mode: a village's FENCE -- white pickets (Pallet Town).
--
-- The same cell lib/FenceKit.lua builds Vermilion's crossbuck timber from
-- (the overworld's two posts a cell, $0E over $55), in a quiet village's
-- hand instead: a kit's look stays in its own town. The run logic is
-- FenceKit's own -- rails only toward a neighbour that is fence too, a run
-- reaching a joined map edge taken to carry on -- so the two read as one
-- family:
--
--   the post     three voxels square, one to a cell, on a stone foot, its
--                top cut to a point
--   the rails    two, low and high, on the north (or west) side of the
--                pickets, so from the road the pickets stand in front
--   the pickets  one voxel thick, two wide, a voxel apart, their tops
--                pointed; here and there the wood shows where the paint wore
--
-- One model per signature. Nothing here is extracted from the ROM.
local V = ...
local FenceKit = V.require("FenceKit")

local Kit = { SHEET = "assets/buildings/picket_fence.png", SHEET_W = 8, SHEET_H = 7,
              POST_H = 12, LOW = 3, TOP = 8, PICKET = 10 }

local PAINT, SHADE, STONE, WOOD = 0, 1, 2, 3
local function sw(row, n) return row * 8 + n % 8 end
local C = 16

-- the run logic is FenceKit's, to the letter
Kit.signature = FenceKit.signature

-- each arm in its own frame: `a` from the post's face (0) out to the cell's
-- edge (6), `d` across (0..2 over the post's three voxels)
local ARMS = {
  function(x, z) return 6 - z, x - 7 end,       -- north
  function(x, z) return x - 10, z - 7 end,      -- east
  function(x, z) return z - 10, x - 7 end,      -- south
  function(x, z) return 6 - x, z - 7 end,       -- west
}

function Kit.model(sp, sig)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local on = {}
  for i = 1, 4 do on[i] = sig:sub(i, i) == "1" end
  local H, LOW, TOP, P = Kit.POST_H, Kit.LOW, Kit.TOP, Kit.PICKET

  local function at(x, y, z)
    -- the post, x/z 7..9, on its stone foot, its top a point
    if x >= 7 and x <= 9 and z >= 7 and z <= 9 then
      if y <= 1 then return sw(STONE, 3 + (x + z) % 2) end
      if y < H then return sw(PAINT, (x == 9 or z == 9) and 5 or 4) end
      if y == H and x == 8 and z == 8 then return sw(PAINT, 6) end
      return nil
    end
    for i = 1, 4 do
      if on[i] then
        local a, d = ARMS[i](x, z)
        if a >= 0 and a <= 6 and d >= 0 and d <= 2 then
          -- along the run, in its own direction, so the pickets keep their
          -- spacing from one cell's arm into the next's
          local along = (i == 2 or i == 3) and (10 + a) or (6 - a)
          -- the rails on the back face (d 0), the pickets on the front (d 2)
          if d == 0 and (y == LOW or y == TOP) then return sw(SHADE, 4) end
          if d == 2 then
            local k = along % 3                               -- picket, picket, gap
            if k ~= 2 and y >= 1 then
              local top = P - ((k == 0) and 0 or 1)           -- a pointed top
              if y <= top then
                local worn = (along * 7 + y) % 53 == 0
                return worn and sw(WOOD, 4) or sw(PAINT, (k == 0) and 5 or 6)
              end
            end
          end
        end
      end
    end
    return nil
  end

  return { at = at, W = C, ytop = H, zmin = 0, zmax = C - 1 }
end

return Kit
