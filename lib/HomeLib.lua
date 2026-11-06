-- Voxel world mode: the pieces every authored home shares.
--
-- lib/LavenderHomeKit.lua and lib/VermilionHomeKit.lua each carry their own
-- copy of the same handful of helpers -- the swatch index, the patch hash,
-- the dollhouse ramp, the wall's height bands, the north window with its
-- recess, the boards, the open case. The kits after them (Red's house,
-- Blue's house, the lab, every house on the way) take them from here, so a
-- room built in Viridian is measured the way a room in Lavender was:
--
--   a person sixteen voxels, the wall 28 tall and 5 thick standing outside
--   the 0..127 box, the side walls cut down toward the camera, no south wall,
--   no ceiling; a skirting, a dado, a rail, a field and a cornice that stands
--   a voxel proud; glass three voxels back in a framed recess; boards one
--   voxel thick over the tileset's floor; the rug and the doormat unclaimed.
--
-- The two Lavender/Vermilion kits are left as they are: they are finished,
-- and their numbers are what this file was measured from.
--
-- Coordinates as in the kits: x east 0..127, z south 0..127 (toward the
-- camera), y up from the floor.

local Lib = {}

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

Lib.WALL_H, Lib.WALL_D = 28, 5
-- what a sitter stands at: the profile's stool class (VermilionHomeKit's
-- reasoning; every seat built on this tops out at y 7)
Lib.SEAT_H = 8

-- a swatch: row of the sheet, shade 0 (darkest) .. 7 (lightest), clamped
function Lib.sw(row, n) return row * 8 + max(0, min(7, floor(n))) end

-- the homes' patch hash: hash a BLOCK index, not the voxel, and the
-- variation comes out in patches instead of noise
function Lib.hash(x, y, z)
  return (x * 127 + y * 311 + z * 571 + x * y * 7 + y * z * 3) % 97
end

-- the dollhouse cut: the side walls full height to z 12, then a voxel lower
-- every five toward the camera, never under 6
function Lib.sideH(z)
  return max(6, Lib.WALL_H - floor(max(0, z - 12) * 0.2))
end

-- A wall skin from its height bands. `spec`:
--   skirt   = { top, fn(u, y) }      y 0..top
--   dado    = { top, fn(u, y) }      above the skirting, to top
--   rail    = { y, texel }           one course over the dado
--   field   = fn(u, y)               up to the cornice
--   cornice = { from, fn(u, y) }     y >= from
-- `u` runs ALONG the wall, whichever wall it is.
function Lib.wallSkin(spec)
  return function(u, y)
    if y <= spec.skirt[1] then return spec.skirt[2](u, y) end
    if y <= spec.dado[1] then return spec.dado[2](u, y) end
    if y == spec.rail[1] then return spec.rail[2] end
    if y >= spec.cornice[1] then return spec.cornice[2](u, y) end
    return spec.field(u, y)
  end
end

-- Whether height y is one of the courses that stand a voxel proud of the
-- wall face (skirting, rail, cornice) under that skin spec.
function Lib.proudCourse(spec, y)
  return y <= spec.skirt[1] or y == spec.rail[1] or y >= spec.cornice[1]
end

-- A window in the north wall. `w`:
--   x0, x1     the opening's outer columns (frame ring included)
--   y0, y1     the opening's bottom and top rows (frame ring included)
--   frame      texel of the frame ring (stands to z 10, a voxel proud)
--   mullion    fn(lx, y) -> true where the glazing bar crosses
--   bar        texel of the bar
--   glass      fn(lx, y) -> texel (z 6, three voxels behind the face)
--   dress      optional fn(lx, y, z) -> texel | nil, the reveal z 7..9:
--              a blind, a net; nil leaves the reveal carved
--   sill       optional { y, z1, texel }: under the opening, z 10..z1
-- Returns fn(x, y, z) -> handled, texel. handled == false: not this window.
function Lib.northWindow(w)
  return function(x, y, z)
    if x < w.x0 or x > w.x1 then return false end
    local lx = x - w.x0
    if w.sill and y == w.sill[1] and z >= 10 and z <= w.sill[2] then
      return true, w.sill[3]
    end
    if y < w.y0 or y > w.y1 then return false end
    local ring = x == w.x0 or x == w.x1 or y == w.y0 or y == w.y1
    if ring then
      if z <= 10 then return true, w.frame end
      return true, nil
    end
    if z >= 10 then return true, nil end
    if z >= 7 then
      if w.dress then return true, w.dress(lx, y, z) end
      return true, nil
    end
    if z == 6 then
      if w.mullion and w.mullion(lx, y) then return true, w.bar end
      return true, w.glass(lx, y)
    end
    return false
  end
