-- Voxel world mode: a town house OUTSIDE, built from a spec.
--
-- lib/VermilionHouseKit.lua is where this was written: `house(S)` and its
-- materials, windows and roofs, for Vermilion's six. It is lifted here so
-- every town since builds its houses in the same language, with three
-- things made parameters that were fixed there:
--
--   the plot     S.W x S.D (Vermilion's are all 64 x 64; Pallet's houses are
--                64 x 48 and Oak's lab 96 x 64)
--   the door     S.doorX0..S.doorX1, the alcove's columns (Vermilion's
--                17..30); the lantern stands three voxels east of it
--   the colours  R, the town sheet's rows by name, so each town paints from
--                its own sheet (VermilionHouseKit's rows are the reference)
--
-- The rest is his, number for number: a stone plinth, quoins, the skin
-- asked per height, the roof a skin three voxels thick with barge boards and
-- a ridge, windows let in with a proud sill, a white surround, a cross bar
-- and the glass two voxels back, the door in an alcove four deep under an
-- arched head, a solid interior ("nothing to see into"), the chimney's mouth
-- handed to HearthFX, the door lantern to the lamp pass, the foot of the
-- walls a little darker than their top. Lib.house(S) returns the model.
--
-- Coordinates are the plot's: x east 0..W-1, z south 0..D-1, y up. A person
-- is sixteen voxels. Nothing here is extracted from the ROM.

local Lib = {}

local floor, abs, min, max = math.floor, math.abs, math.min, math.max

-- The rows of every town's houses sheet, by name (tools/town_houses.py is
-- the mirror of this list; a town changes the colours, never the order)
Lib.ROWS = {}
for i, name in ipairs({ "STONE", "MORTAR", "WHITE", "CREAM", "BRICK", "TIMBER", "WOOD",
                        "TERRA", "TERRA_DK", "SLATE", "SLATE_DK", "LEAD", "IRON", "SHADOW",
                        "GLASS", "LIGHT", "GOLD", "PAVE", "PAVEJOINT", "LEAF", "FLOWER",
                        "RED", "BLUE", "GREEN", "WEATHER", "LILAC", "CANVAS", "COPPER" }) do
  Lib.ROWS[name] = i - 1
end
Lib.SHEET_W, Lib.SHEET_H = 8, 28

function Lib.sw(row, n) return row * 8 + n % 8 end
local sw = Lib.sw
function Lib.noise(x, y, z) return (x * 17 + y * 31 + z * 13) % 8 end
local noise = Lib.noise

-- ---------------------------------------------------------- materials --
-- Factories over a town's rows R; each returns fn(u, y, salt) for a wall
-- (u along it, y up) or fn(u, d, salt) for a roof (u along the eave, d up
-- the slope).
function Lib.materials(R)
  local M = {}
  function M.stone(u, y, salt)
    local course = floor(y / 3)
    if y % 3 == 2 or (u + course % 2 * 4) % 8 == 0 then return sw(R.MORTAR, 3) end
    return sw(R.STONE, noise(floor((u + course % 2 * 4) / 8), course, salt))
  end
  function M.brick(u, y, salt)
    local course = floor(y / 3)
    if y % 3 == 0 or (u + course % 2 * 3) % 6 == 0 then return sw(R.MORTAR, 5) end
    return sw(R.BRICK, noise(floor((u + course % 2 * 3) / 6), course, salt))
  end
  function M.stucco(row)
    return function(u, y, salt)
      return sw(row, 2 + (floor(u / 9) + floor(y / 6) * 3 + salt) % 5)
    end
  end
  -- boards lying along the wall, each lapped over the one below
  function M.clapboard(row)
    return function(u, y, salt)
      if y % 3 == 0 then return sw(row, 0) end
      return sw(row, 3 + (floor(y / 3) * 5 + floor(u / 16) + salt) % 4)
    end
  end
  function M.timber(u, y)
    return sw((u + y) % 5 == 0 and R.WOOD or R.TIMBER, 2 + floor(y / 7) % 3)
  end
  function M.halftimber(lo, hi, infill)
    local rail = floor((lo + hi) / 2)
    return function(u, y, salt)
      if y == lo or y == hi or y == rail or u % 9 == 0 then return M.timber(u, y) end
      if (u + y) % 18 == 0 or (u - y) % 18 == 0 then return M.timber(u, y) end
      return sw(infill or R.CREAM, 3 + (floor(u / 9) + floor(y / 6) + salt) % 4)
    end
  end
  -- clay pantiles: a rib every third voxel along the eave, a course up it
  function M.pantile(u, d, salt)
    if d % 4 == 0 then return sw(R.TERRA_DK, 3 + u % 2) end
    if u % 3 == 0 then return sw(R.TERRA_DK, 5) end
    return sw(R.TERRA, 2 + (floor(u / 3) + floor(d / 4) * 3 + (salt or 0)) % 5)
  end
  -- shingles (or slates, in a slate row): courses three up, joints staggered
  function M.shingle(row)
    return function(u, d, salt)
      local course = floor(d / 3)
      if d % 3 == 0 then return sw(row, 0) end
      if (u + course % 2 * 2) % 5 == 0 then return sw(row, 1) end
      return sw(row, 3 + noise(floor((u + course % 2 * 2) / 5), course, salt or 0) % 5)
    end
  end
  -- the plot's paving, one voxel thick, on an eight-voxel grid
  function M.pave(x, z)
    if x % 8 == 0 or z % 8 == 0 then return sw(R.PAVEJOINT, 3) end
    return sw(R.PAVE, 2 + (floor(x / 8) * 3 + floor(z / 8) * 5) % 4)
  end
  return M
