-- Voxel world mode: the Safari Zone's fences, built as fences.
--
-- The FOREST sheet draws them face-on, three tiles tall: a post (10/11 its
-- rounded cap, 26/27 its body, 75/76 its foot) every few cells, the rails
-- between (66 over 67). What stands here: a squared timber post on a
-- stone foot, a rounded cap, two split rails between the posts at knee and
-- hip height -- all on the line of the drawing's lowest row (the foot's
-- and the lower rail's tile), the rows above it what the post's height
-- covers. One cell at a time (Buildings' `cellKit`): only the fence's
-- tiles are claimed, the turf under them is the meadow's
-- (tools/kanto_ground.py lays it). Nothing here is extracted from the ROM.
local V = ...

local Kit = { SHEET = "assets/buildings/picket_fence.png", SHEET_W = 8, SHEET_H = 7 }

local PAINT, SHADE, STONE, WOOD, RAIL, BARK, IRON = 0, 1, 2, 3, 4, 5, 6
local function sw(row, n) return row * 8 + math.max(0, math.min(7, n)) end
local floor = math.floor

Kit.MAPS = { SAFARI_ZONE_CENTER = true, SAFARI_ZONE_EAST = true, SAFARI_ZONE_NORTH = true,
             SAFARI_ZONE_WEST = true }
-- a, b: the post's drawn height (nothing stands in them); P/Q its foot,
-- west and east half; r: the upper rail's tile (height only); R the rails
local KIND = { [10] = "a", [11] = "a", [26] = "b", [27] = "b", [75] = "P", [76] = "Q",
               [66] = "r", [67] = "R" }

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

local POST_H = 22

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
    if x < 0 or x > 15 or z < 0 or z > 15 or y < 0 then return nil end
    local i = (z >= 8 and 2 or 0) + (x >= 8 and 2 or 1)
    local k = kinds[i]
    if not k or k == "a" or k == "b" or k == "r" then return nil end
    local lx, lz = x % 8, z % 8
    if k == "P" or k == "Q" then
      -- the post: its west half in P (lx 4..7), its east half in Q (0..3)
      local px = (k == "P") and (lx - 4) or (lx + 4)      -- 0..7 across the post
      if px < 0 or px > 7 or lz < 2 or lz > 6 then
        -- the rails run on into the post's tile from the open side
        if lz >= 3 and lz <= 4 and (y == 7 or y == 8 or y == 14 or y == 15) then
          return sw(RAIL, (y == 8 or y == 15) and 5 or 3)
        end
        return nil
      end
      if y <= 3 then
        if px == 0 or px == 7 or lz == 2 or lz == 6 then return sw(STONE, 3 + (y == 3 and 2 or 0)) end
        return sw(STONE, 4)
      end
      if y < POST_H then
        if px == 0 or lz == 2 then return sw(BARK, 3) end
        if y % 6 == 0 then return sw(BARK, 4) end                       -- the grain
        return sw(RAIL, 3 + (px >= 5 and 1 or 0))
      end
      -- the cap: rounded, a voxel proud
      local cx, cz = px - 3.5, lz - 4
      local h = y - POST_H
      if h <= 2 and cx * cx + cz * cz <= 9 - h * 3 then return sw(BARK, 4 + h) end
      return nil
    end
    -- the rails: two split rails along the drawing's lower row, a voxel
    -- and a half thick, the upper one a little lighter
    if lz >= 3 and lz <= 4 then
      if y == 7 or y == 8 then return sw(RAIL, y == 8 and 4 or 3) end
      if y == 14 or y == 15 then return sw(RAIL, y == 15 and 5 or 3) end
    end
    return nil
  end
  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15, ytop = POST_H + 3,
           claimMask = mask, standH = 0 }
end

return Kit
