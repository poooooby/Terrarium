-- Voxel world mode: a town's SIGNS, built as signs.
--
-- The overworld draws a sign as a board seen a little from above -- a dark
-- frame, a white face with two rows of lettering, a post under it a voxel
-- right of the middle (70/71 over 86/87) -- and the profile stood it as a
-- flat card on two stubs, a low box. What stands here is that board: a
-- frame of dark wood two voxels thick round a painted face, the lettering
-- as two rows of dashes, a capping strip along its top, the board at chest
-- height on one post with a stone foot. It faces south, the way the player
-- reads it.
--
-- One model for every sign (the drawing is the same everywhere); which maps
-- carry it is the template's `maps`, so a town gets it when it is finished.
-- Nothing here is extracted from the ROM.
local V = ...

local Kit = { SHEET = "assets/buildings/sign_kit.png", SHEET_W = 8, SHEET_H = 5 }

local WOOD, FRAME, FACE, INK, STONE = 0, 1, 2, 3, 4
local function sw(row, n) return row * 8 + n % 8 end

-- the lettering: two rows of dashes, the drawing's rhythm
local TEXT = { "XX.X.XXX.XX", "X.XXX.XX.X." }

function Kit.model(sp)
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local function at(x, y, z)
    -- the post, x 8..9, z 8..9, on a stone foot
    if x >= 8 and x <= 9 and z >= 8 and z <= 9 and y <= 8 then
      if y == 0 then return sw(STONE, 4) end
      return sw(WOOD, (x == 9 or z == 9) and 4 or 3)
    end
    -- the board: x 1..14, y 7..15, z 10..11 (in front of the post)
    if x < 1 or x > 14 or y < 7 or y > 16 or z < 10 or z > 11 then return nil end
    if y == 16 then                                         -- the capping strip
      if x == 1 or x == 14 then return nil end
      return sw(FRAME, 5)
    end
    local rim = x == 1 or x == 14 or y == 7 or y == 15
    if z == 10 then return sw(WOOD, 3) end                  -- its back
    if rim then return sw(FRAME, 4) end
    -- the face, lettering on rows y 12 and 10
    local row = (y == 12 and 1) or (y == 10 and 2) or nil
    if row and x >= 2 and x <= 12 and TEXT[row]:sub(x - 1, x - 1) == "X" then
      return sw(INK, 4)
    end
    return sw(FACE, 5 + (y % 2))
  end
  return { at = at, W = 16, xmin = 0, xmax = 15, zmin = 0, zmax = 15, ytop = 16 }
end

return Kit