end

function Lib.glyph(rows, x0, ytop, x, y)
  local row = rows[ytop - y + 1]
  local cx = x - x0 + 1
  return row ~= nil and cx >= 1 and cx <= #row and row:sub(cx, cx) == "X"
end

-- A window let into a wall: `u` across, `y` up, `depth` IN from the face (0 =
-- the face, negative = proud of it). Answers handled, texel; a texel of nil
-- is a carved voxel. W: c (centre), w2 (half width), y0, y1, arch, shut (a
-- row: louvred shutters either side), box (a row: a window box).
local function windowFn(R)
  return function(u, y, depth, W)
    local du = u - W.c + 0.5
    local w2, y0, y1 = W.w2, W.y0, W.y1
    local reach = w2 + (W.shut and 5.5 or 1.5)
    if abs(du) > reach or y < y0 - 2 or y > y1 + 1 or depth < -1 or depth > 2 then return false end
    local inside = abs(du) <= w2 and y >= y0 and y <= y1
    if inside and W.arch then
      local spring = y1 - w2
      if y > spring and du * du + (y - spring) * (y - spring) > w2 * w2 + 1 then inside = false end
    end
    if y == y0 - 1 and abs(du) <= w2 + 1.5 and depth <= 0 then return true, sw(R.WHITE, 6) end
    if W.box and y == y0 - 2 and abs(du) <= w2 + 0.5 and depth == -1 then return true, sw(R.WOOD, 3) end
    if W.box and y == y0 - 1 and abs(du) <= w2 + 0.5 and depth == -1 then
      return true, sw((floor(du) % 3 == 0) and W.box or R.LEAF, 3 + floor(du) % 3)
    end
    if W.shut and depth == -1 and abs(du) > w2 + 1 and abs(du) <= w2 + 5 and y >= y0 and y <= y1 then
      return true, sw(W.shut, (y % 2 == 0) and 1 or 4)
    end
    if not inside then
      if depth == 0 and abs(du) <= w2 + 1 and y >= y0 and y <= y1 + 1 then return true, sw(R.WHITE, 5) end
      return false
    end
    if depth < 0 then return false end
    if depth < 2 then
      if depth == 1 and (abs(du) < 1 or y == floor((y0 + y1) / 2)) then return true, sw(R.WHITE, 4) end
      return true, nil
    end
    return true, sw(R.GLASS, 2 + (floor(du) + y) % 4)
  end
end