end

-- Boards one voxel thick: planks `width` wide running east-west, butt
-- joints every `run` staggered by `offset` per plank row; `seam` texel on
-- the joints, `plank(i, row)` the texel of plank number i in that row.
function Lib.boards(width, run, offset, seam, plank)
  return function(x, z)
    local row = floor(z / width)
    local r = x + row * offset
    if z % width == 0 or r % run == 0 then return seam end
    return plank(floor(r / run), row)
  end
end

-- rounded rectangle corners: true where (tx, tz) is cut away from a w x d
-- top with corner radius r
function Lib.cornerCut(tx, tz, w, d, r)
  local cx = tx < r and r or (tx > w - 1 - r and w - 1 - r) or tx
  local cz = tz < r and r or (tz > d - 1 - r and d - 1 - r) or tz
  local dx, dz = tx - cx, tz - cz
  return dx * dx + dz * dz > r * r + 0.5
end

-- inside a disc of radius r about a fractional centre
function Lib.disk(x, z, cx, cz, r)
  local dx, dz = x - cx, z - cz
  return dx * dx + dz * dz <= r * r + 0.25
end

-- An open case: 16 wide (ux 0..15), 21 deep (dz 0..20, 20 the front), top
-- at H. Sides, top and back in wood's shade 3, a plinth y 0..1 set back two,
-- a shelf every 6, the front 3 voxels left clear; `fill(ux, s, hy, dz)`
-- stocks shelf s at local height hy (LavenderHomeKit's case, as it is).
function Lib.case(ux, y, dz, H, wood, dark, fill)
  if y > H or dz > 20 then return nil end
  if y <= 1 then return dz <= 18 and Lib.sw(dark, 2) or nil end
  if ux == 0 or ux == 15 or y == H or dz <= 1 then return Lib.sw(wood, 3) end
  if (y - 2) % 6 == 0 then return Lib.sw(wood, 5) end
  if dz >= 18 then return nil end
  return fill and fill(ux, floor((y - 2) / 6), (y - 2) % 6, dz) or nil
end

-- A small pictogram: rows of ASCII, "X" set. (x0, ytop) is the top-left
-- voxel; returns the row's character at (x, y), or nil off the glyph.
function Lib.glyph(rows, x0, ytop, x, y)
  local r = rows[ytop - y + 1]
  if not r then return nil end
  local c = r:sub(x - x0 + 1, x - x0 + 1)
  if c == "" or c == " " or c == "." then return nil end
  return c
end

-- The model every home returns: the room function, the claim mask built
-- from the plan (a tile is claimed unless `open[tile]`), sheet checked.
function Lib.model(kit, sp, t, at, open)
  if not sp or sp.W ~= kit.SHEET_W or sp.H ~= kit.SHEET_H then
    return nil, "sheet is not " .. kit.SHEET_W .. "x" .. kit.SHEET_H
  end
  local rows, cols = #t.tiles, #t.tiles[1]
  local mask = {}
  for r = 1, rows do
    for c = 1, cols do
      mask[(r - 1) * cols + c] = not open[t.tiles[r][c]]
    end
  end
  return { at = at, W = 128, xmin = -Lib.WALL_D, xmax = 127 + Lib.WALL_D,
           zmin = 0, zmax = 127, ytop = Lib.WALL_H + 1,
           standH = 0, claimMask = mask, noFigure = true }
end

return Lib
