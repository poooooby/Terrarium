-- Voxel world mode: the GATEHOUSES on Kanto's routes, outside.
--
-- Route 22's is the Pokemon League's front gate (data/voxel_heights.lua
-- `route_22_gate`, 192 x 96: a deep flat roof, three courses of windows
-- across a long front, the door at the middle). Built from lib/HouseLib.lua
-- in the routes' language -- a stone plinth, white trim -- and told apart
-- as a gate is: a long low hall of coursed stone, a flat roof behind a
-- crenellated parapet, a pair of towers framing the gateway, two banners.
--
--   LEAGUE   (ROUTE_22, the placement at 4:0) the League's front gate:
--            pale ashlar, three rows of tall windows, the gateway an arch
--            between two square towers a voxel taller than the hall, the
--            League's colours -- a deep red and gold -- on the banners and
--            the door. No mark is drawn: two plain banners and a star.
--
-- Chosen ONLY for these placements (lib/HouseKits.lua). The plot, the door
-- (the drawing's door columns) and the warp lane are the template's.
--
-- Coordinates are the plot's: x east, z south, y up. A person is sixteen
-- voxels. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HouseLib")

local Kit = { SHEET = "assets/buildings/viridian_houses.png",
              SHEET_W = Lib.SHEET_W, SHEET_H = Lib.SHEET_H }
Kit.MAPS = { ROUTE_22 = true, ROUTE_2 = true, ROUTE_5 = true, ROUTE_6 = true, ROUTE_11 = true,
             ROUTE_10 = true, ROUTE_12 = true, ROUTE_15 = true, ROUTE_16 = true, ROUTE_18 = true }
Kit.TEMPLATES = { route_22_gate = true, route_2_gate = true, flat_commercial = true,
                  gabled_cottage = true, route_5_gate = true, daycare = true,
                  celadon_mansion = true, flat_block_8x4 = true, power_plant = true,
                  flat_block_6x4 = true, flat_block_6x6 = true }

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local sw = Lib.sw
local R = Lib.ROWS
Kit.GLASS_UV = { 0, R.GLASS / Kit.SHEET_H, 1, (R.LIGHT + 1) / Kit.SHEET_H }
local M = Lib.materials(R)

local STAR = { "..X..", ".XXX.", "XXXXX", ".X.X." }

local function league()
  local W, D = 192, 96
  local X0, X1, Z0, Z1 = 4, 187, 10, 86
  local WALL = 40
  local DX0, DX1 = 97, 110                          -- the alcove in the drawing's door columns
  -- a flat roof, cut off at the wall's top + 1 (a lead flat behind the parapet)
  local roof = Lib.hip(X0 - 1, X1 + 1, Z0 - 1, Z1 + 1, WALL + 1, Lib.pitchOf(0), WALL + 1)
  local windows = {}
  for row, y0 in ipairs({ 8, 19, 30 }) do
    for c = 14, 180, 14 do
      if not (c >= 88 and c <= 118) or row == 3 then
        windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = y0, y1 = y0 + 7,
                                  arch = row == 1 }
      end
    end
  end
  for _, c in ipairs({ 24, 48, 72 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 3, y0 = 19, y1 = 26 }
    windows[#windows + 1] = { face = "w", c = c, w2 = 3, y0 = 19, y1 = 26 }
  end
  -- the hall's skin: ashlar, a white string course between each storey
  local function skin(y)
    if y == 17 or y == 28 then return function() return sw(R.WHITE, 5) end end
    return M.stone
  end
  return Lib.house({
    R = R, W = W, D = D, x0 = X0, x1 = X1, z0 = Z0, z1 = Z1, wall = WALL, plinth = 5,
    salt = 7, ytop = 58, doorX0 = DX0, doorX1 = DX1,
    skin = skin, quoin = R.WHITE,
    roof = roof, tile = M.shingle(R.SLATE), ridgeRow = R.SLATE_DK,
    door = R.RED,
    windows = windows,
    lights = { { x = DX0 - 3, y = 16, z = Z1 + 2 } },
    extra = function(x, y, z)
      -- the parapet round the flat: merlons three on, three off
      local onRim = (x >= X0 and x <= X1 and (z == Z0 or z == Z1)) or
                    (z >= Z0 and z <= Z1 and (x == X0 or x == X1))
      if onRim and y >= WALL + 2 and y <= WALL + 5 then
        local u = (z == Z0 or z == Z1) and x or z
        if y <= WALL + 3 or u % 6 < 3 then return true, M.stone(u, y, 7) end
        return true, nil
      end
      -- the two towers framing the gateway: 16 wide, standing 10 proud of
      -- the hall's front and 12 over its roof, their own parapets
      for _, t0 in ipairs({ DX0 - 18, DX1 + 3 }) do
        if x >= t0 and x <= t0 + 15 and z >= Z1 - 8 and z <= Z1 + 4 then
          local edge = x == t0 or x == t0 + 15 or z == Z1 - 8 or z == Z1 + 4
          if y <= WALL + 12 then
            if not edge then return true, (y == WALL + 12) and sw(R.LEAD, 3) or sw(R.SHADOW, 2) end
            if y <= 5 then return true, M.stone(x + z, y, 8) end
            -- a slit window in each tower's front, high up
            if z == Z1 + 4 and x >= t0 + 7 and x <= t0 + 8 and y >= 30 and y <= 38 then
              return true, sw(R.SHADOW, 1)
            end
            if (x <= t0 + 1 or x >= t0 + 14) and (z <= Z1 - 7 or z >= Z1 + 3) then
              return true, sw(R.WHITE, 4 + floor(y / 4) % 2)            -- quoins
            end
            return true, M.stone(x + z, y, 8)
          end
          if y <= WALL + 15 and edge then
            local u = (z == Z1 - 8 or z == Z1 + 4) and x or z
            if y <= WALL + 13 or u % 4 < 2 then return true, M.stone(u, y, 8) end
          end
          return true, nil
        end
      end
      -- the banners on the towers' fronts: red cloth, a gold border and star
      for _, b0 in ipairs({ DX0 - 14, DX1 + 7 }) do
        if z == Z1 + 5 and x >= b0 and x <= b0 + 7 and y >= 20 and y <= 33 then
          local lx, ly = x - b0, 33 - y
          if lx == 0 or lx == 7 or ly == 0 then return true, sw(R.GOLD, 5) end
          if ly >= 10 and lx >= 1 and lx <= 6 and (ly - 10 + lx) % 2 == 0 then return true, nil end   -- the hem
          local srow = STAR[ly - 2]
          if srow and lx >= 1 and lx <= 5 and srow:sub(lx, lx) == "X" then return true, sw(R.GOLD, 6) end
          return true, sw(R.RED, 3 + (ly % 2))
        end
      end
      return false
    end,
  })
end

-- The route gatehouses: a hall of coursed stone under a slate hip, the
-- door in an arched alcove, a lantern by it, a row of tall windows, and
-- the gate's signboard over the door -- the forest gates' a leaf, the
-- route gates' two arrows. `W` 64 or 96 (the drawing's plot), `D` 64,
-- the door at the drawing's columns.
local LEAF = { "..XX..", ".XXXX.", "XXXXXX", ".XXXX.", "..XX..", "..X..." }
local ARROWS = { ".X......", "XXXXXXX.", ".X......", "........", "......X.", ".XXXXXXX", "......X." }

-- `D` 64 (one storey) or 96 (the Route 6 and 12 gates: two storeys, the
-- drawing twice as deep)
local function gatehouse(W, doorX0, sign, salt, D)
  D = D or 64
  local tall = D > 64
  local Z1 = D - 10
  local X0, X1 = 4, W - 5
  local WALL = tall and 46 or 32
  local roof = Lib.hip(1, W - 2, 5, D - 6, WALL + 1, Lib.pitchOf(0.8))
  local windows = {}
  local noDoor = doorX0 == false
  doorX0 = doorX0 or -100
  for c = 12, W - 10, 12 do
    if c < doorX0 - 6 or c > doorX0 + 19 then
      windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = 8, y1 = 20, arch = true }
    end
    if tall then
      windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = 30, y1 = 40, arch = true }
    end
  end
  windows[#windows + 1] = { face = "e", c = 30, w2 = 4, y0 = 8, y1 = 20, arch = true }
  windows[#windows + 1] = { face = "w", c = 30, w2 = 4, y0 = 8, y1 = 20, arch = true }
  windows[#windows + 1] = { face = "n", c = W / 2, w2 = 4, y0 = 8, y1 = 20, arch = true }
  local DC = doorX0 + 7.5
  return Lib.house({
    R = R, W = W, D = D, x0 = X0, x1 = X1, z0 = 8, z1 = Z1, wall = WALL, plinth = 5,
    salt = salt, ytop = WALL + 30, doorX0 = doorX0, doorX1 = doorX0 + 13,
    skin = function(y)
      if y == 22 or (tall and y == 26) then return function() return sw(R.WHITE, 5) end end
      return M.stone
    end,
    quoin = R.WHITE,
    roof = roof, tile = M.shingle(R.SLATE), ridgeRow = R.SLATE_DK,
    door = (not noDoor) and R.GREEN or nil, porch = not noDoor,
    windows = windows,
    extra = function(x, y, z)
      if noDoor then return false end
      -- the signboard over the porch: a white board in a timber frame,
      -- the gate's sign on it in green
      if z == Z1 + 1 and y >= 24 and y <= 31 and x >= DC - 5 and x <= DC + 5 then
        local lx, ly = floor(x - (DC - 5)), 31 - y
        if lx == 0 or lx == 10 or ly == 0 or ly == 7 then return true, sw(R.TIMBER, 4) end
        local row = sign[ly]
        if row and lx >= 2 and lx - 1 <= #row and row:sub(lx - 1, lx - 1) == "X" then
          return true, sw(R.GREEN, 4)
        end
        return true, sw(R.WHITE, 6)
      end
      return false
    end,
  })
end

-- Route 2's trade house: a small cottage of the meadow's (the Viridian
-- houses' language), cream render under a slate gable, a door on the left,
-- a window with a flower box on the right, a bench by the door
local function tradeCottage()
  local Z1 = 27
  return Lib.house({
    R = R, W = 64, D = 32, x0 = 5, x1 = 58, z0 = 4, z1 = Z1, wall = 24, plinth = 4,
    salt = 9, ytop = 50,
    skin = function() return M.stucco(R.CREAM) end, quoin = R.STONE,
    roof = Lib.gableEW(2, 61, 1, 30, 25, 0.95), tile = M.shingle(R.SLATE), ridgeRow = R.SLATE_DK,
    door = R.BLUE,
    chimney = { x = 46, z = 8, top = 46 },
    windows = { { face = "s", c = 41, w2 = 5, y0 = 8, y1 = 18, shut = R.BLUE, box = R.FLOWER },
                { face = "e", c = 16, w2 = 4, y0 = 8, y1 = 18 },
                { face = "w", c = 16, w2 = 4, y0 = 8, y1 = 18 },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
    extra = function(x, y, z)
      -- a bench against the wall, right of the window
      if z >= Z1 + 1 and z <= Z1 + 3 and x >= 49 and x <= 57 then
        if y <= 3 and (x == 49 or x == 57) then return true, M.timber(x, y) end
        if y == 4 then return true, sw(R.WOOD, 5) end
        if z == Z1 + 1 and y >= 5 and y <= 8 then return true, sw(R.WOOD, 4) end
      end
      return false
    end,
  })
end

-- the Underground Path's sign: steps going down
local STEPS = { "XX......", "XXXX....", "..XXXX..", "....XXXX", "......XX", "........", "XXXXXXXX" }

-- Route 5's Day Care: a farmhouse of the meadow -- cream render over a
-- stone plinth, a hipped slate roof, green shutters with flower boxes, a
-- signboard with an egg over the door, a little paddock rail along the
-- front where the minded Pokemon are let out
local EGG = { "..XX..", ".XXXX.", "XX.XXX", "XXXX.X", "XXXXXX", ".XXXX." }
local function daycare()
  local Z1 = 54
  local DX0 = 33
  local DC = DX0 + 7.5
  return Lib.house({
    R = R, W = 64, D = 64, x0 = 4, x1 = 59, z0 = 8, z1 = Z1, wall = 32, plinth = 5,
    salt = 12, ytop = 64, doorX0 = DX0, doorX1 = DX0 + 13,
    skin = function() return M.stucco(R.CREAM) end, quoin = R.STONE,
    roof = Lib.hip(1, 62, 5, 58, 33, Lib.pitchOf(0.85)), tile = M.shingle(R.SLATE), ridgeRow = R.SLATE_DK,
    door = R.GREEN, porch = true,
    chimney = { x = 12, z = 18, top = 56 },
    windows = { { face = "s", c = 16, w2 = 5, y0 = 8, y1 = 18, shut = R.GREEN, box = R.FLOWER },
                { face = "s", c = 16, w2 = 4, y0 = 23, y1 = 30, shut = R.GREEN },
                { face = "s", c = 52, w2 = 4, y0 = 23, y1 = 30, shut = R.GREEN },
                { face = "e", c = 30, w2 = 4, y0 = 8, y1 = 18 },
                { face = "w", c = 30, w2 = 4, y0 = 8, y1 = 18 },
                { face = "n", c = 32, w2 = 5, y0 = 8, y1 = 18 } },
    extra = function(x, y, z)
      if z == Z1 + 1 and y >= 24 and y <= 31 and x >= DC - 5 and x <= DC + 5 then
        local lx, ly = floor(x - (DC - 5)), 31 - y
        if lx == 0 or lx == 10 or ly == 0 or ly == 7 then return true, sw(R.TIMBER, 4) end
        local row = EGG[ly]
        if row and lx >= 2 and lx - 1 <= #row and row:sub(lx - 1, lx - 1) == "X" then
          return true, sw(R.GOLD, 5)
        end
        return true, sw(R.WHITE, 6)
      end
      -- the paddock rail west of the door: posts every six, two rails
      if z == Z1 + 7 and x >= 3 and x <= 27 then
        if x % 6 == 3 and y >= 1 and y <= 9 then return true, M.timber(x, y) end
        if y == 4 or y == 8 then return true, sw(R.WOOD, 4 + (y == 8 and 1 or 0)) end
      end
      return false
    end,
  })
end

-- Route 10's Power Plant: a brick generating hall, long and tall, a row of
-- tall windows, a flat lead roof with two brick chimneys, a transformer
-- yard on the roof's east end (insulators, a lattice), a sign with a
-- lightning flash over the door. Long abandoned: soot at the chimney tops.
local FLASH = { "...XX", "..XX.", ".XXXX", "..XX.", ".XX..", "XX..." }
local function powerPlant()
  local W, D = 128, 96
  local Z1 = D - 10
  local DX0 = 65
  local DC = DX0 + 7.5
  local roof = Lib.hip(1, W - 2, 5, D - 6, 47, Lib.pitchOf(0.3), 50)
  local windows = {}
  for c = 10, W - 10, 12 do
    if c < DX0 - 6 or c > DX0 + 19 then
      windows[#windows + 1] = { face = "s", c = c, w2 = 3, y0 = 10, y1 = 38 }
    end
  end
  for _, c in ipairs({ 20, 44, 68 }) do
    windows[#windows + 1] = { face = "e", c = c, w2 = 3, y0 = 10, y1 = 38 }
    windows[#windows + 1] = { face = "w", c = c, w2 = 3, y0 = 10, y1 = 38 }
  end
  local stacks = { { 26, 34 }, { 46, 34 } }
  return Lib.house({
    R = R, W = W, D = D, x0 = 4, x1 = W - 5, z0 = 8, z1 = Z1, wall = 46, plinth = 5,
    salt = 18, ytop = 96, doorX0 = DX0, doorX1 = DX0 + 13,
    skin = function(y)
      if y == 42 or y == 43 then return function() return sw(R.STONE, 5) end end   -- a string course
      return M.brick
    end,
    quoin = R.STONE,
    roof = roof, tile = M.shingle(R.SLATE), ridgeRow = R.SLATE_DK,
    door = R.IRON, porch = false,
    windows = windows,
    extra = function(x, y, z)
      -- the chimneys
      for _, st in ipairs(stacks) do
        local dx, dz = x - st[1], z - st[2]
        if abs(dx) <= 4 and abs(dz) <= 4 and y > 46 and y <= 90 then
          if abs(dx) <= 2 and abs(dz) <= 2 and y >= 88 then return true, nil end
          if y >= 84 then return true, sw(R.SHADOW, 2) end                       -- soot
          if y == 70 then return true, sw(R.STONE, 5) end
          return true, M.brick(x + z, y, 4)
        end
      end
      -- the transformer yard on the roof's east end
      if x >= 84 and x <= 118 and z >= 20 and z <= 70 and y > 50 and y <= 66 then
        local px, pz = (x - 84) % 12, (z - 20) % 12
        if (px == 0 or px == 11) and (pz == 0 or pz == 11) then return true, sw(R.IRON, 3) end   -- posts
        if (y == 60 or y == 66) and (px == 0 or pz == 0) then return true, sw(R.IRON, 4) end      -- the lattice
        if px >= 4 and px <= 7 and pz >= 4 and pz <= 7 and y <= 58 then
          if y >= 56 then return true, sw(R.WHITE, 5 + y % 2) end             -- insulators
          return true, sw(R.LEAD, 3 + (px + pz) % 2)                            -- a transformer
        end
        return false
      end
      -- the sign over the door: a white board, a yellow flash
      if z == Z1 + 1 and y >= 26 and y <= 33 and x >= DC - 5 and x <= DC + 5 then
        local lx, ly = floor(x - (DC - 5)), 33 - y
        if lx == 0 or lx == 10 or ly == 0 or ly == 7 then return true, sw(R.IRON, 4) end
        local row = FLASH[ly]
        if row and lx >= 3 and lx - 2 <= #row and row:sub(lx - 2, lx - 2) == "X" then
          return true, sw(R.GOLD, 6)
        end
        return true, sw(R.WHITE, 6)
      end
      return false
    end,
  })
end

-- Which building stands on (map, top-left tile)
Kit.PLACES = {
  ROUTE_22 = { ["4:0"] = league },
  -- (the door alcove's first column in the plot: the drawing's door tiles
  -- 11/12 stand at plot x 16..31, the alcove inside them 17..30)
  ROUTE_2 = { ["28:72"] = function() return gatehouse(96, 17, ARROWS, 10) end,
              ["4:80"] = function() return gatehouse(64, 17, LEAF, 11) end,
              ["28:36"] = tradeCottage },
  -- Route 5: the gate to Saffron (its door tiles at plot x 64..79), the
  -- Underground Path's entrance, the Day Care
  ROUTE_5 = { ["12:60"] = function() return gatehouse(128, 65, ARROWS, 13) end,
              ["32:48"] = function() return gatehouse(64, 17, STEPS, 14) end,
              ["16:36"] = daycare },
  -- Route 6: the gate to Saffron (two storeys) and the Underground Path's
  -- south entrance
  -- Route 11: the gate to Route 12, entered from its ends (no door drawn
  -- on its front)
  ROUTE_10 = { ["4:68"] = powerPlant },
  ROUTE_11 = { ["100:12"] = function() return gatehouse(128, false, nil, 17) end },
  ROUTE_6 = { ["16:4"] = function() return gatehouse(96, 33, ARROWS, 15, 96) end,
              ["32:20"] = function() return gatehouse(64, 17, STEPS, 16) end },
}

-- the door the drawing draws (its 11/12 pair), as the alcove's first column
local function doorOf(t)
  local rows, cols = #t.tiles, #t.tiles[1]
  for r = rows, math.max(1, rows - 3), -1 do
    for c = 1, cols - 1 do
      if t.tiles[r][c] == 11 and t.tiles[r][c + 1] == 12 then return (c - 1) * 8 + 1 end
    end
  end
  return false
end
-- the gates of the south: any of these drawings at these placements
local GENERIC = { ROUTE_12 = { ["16:32"] = 19 }, ROUTE_15 = { ["16:12"] = 20 },
                  ROUTE_16 = { ["36:4"] = 21, ["36:12"] = 22 }, ROUTE_18 = { ["68:8"] = 23 } }

function Kit.model(sp, t, tx, ty, mapId)
  if Kit.ENABLED == false then return nil, "switched off" end
  if not sp or sp.W ~= Kit.SHEET_W or sp.H ~= Kit.SHEET_H then
    return nil, "sheet is not " .. Kit.SHEET_W .. "x" .. Kit.SHEET_H
  end
  local g = GENERIC[mapId or ""] and GENERIC[mapId][tostring(tx) .. ":" .. tostring(ty)]
  if g then
    local W, D = #t.tiles[1] * 8, #t.tiles * 8
    local door = doorOf(t)
    return gatehouse(W, door, door and ARROWS or nil, g, D)
  end
  local places = Kit.PLACES[mapId or ""]
  local make = places and places[tostring(tx) .. ":" .. tostring(ty)]
  if not make then return nil, "no gatehouse stands at " .. tostring(mapId) .. " " .. tostring(tx) .. ":" .. tostring(ty) end
  return make()
end

return Kit