-- ---------------------------------------------------------------- roofs --
-- Each answers top, u, d, barge, ridge, flat for a column: the y of its
-- outer skin, where along the eave and how far up the slope -- or nil.
function Lib.gableNS(x0, x1, z0, z1, eave, pitch)
  local cx = (x0 + x1) / 2
  return function(x, z)
    if x < x0 or x > x1 or z < z0 or z > z1 then return nil end
    local d = (x1 - x0) / 2 - abs(x - cx)
    return eave + floor(d * pitch), z, floor(d), (z == z0 or z == z1), d >= (x1 - x0) / 2 - 1
  end
end
function Lib.gableEW(x0, x1, z0, z1, eave, pitch)
  local cz = (z0 + z1) / 2
  return function(x, z)
    if x < x0 or x > x1 or z < z0 or z > z1 then return nil end
    local d = (z1 - z0) / 2 - abs(z - cz)
    return eave + floor(d * pitch), x, floor(d), (x == x0 or x == x1), d >= (z1 - z0) / 2 - 1
  end
end
function Lib.hip(x0, x1, z0, z1, eave, rise, cap)
  return function(x, z)
    if x < x0 or x > x1 or z < z0 or z > z1 then return nil end
    local dx, dz = min(x - x0, x1 - x), min(z - z0, z1 - z)
    local d = min(dx, dz)
    local top = eave + floor(rise(d))
    local flat = cap and top >= cap
    if flat then top = cap end
    return top, (dz < dx) and x or z, d, false, dx == dz and not flat, flat
  end
end
function Lib.pitchOf(k) return function(d) return d * k end end

