-- Voxel world mode: the RAILINGS along a walkway (Route 5, Cerulean's south
-- exit), built as railings.
--
-- The overworld draws them from straight above: $10 (16) a white pole two
-- dark lines wide running north-south, $21 (33) the round knob at each end
-- of a run. What stands here: a white tube rail on posts -- a post every
-- eight voxels, the rail at hand height, a ball-topped newel at each end --
-- along the line the drawing puts it (x 2..5 in its tile).
--
-- One cell at a time (Buildings' `cellKit`): the spec says which of the
-- cell's tiles are rail or knob, and only those are claimed; the cell's
-- ground is the meadow world's (tools/kanto_ground.py lays it, LAID).
-- Nothing here is extracted from the ROM.
local V = ...

local Kit = { SHEET = "assets/buildings/picket_fence.png", SHEET_W = 8, SHEET_H = 7 }

local PAINT, SHADE, STONE, WOOD, RAIL, BARK, IRON = 0, 1, 2, 3, 4, 5, 6
local function sw(row, n) return row * 8 + n % 8 end
local floor, abs = math.floor, math.abs

Kit.MAPS = { CERULEAN_CITY = true, ROUTE_5 = true }
local KIND = { [16] = "r", [33] = "k" }

function Kit.spec(tileAt, tx, ty, mapId)
  if Kit.ENABLED == false or not Kit.MAPS[mapId] then return nil end
  local s, any = "", false
  for _, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local k = KIND[tileAt(tx + d[1], ty + d[2])]
    if k then any = true end
    s = s .. (k or ".")
  end
  if not any then return nil end
  return s
end

function Kit.model(sp, key)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local kinds, mask = {}, {}
  for i = 1, 4 do
    local k = key:sub(i, i)
    kinds[i] = k ~= "." and k or nil
    mask[i] = kinds[i] ~= nil
  end
  local function at(x, y, z)
    if x < 0 or x > 15 or z < 0 or z > 15 then return nil end
    local i = (z >= 8 and 2 or 0) + (x >= 8 and 2 or 1)
    local k = kinds[i]
    if not k then return nil end
    local lx, lz = x % 8, z % 8
    if k == "k" then
      -- the newel: a post to y 9, a ball on it
      local dx, dz = lx - 3.5, lz - 3.5
      local d2 = dx * dx + dz * dz
      if y <= 9 and d2 <= 2.6 then return sw(PAINT, y == 0 and 2 or 4 + (dx < 0 and 1 or 0)) end
      if y >= 10 and y <= 13 and d2 + (y - 11.5) ^ 2 <= 4.5 then return sw(PAINT, 6) end
      -- the rail meets it from the run's side
      if y >= 9 and y <= 10 and lx >= 3 and lx <= 4 then return sw(PAINT, 5) end
      return nil
    end
    -- the rail: a tube at y 9..10 along z, a post every eight
    if lx < 3 or lx > 4 then return nil end
    if y >= 9 and y <= 10 then return sw(y == 10 and PAINT or SHADE, y == 10 and 6 or 4) end
    if lz == 3 and y <= 8 then return sw(SHADE, y == 0 and 2 or 4) end
    return nil
  end
  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15, ytop = 14,
           claimMask = mask, standH = 0 }
end

return Kit
