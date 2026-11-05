-- Voxel world mode: a stone city's FENCE -- granite bollards and a chain
-- (Pewter City).
--
-- The same cell as lib/PicketFenceKit.lua (the overworld's two posts a
-- cell, $0E over $55) and its run logic (FenceKit's: a chain only toward a
-- neighbour that is fence too, carried on over a joined map edge), in the
-- hand of the city of stone -- the drawing's posts are round, so they stand
-- as bollards:
--
--   the post   a granite bollard six across with its corners rounded off,
--              ten tall, a domed cap
--   the chain  one iron chain from post to post, sagging to its lowest
--              half way between, the links alternating light and dark
--
-- One model per signature; the sheet is the picket fence's
-- (tools/picket_fence.py, its STONE and IRON rows). Nothing here is
-- extracted from the ROM.
local V = ...
local FenceKit = V.require("FenceKit")

local Kit = { SHEET = "assets/buildings/picket_fence.png", SHEET_W = 8, SHEET_H = 7,
              POST_H = 10 }

local PAINT, SHADE, STONE, WOOD, RAIL, BARK, IRON = 0, 1, 2, 3, 4, 5, 6
local function sw(row, n) return row * 8 + n % 8 end
local C = 16
local floor, abs, sin, pi = math.floor, math.abs, math.sin, math.pi

Kit.signature = FenceKit.signature

-- each arm in its own frame: `a` from the post's centre out to the cell's
-- edge (0..8), `d` across (0 on the chain's line)
local ARMS = {
  function(x, z) return 7.5 - z, x - 7 end,     -- north
  function(x, z) return x - 7.5, z - 7 end,     -- east
  function(x, z) return z - 7.5, x - 7 end,     -- south
  function(x, z) return 7.5 - x, z - 7 end,     -- west
}

function Kit.model(sp, sig)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local on = {}
  for i = 1, 4 do on[i] = sig:sub(i, i) == "1" end
  local H = Kit.POST_H

  local function at(x, y, z)
    -- the bollard: x/z 5..10, its corners rounded, a dome over y H
    local dx, dz = x - 7.5, z - 7.5
    local r2 = dx * dx + dz * dz
    if r2 <= 9.5 then
      if y < H then
        if y == 0 then return sw(STONE, 2) end
        return sw(STONE, 3 + ((dx < 0) and 1 or 0) + (y % 4 == 0 and 0 or 1))
      end
      if y == H and r2 <= 5 then return sw(STONE, 6) end
      if y == H + 1 and r2 <= 1.5 then return sw(STONE, 7) end
      return nil
    end
    for i = 1, 4 do
      if on[i] then
        local a, d = ARMS[i](x, z)
        if a >= 3.2 and a <= 8 and (d == 0 or d == 1) then
          -- the sag: at the post y 8, at the span's middle (the cell edge) y 5
          local cy = 8 - floor(3 * sin(pi * a / 16) + 0.5)
          local link = floor(a) % 2
          if (d == 0 and y == cy and link == 0) or (d == 1 and y == cy and link == 1) then
            return sw(IRON, link == 0 and 4 or 2)
          end
        end
      end
    end
    return nil
  end

  return { at = at, W = C, ytop = H + 1, zmin = 0, zmax = C - 1 }
end

return Kit