-- ------------------------------------------------------------ the house --
-- S: W, D (the plot), x0 x1 z0 z1 (walls), wall (their top), skin(y) ->
-- material fn, plinth, quoin (a row), roof (above), tile (material fn),
-- ridgeRow, windows { face, ... }, door (a row, or nil), doorX0/doorX1,
-- porch, chimney { x, z, top }, extra(x, y, z) -> handled, texel, lights,
-- ytop, salt, R (the town's rows), pave (false for none).
function Lib.house(S)
  local R = S.R
  local M = Lib.materials(R)
  local window = windowFn(R)
  local W, D = S.W or 64, S.D or 64
  local X0, X1, Z0, Z1 = S.x0, S.x1, S.z0, S.z1
  local roof, ch = S.roof, S.chimney
  local DX0, DX1 = S.doorX0 or 17, S.doorX1 or 30
  local DOORC = (DX0 + DX1) / 2
  local LX = DX1 + 3                                    -- the lantern's column

  local function at(x, y, z)
    if x < 0 or x > W - 1 or z < 0 or z > D - 1 or y < 0 or y > S.ytop then return nil end
    if S.extra then
      local handled, v = S.extra(x, y, z)
      if handled then return v end
    end
    local top, u, d, barge, ridge, flat = roof(x, z)

    -- the chimney: brick, a stone cap, an open flue
    if ch and x >= ch.x and x <= ch.x + 5 and z >= ch.z and z <= ch.z + 5 and top and y > top - 2 then
      if y <= ch.top then
        if y >= ch.top - 1 then
          if x >= ch.x + 2 and x <= ch.x + 3 and z >= ch.z + 2 and z <= ch.z + 3 then return nil end
          return sw(R.STONE, 5)
        end
        return M.brick(x + z, y, 3)
      end
      return nil
    end

    -- the roof: a skin three voxels thick, barge boards, a ridge
    if top and y <= top and y >= top - 2 then
      if flat then return sw(R.LEAD, 2 + (x + z) % 3) end
      if barge then return sw(R.WHITE, 5) end
      if ridge then return sw(S.ridgeRow or R.TERRA_DK, 6) end
      return S.tile(u, d, S.salt)
    end

    local inside = x >= X0 and x <= X1 and z >= Z0 and z <= Z1
    if inside and top and y < top - 2 then
      -- the door: an alcove four deep, the leaf behind it
      if S.door and x >= DX0 and x <= DX1 and z >= Z1 - 4 and y <= 21 then
        local du = abs(x - DOORC)
        local head = 21 - floor((du / ((DX1 - DX0) / 2)) ^ 2 * 4)
        if y <= head then
          if y == 0 then return sw(R.STONE, 5) end
          if x == DX0 or x == DX1 or y >= head - 1 then return sw(R.WHITE, 5) end
          if z > Z1 - 4 then return nil end
          if x == DX1 - 3 and y == 10 then return sw(R.GOLD, 5) end
          if y == 5 or y == 12 or x == DX0 + 2 or x == DX1 - 2 or du < 1 then return sw(S.door, 1) end
          return sw(S.door, 4 + y % 2)
        end
      end
      local face, fu, depth = nil, nil, nil
      if z >= Z1 - 2 then face, fu, depth = "s", x, Z1 - z
      elseif z <= Z0 + 2 then face, fu, depth = "n", x, z - Z0
      elseif x >= X1 - 2 then face, fu, depth = "e", z, X1 - x
      elseif x <= X0 + 2 then face, fu, depth = "w", z, x - X0 end
      if face then
        for _, Wn in ipairs(S.windows) do
          if Wn.face == face then
            local handled, v = window(fu, y, depth, Wn)
            if handled then return v end
          end
        end
      end
      local edge = x == X0 or x == X1 or z == Z0 or z == Z1
      if not edge then return sw(R.SHADOW, 2) end       -- solid within
      local wu = (z == Z0 or z == Z1) and x or z
      if y <= S.plinth then return M.stone(wu, y, S.salt) end
      if (x <= X0 + 1 or x >= X1 - 1) and (z <= Z0 + 1 or z >= Z1 - 1) and S.quoin then
        return sw(S.quoin, 4 + floor(y / 4) % 2)
      end
      return S.skin(y)(wu, y, S.salt)
    end

    -- proud of the walls: shutters, sills, window boxes
    if y > 0 and top then
      local face, fu, depth = nil, nil, nil
      if z == Z1 + 1 and x >= X0 and x <= X1 then face, fu, depth = "s", x, -1
      elseif z == Z0 - 1 and x >= X0 and x <= X1 then face, fu, depth = "n", x, -1
      elseif x == X1 + 1 and z >= Z0 and z <= Z1 then face, fu, depth = "e", z, -1
      elseif x == X0 - 1 and z >= Z0 and z <= Z1 then face, fu, depth = "w", z, -1 end
      if face then
        for _, Wn in ipairs(S.windows) do
          if Wn.face == face then
            local handled, v = window(fu, y, depth, Wn)
            if handled and v then return v end
          end
        end
      end
    end

    -- a porch over the door: a little tiled roof on two brackets
    if S.porch and x >= DX0 - 4 and x <= DX1 + 4 and z > Z1 and z <= Z1 + 6 then
      local py = 25 - floor((z - Z1) * 0.7)
      if y == py or y == py - 1 then return S.tile(x, z - Z1, S.salt) end
      if (x == DX0 - 3 or x == DX1 + 3) and z <= Z1 + 4 and y >= 18 and y < py - 1
         and y >= py - 1 - (Z1 + 5 - z) then
        return M.timber(x, y)
      end
    end
    -- a lantern by the door
    if S.door and x >= LX and x <= LX + 2 and z >= Z1 + 1 and z <= Z1 + 3 and y >= 13 and y <= 19 then
      if y == 19 or y == 13 then return sw(R.IRON, 3) end
      if x == LX + 1 and z == Z1 + 2 then return sw(R.LIGHT, 5) end
      if (x + z) % 2 == 0 then return sw(R.IRON, 3) end
      return sw(R.LIGHT, 3)
    end

    if y == 0 and S.pave ~= false then return M.pave(x, z) end
    return nil
  end

  local lights = S.lights or {}
  if S.door then lights[#lights + 1] = { x = LX + 1, y = 16, z = Z1 + 2 } end
  return { at = at, W = W, xmin = 0, xmax = W - 1, zmin = 0, zmax = D - 1, ytop = S.ytop,
           chimney = ch and { x = ch.x + 3, y = ch.top + 1, z = ch.z + 3 } or nil,
           lights = #lights > 0 and lights or nil,
           tint = function(y) return 0.90 + min(y / 32, 1) * 0.10 end }
end

Lib.materialsFor = Lib.materials
Lib.windowFor = windowFn

return Lib
