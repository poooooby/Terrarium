-- Voxel world mode: the halls on the gym tileset that are walls and a floor.
--
-- The drawing in all of them is the same few tiles: a striped floor (17),
-- the black wall blocks with their white edge (36/39 over 37/53, 38 the
-- top run, 15 the fill, 66/16/62 the lit south face of a run), the wall
-- band at the north (5 over 16), the statues (2/56 .. 50/51) and the mat.
-- One cell (2x2 tiles) is one block of wall. What stands, per hall:
--
--   VIRIDIAN_GYM    Giovanni's maze: dark granite ashlar, a pale cap, the
--                   partitions shoulder high so the maze reads from above;
--                   dark oak boards; the spinner arrows and stop pads (60/61,
--                   76/77, 63) stay drawn
--   FUCHSIA_GYM     Koga's hall: its walls (31) are invisible in the game,
--                   drawn as floor -- so here too only the boards are laid
--   FIGHTING_DOJO   timber posts and rails, plastered panels; the two
--                   hanging scrolls on the back wall (52/67 over 82/83);
--                   pale boards
--   LANCES_ROOM     granite walls with a gold band; dark boards; the gate
--   CHAMPIONS_ROOM  into the Champion's room (32/33 over 48/49) a pair of
--                   leaves in a frame; the stairs (72..75) stay drawn
--   HALL_OF_FAME    the floor of big pale tiles (9/10 over 25/26) and the
--                   recording machine (91..95, 54/55/85, 88..90): a console
--                   desk, a monitor and the recorder on it
--
-- The black fill far from any floor (Lance's map is mostly that) is left
-- empty. Statues stay the profile's (`gym_statue` / `dojo_statue`), the mat
-- drawn. No south wall, no ceiling; no side cut (the halls are long).
-- x east, z south, one tile 8 voxels. Nothing here is extracted from the ROM.
local V = ...
local Lib = V.require("HomeLib")

local Kit = { SHEET = "assets/buildings/gym_halls.png", SHEET_W = 8, SHEET_H = 14 }
Kit.MAPS = { VIRIDIAN_GYM = "maze", FUCHSIA_GYM = "ninja", FIGHTING_DOJO = "dojo",
             LANCES_ROOM = "stone", CHAMPIONS_ROOM = "stone", HALL_OF_FAME = "hall" }

local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local sw = Lib.sw
local OAK, OAK_DK, GRANITE, GRANITE_LT, PLASTER, TIMBER, PAPER, INK, GOLD, TILE, TILE_DK,
      SCREEN, RED, STEEL = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
local function hash(a, b, c)
  local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
  return floor((v - floor(v)) * 97)
end

local DARK = { [15] = true, [36] = true, [37] = true, [38] = true, [39] = true,
               [53] = true, [62] = true, [66] = true }
local BACK = { [5] = true, [16] = true, [52] = true, [67] = true, [82] = true, [83] = true }
local DOOR = { [32] = true, [33] = true, [48] = true, [49] = true }
local MACHINE = { [91] = true, [92] = true, [93] = true, [94] = true, [54] = true,
                  [55] = true, [85] = true, [95] = true, [88] = true, [89] = true, [90] = true }
-- left to the profile (the statues: the boards run on under them) or
-- drawn (the mat, the spinner arrows, the stop pads: the floor gives way)
local OPEN = { [2] = true, [56] = true, [18] = true, [19] = true, [34] = true, [35] = true,
               [50] = true, [51] = true, [6] = true, [22] = true, [60] = true, [61] = true,
               [63] = true, [76] = true, [77] = true }
local DRAWN = { [6] = true, [22] = true, [60] = true, [61] = true, [63] = true, [76] = true,
                [77] = true }
-- the stairs up out of Lance's corridor (72/73 over 74/75), built: an
-- unclaimed tile would be laid as the ground under the whole empty fill
local STAIRS = { [72] = true, [73] = true, [74] = true, [75] = true }
Kit.OPEN = OPEN

local WALL_H = { maze = 16, dojo = 24, stone = 24, ninja = 24, hall = 24 }
local BACK_H = 28

local function build(t, style)
  local rows, cols = #t.tiles, #t.tiles[1]
  local function tile(c, r)
    if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
    return t.tiles[r + 1][c + 1]
  end
  local W, D = cols * 8, rows * 8
  local cw, ch = floor(cols / 2), floor(rows / 2)
  -- each cell: "wall", "back", "void" or "floor"
  local kind = {}
  local function cellTiles(cx, cy)
    return tile(cx * 2, cy * 2), tile(cx * 2 + 1, cy * 2), tile(cx * 2, cy * 2 + 1), tile(cx * 2 + 1, cy * 2 + 1)
  end
  for cy = 0, ch - 1 do
    for cx = 0, cw - 1 do
      local a, b, c, d = cellTiles(cx, cy)
      local k = "floor"
      if DARK[a] or DARK[b] or DARK[c] or DARK[d] then k = "wall"
      elseif BACK[a] and BACK[c] then k = "back" end
      kind[cy * cw + cx] = k
    end
  end
  -- the fill with no floor beside it is nothing at all
  local function kindAt(cx, cy)
    if cx < 0 or cy < 0 or cx >= cw or cy >= ch then return nil end
    return kind[cy * cw + cx]
  end
  local solid = {}
  for cy = 0, ch - 1 do
    for cx = 0, cw - 1 do
      if kind[cy * cw + cx] == "wall" then
        local near = false
        for dy = -1, 1 do
          for dx = -1, 1 do
            local k = kindAt(cx + dx, cy + dy)
            if k == "floor" or k == "back" then near = true end
          end
        end
        solid[cy * cw + cx] = near
      end
    end
  end
  local wallH = WALL_H[style]
  -- where each row's run of door tiles begins
  local doorX0 = {}
  for r = 0, rows - 1 do
    for c = cols - 1, 0, -1 do
      if DOOR[tile(c, r)] then doorX0[r] = c * 8 end
    end
  end

  -- the wall skins. `u` along the face, `y` up, `H` the wall's height
  local function stoneSkin(u, y, H, gold)
    if y >= H - 1 then return sw(GRANITE_LT, 4 + (u % 16 == 0 and -1 or 0)) end
    if gold and y == H - 4 then return sw(GOLD, 4 + hash(floor(u / 4), y, 1) % 3) end
    if y <= 1 then return sw(GRANITE, 1) end
    local course = floor((y - 2) / 6)
    if (y - 2) % 6 == 5 then return sw(GRANITE, 0) end                 -- bed joints
    if (u + course * 7) % 14 == 0 then return sw(GRANITE, 0) end       -- head joints
    return sw(GRANITE, 2 + hash(floor((u + course * 7) / 14), course, 3) % 4)
  end
  local function timberSkin(u, y, H)
    if y >= H - 2 or y <= 1 or y == 12 then return sw(TIMBER, 3 + (y == H - 1 and 2 or 0)) end
    if u % 16 <= 1 then return sw(TIMBER, 3) end                       -- posts
    return sw(PLASTER, 4 + hash(floor(u / 16), floor(y / 4), 5) % 2)
  end
  local function skin(u, y, H)
    if style == "dojo" then return timberSkin(u, y, H) end
    if style == "hall" or style == "ninja" then
      if y <= 1 then return sw(OAK_DK, 3) end
      if y >= H - 1 then return sw(PLASTER, 6) end
      if y == 9 then return sw(OAK_DK, 4) end
      if y < 9 then return sw(OAK, 3 + (u % 12 == 0 and -2 or 0)) end
      return sw(PLASTER, 4 + hash(floor(u / 8), floor(y / 6), 9) % 2)
    end
    return stoneSkin(u, y, H, style == "stone")
  end

  -- a block of wall, H tall, standing on its whole cell; its faces skinned
  -- and its top the cap
  local function block(x, y, z, H)
    if y >= H then return nil end
    local lx, lz = x % 16, z % 16
    if y == H - 1 then
      if style == "dojo" then return sw(TIMBER, 4 + hash(floor(x / 16), 0, floor(z / 16)) % 2) end
      if style == "hall" or style == "ninja" then return sw(PLASTER, 6) end
      return sw(GRANITE_LT, 3 + hash(floor(x / 4), 7, floor(z / 4)) % 3)
    end
    -- the face toward whichever side is open; the inside is the same skin
    local u = (lz == 0 or lz == 15) and x or z
    return skin(u, y, H)
  end

  -- the floor
  local function boards(x, z)
    local row = floor(z / 4)
    local run = x + row * 17
    local mat = (style == "dojo" or style == "ninja") and OAK or OAK_DK
    if z % 4 == 0 then return sw(mat, 1) end
    if run % 32 == 0 then return sw(mat, 2) end
    return sw(mat, 3 + hash(floor(run / 32), row, 4) % 3)
  end
  local function tiles(x, z)
    local lx, lz = x % 16, z % 16
    if lx == 0 or lz == 0 then return sw(TILE_DK, 3) end
    if lx == 1 or lz == 1 then return sw(TILE, 7) end
    if lx == 15 or lz == 15 then return sw(TILE, 2) end
    return sw(TILE, 4 + hash(floor(x / 16), 0, floor(z / 16)) % 2)
  end

  -- the Hall's machine on the tiles (cols 8..11, rows 2..4)
  local MX0, MX1, MZ0, MZ1 = 64, 95, 16, 39
  local function machine(x, y, z)
    if x < MX0 or x > MX1 or z < MZ0 or z > MZ1 then return nil end
    -- the desk: a top at 10 on a dark plinth, the knee recess in front
    local DESK = 10
    if z >= MZ0 + 2 and z <= MZ1 - 1 and y < DESK then
      if y == DESK - 1 then return sw(TILE_DK, 5) end
      if z == MZ1 - 1 and y >= 2 and y <= 6 and x > MX0 + 3 and x < MX1 - 3 then
        return sw(STEEL, 2 + (x % 6 == 0 and 2 or 0))                    -- vents
      end
      return sw(STEEL, 3 + hash(floor(x / 8), y, 2) % 2)
    end
    -- the monitor on the left: a box, its screen to the south
    if x >= MX0 + 2 and x <= MX0 + 13 and z >= MZ0 + 3 and z <= MZ0 + 13 and y >= DESK and y < DESK + 12 then
      if z == MZ0 + 13 and x >= MX0 + 4 and x <= MX0 + 11 and y >= DESK + 2 and y <= DESK + 9 then
        return sw(SCREEN, 4 + ((y + floor(x / 2)) % 4 == 0 and 2 or 0))
      end
      return sw(TILE, 3 + (y == DESK + 11 and 2 or 0))
    end
    -- the recorder on the right: lower, a slot and three lamps on its face
    if x >= MX0 + 16 and x <= MX1 - 2 and z >= MZ0 + 4 and z <= MZ0 + 15 and y >= DESK and y < DESK + 8 then
      if z == MZ0 + 15 then
        if y == DESK + 4 and x >= MX0 + 18 and x <= MX1 - 6 then return sw(INK, 2) end   -- the slot
        if y == DESK + 6 and (x == MX1 - 4 or x == MX1 - 6 or x == MX1 - 8) then
          return sw(x == MX1 - 4 and RED or SCREEN, 6)
        end
      end
      return sw(STEEL, 4 + (y == DESK + 7 and 2 or 0))
    end
    return nil
  end

  local function at(x, y, z)
    if x < 0 or x >= W or z < 0 or z >= D or y < 0 then return nil end
    local c, r = floor(x / 8), floor(z / 8)
    local cx, cy = floor(x / 16), floor(z / 16)
    local k = kind[cy * cw + cx]
    local v = tile(c, r)
    if k == "wall" then
      if not solid[cy * cw + cx] then return nil end
      if style == "ninja" then
        if y > 0 then return nil end
        return boards(x, z)
      end
      return block(x, y, z, wallH)
    end
    if k == "back" then
      local lz = z % 16
      local b = block(x, y, z, BACK_H)
      -- the dojo's two scrolls, hung on the back wall's face
      if style == "dojo" and lz == 15 and (v == 52 or v == 67 or v == 82 or v == 83) then
        local sx = x % 16
        if sx >= 2 and sx <= 13 then
          if y == 23 or y == 5 then return sw(TIMBER, 5) end               -- the rods
          if y > 5 and y < 23 then
            if sx == 2 or sx == 13 then return sw(TILE_DK, 4) end          -- the mount
            -- brush strokes down the middle, two columns of them
            if (sx == 6 or sx == 9) and y >= 8 and y <= 20 and hash(floor(x / 16), y, sx) % 3 ~= 0 then
              return sw(INK, 2)
            end
            if (sx == 7 or sx == 10) and y >= 9 and y <= 19 and hash(floor(x / 16), y, sx + 1) % 4 == 0 then
              return sw(INK, 3)
            end
            return sw(PAPER, 5)
          end
        end
      end
      return b
    end
    if DOOR[v] then
      -- the gate into the Champion's room: two posts, two leaves between
      local gx = x - doorX0[r]          -- the door is two cells wide, 32
      local lz = z % 16
      if lz >= 6 and lz <= 9 then
        if gx <= 2 or gx >= 29 then
          if y < 26 then return sw(GRANITE_LT, 3 + (y >= 24 and 2 or 0)) end
          return nil
        end
        if y >= 22 and y < 26 then return sw(GRANITE_LT, 4) end            -- the lintel
        if lz >= 7 and lz <= 8 and y < 22 then
          if gx == 15 or gx == 16 then return sw(GOLD, 3) end              -- the meeting
          if y == 10 and (gx == 13 or gx == 18) then return sw(GOLD, 6) end -- the handles
          if (gx - 3) % 6 == 0 or y % 7 == 0 then return sw(RED, 3) end
          return sw(RED, 4 + hash(floor(gx / 6), floor(y / 7), 8) % 2)
        end
      end
      if y > 0 then return nil end
      return boards(x, z)
    end
    if STAIRS[v] then
      -- four steps rising east into the wall, each four wide, four high
      local c0 = (STAIRS[tile(c - 1, r)] and c - 1) or c
      local sx = x - c0 * 8
      local top = 4 * (floor(sx / 4) + 1)
      if y < top then
        if y == top - 1 then return sw(GRANITE_LT, 5) end
        if sx % 4 == 3 then return sw(GRANITE, 1) end
        return sw(GRANITE, 3 + hash(floor(sx / 4), y, 2) % 2)
      end
      return nil
    end
    if MACHINE[v] then
      local m = machine(x, y, z)
      if m then return m end
      if y > 0 then return nil end
      return tiles(x, z)
    end
    if y > 0 then return nil end
    if DRAWN[v] then return nil end
    if style == "hall" then return tiles(x, z) end
    -- Koga's invisible walls (31) stay invisible; the drawing tells them
    -- from the floor only by a fainter stripe, so the boards under them
    -- run the other way, north-south
    if style == "ninja" and v == 31 then return boards(z, x) end
    return boards(x, z)
  end
  return at, W, D
end

function Kit.model(sp, t, mapId)
  local style = Kit.MAPS[mapId]
  if not style then return nil, "not a gym hall: " .. tostring(mapId) end
  local at, W, D = build(t, style)
  local m, why = Lib.model(Kit, sp, t, at, OPEN)
  if not m then return nil, why end
  m.W, m.xmin, m.xmax, m.zmax, m.ytop = W, 0, W - 1, D - 1, BACK_H + 1
  return m
end

return Kit
