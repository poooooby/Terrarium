-- Voxel world mode: a forest town's FENCE -- split rails (Viridian City).
--
-- The same cell as lib/PicketFenceKit.lua (the overworld's two posts a
-- cell, $0E over $55) and its run logic (FenceKit's: rails only toward a
-- neighbour that is fence too, carried on over a joined map edge), in the
-- hand of the town at the forest's edge:
--
--   the post   a round-ish trunk four voxels across, bark-dark, its top cut
--              off flat with a lighter end grain
--   the rails  two split rails, low and high, each two voxels deep, their
--              shade varying along the run the way cleft oak does
--
-- One model per signature; the sheet is the picket fence's
-- (tools/picket_fence.py, its RAIL and BARK rows). Nothing here is
-- extracted from the ROM.
local V = ...
local FenceKit = V.require("FenceKit")

local Kit = { SHEET = "assets/buildings/picket_fence.png", SHEET_W = 8, SHEET_H = 7,
              POST_H = 12, LOW = 3, TOP = 8 }

local PAINT, SHADE, STONE, WOOD, RAIL, BARK = 0, 1, 2, 3, 4, 5
local function sw(row, n) return row * 8 + n % 8 end
local C = 16
local floor = math.floor

Kit.signature = FenceKit.signature

-- each arm in its own frame: `a` from the post (0) out to the cell's edge
-- (5), `d` across (0..1, the rail's depth)
local ARMS = {
  function(x, z) return 5 - z, x - 7 end,       -- north
  function(x, z) return x - 10, z - 7 end,      -- east
  function(x, z) return z - 10, x - 7 end,      -- south
  function(x, z) return 5 - x, z - 7 end,       -- west
}

function Kit.model(sp, sig)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local on = {}
  for i = 1, 4 do on[i] = sig:sub(i, i) == "1" end
  local H, LOW, TOP = Kit.POST_H, Kit.LOW, Kit.TOP

  local function at(x, y, z)
    -- the post: x/z 6..9 with its corners cut, so it reads as a trunk
    if x >= 6 and x <= 9 and z >= 6 and z <= 9 then
      local corner = (x == 6 or x == 9) and (z == 6 or z == 9)
      if corner then return nil end
      if y < H then return sw(BARK, 3 + (x + y) % 3) end
      if y == H then return sw(WOOD, 5) end                -- the end grain
      return nil
    end
    for i = 1, 4 do
      if on[i] then
        local a, d = ARMS[i](x, z)
        if a >= 0 and a <= 5 and d >= 0 and d <= 1 then
          local along = (i == 2 or i == 3) and (10 + a) or (5 - a)
          if y == LOW or y == LOW + 1 or y == TOP or y == TOP + 1 then
            local top = (y == LOW + 1 or y == TOP + 1)
            return sw(RAIL, (top and 4 or 2) + floor(along / 3) % 2)
          end
        end
      end
    end
    return nil
  end

  return { at = at, W = C, ytop = H, zmin = 0, zmax = C - 1 }
end

return Kit
