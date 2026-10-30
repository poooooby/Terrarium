-- Voxel world mode: the insides of houses, lived in.
--
-- A Gen 1 room with two people in it is a room with two people in it and
-- nothing else. This puts one thing in a home, and it is purely a drawing.
--
-- (An earlier cut also stood a sleeping house pet on the floor as a real map
-- entity. Real entities block and answer A, which is gameplay, and this mod
-- only changes what the world LOOKS like -- so it is gone.)
--
-- ------- the steam
--
-- A mug left on the table, still hot. Wisps rising off it, drawn in the same
-- overlay pass the ambient life composites through, anchored to the world by
-- the same camera. Nothing stands anywhere: no cell, no entity, no collision,
-- no interaction -- if you walk through where the steam is, you walk through
-- it, because it is steam.
--
-- WHERE a table is comes from the mod's own shape profile rather than from a
-- list of coordinates. Every interior tileset this mod has hand-authored
-- names its `table` and `counter` tiles by id (data/voxel_heights.lua), for
-- the entirely different purpose of extruding them to the right height, and
-- that list answers "is there a tabletop at this cell" for free. So a mug
-- lands on a table in a house nobody wrote a line of code about, and a total
-- conversion that adds its own tileset gets mugs on its tables by pinning
-- them the way it already had to.
--
-- Same hash, same reason: the same table in the same house always has the
-- mug, and the one across the room never does.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")
local TileShape = V.require("TileShape")

local Map = require("src.world.Map")

local Interiors = {}

Interiors.setting = ModSetting.new("indoor", "HOME DETAIL",
                                   { "on", "off" }, { "ON", "OFF" })

function Interiors.enabled()
  return Interiors.setting:get() == "on"
end

function Interiors.row()
  return Interiors.setting:row()
end

local function game()
  return require("src.core.Game")
end

-- ------- which rooms are HOMES
--
-- By tileset, which is the only honest way: Gen 1 has no "this is a house"
-- flag, but it does have one tileset per KIND of interior, and the house
-- tilesets are drawn as houses -- dining tables, bookcases, beds, a TV. A gym
-- is a gym, a Mart is a shop, a cave is a cave, and none of them has anybody
-- living in it.
--
-- The three named oddities are the same rooms with their own atlases: Red's
-- two floors, and the Beach House by the Cycling Road.
Interiors.HOMES = {
  HOUSE = true,
  REDS_HOUSE_1 = true,
  REDS_HOUSE_2 = true,
  BEACH_HOUSE = true,
}

local function isHome(map)
  if not (map and map.def) then return false end
  if Map.isOutdoor(map.def) then return false end
  local tileset = map.def.tileset
  return (tileset and Interiors.HOMES[tileset]) and true or false
end

-- ------- the hash
--
-- A small, stable string hash, and it is stable ACROSS SESSIONS on purpose:
-- love.math.random is seeded per run, and a mug that moved tables between two
-- sessions would read as a spawner rather than somebody's kitchen. Nothing here is
-- cryptographic and nothing needs to be -- it only has to give the same
-- answer for the same name every time, on every machine.
--
-- Multiply-and-add rather than the usual xor mix, and deliberately: this runs
-- on LuaJIT, where `~` is not an operator and `//` is not a division, so the
-- 5.3 spelling of a hash is a syntax error rather than a slow path. Plain
-- arithmetic under 2^31 stays exact in a double and needs no bit library.
local function hash(text, salt)
  local h = 5381
  local s = tostring(text) .. "|" .. tostring(salt or "")
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 2147483647
  end
  return h
end

-- 0..1 from a hash, for a threshold.
local function unit(h) return (math.floor(h / 977) % 100000) / 100000 end

-- ------- the mugs
--
-- Every cell in the room whose TOP-LEFT tile the shape profile calls a
-- tabletop. The top-left tile is the one the cell rules already judge a cell
-- by (TileShape.at), and a table's own art puts its surface there.
--
-- Recomputed on arrival and cached per map, because it cannot change: the
-- shapes come from the tileset and the tiles come from the block layer, and
-- a block edit invalidates far more than this (ChunkMesher.refresh) already.
local TABLETOPS = { table = true, counter = true }

local function mugCells(map)
  local ok, shapes = pcall(TileShape.forMap, map)
  if not ok or not shapes then return {} end
  local out = {}
  for cy = 0, map.heightCells - 1 do
    for cx = 0, map.widthCells - 1 do
      local tile = map:tileAt(cx * 2, cy * 2)
      local shape = tile and shapes[tile]
      if shape and TABLETOPS[shape.class] then
        -- about one tabletop cell in four carries a mug: a table with a mug
        -- on every square of it is a canteen, not a kitchen
        local h = hash(map.id, "mug" .. cx .. "," .. cy)
        if unit(h) < 0.26 then
          out[#out + 1] = {
            -- a spot ON the top rather than in the middle of the cell, and
            -- the tabletop's own drawn height (shape.h) is where it stands
            x = cx * 16 + 4 + (h % 7),
            z = cy * 16 + 4 + (math.floor(h / 7) % 7),
            y = (shape.h or 12) + 1,
            seed = unit(hash(map.id, "phase" .. cx .. "," .. cy)) * 6.2831,
          }
        end
      end
    end
  end
  return out
end

-- ------- state
--
-- Nothing here is written to a save. The mugs exist for as long as the map
-- they belong to is loaded, and are rebuilt from the same hash the next time
-- -- which is the same thing as persisting them, without persisting anything.
local state = { mapId = nil, mugs = {} }

-- ------- per-frame
--
-- Rides the voxel pipeline's update hook like every other clock in this mod,
-- and does almost nothing on almost every frame: the room only changes when
-- the MAP does, so the whole body below is one comparison in the common case.
local failed = false

local function tick()
  local Game = game()
  local ow = Game and Game.overworld
  if not (ow and ow.map and ow.player) then return end
  if Game.stack and Game.stack:top() ~= ow then return end
  if ow.transitioning then return end
  if ow.runner and ow.runner.isRunning and ow.runner:isRunning() then return end

  if not (Interiors.enabled() and isHome(ow.map)) then
    state.mapId, state.mugs = nil, {}
    return
  end

  if state.mapId == ow.map.id then return end
  state.mapId = ow.map.id
  state.mugs = mugCells(ow.map)
end

function Interiors.update()
  if failed then return end
  local ok, err = pcall(tick)
  if ok then return end
  failed = true
  V.mod.log:warn("interior life failed: %s -- the houses are empty for this "
                 .. "session", tostring(err))
  state.mapId, state.mugs = nil, {}
end

-- ------- the draw
--
-- Inside the voxel overlay pass (main.lua's drawWorld), with the same project
-- function the ambient life anchors through: `scale` is pixels per world
-- pixel at the camera's focus and project's third return is this point's own
-- perspective correction, so a mug across the room is smaller than the one on
-- the near table for the same reason the table is.
--
-- Cel-shaded flat: hard-edged rectangles in two
-- tones, no gradients and no soft alpha ramps except the one that carries a
-- wisp away. A soft-edged puff of steam over a world made of voxels would be
-- the one thing on screen that looked like a photograph.
Interiors.STEAM_COLOR = { 0.93, 0.95, 0.98 }
Interiors.MUG_LIGHT = { 0.85, 0.86, 0.88 }
Interiors.MUG_DARK = { 0.42, 0.44, 0.50 }

-- How far a wisp climbs before it is gone, in world pixels, how long that
-- takes, and how many are in the air at once. Slow, because steam is slow and
-- a fast one reads as smoke -- but SHORT, which the probe's shots decided: at
-- eleven pixels the column climbed clear of the cup and read as four specks
-- floating near a mug rather than as steam coming off one. A plume has to
-- touch the thing it is coming out of.
Interiors.RISE = 7
Interiors.PERIOD = 2.0
Interiors.WISPS = 4

-- and how solid a wisp gets at its strongest. The first cut was 0.62, which
-- over a dark interior ceiling came out at about a fifth of white -- present
-- in the draw-call count and invisible on the screen, which is the exact
-- failure the battle HUD's ink taught this mod to check for.
Interiors.STEAM_ALPHA = 0.92

function Interiors.draw(project, scale)
  if state.mapId == nil then return end
  if #state.mugs == 0 then return end
  local g = love.graphics
  local prevBlend, prevAlpha = g.getBlendMode()
  g.setBlendMode("alpha")
  local now = (love.timer and love.timer.getTime()) or 0

  -- ------- the mugs, and what is coming off them
  for _, mug in ipairs(state.mugs) do
    local sx, sy, ps = project(mug.x, mug.y, mug.z)
    if sx then
      local s = math.max(1, scale * (ps or 1))

      -- the cup: a two-tone block with a lighter rim, which is every mug
      -- anybody ever drew at this size
      local c = Interiors.MUG_DARK
      g.setColor(c[1], c[2], c[3], 0.95)
      g.rectangle("fill", sx - s * 1.1, sy - s * 2.2, s * 2.2, s * 2.2)
      c = Interiors.MUG_LIGHT
      g.setColor(c[1], c[2], c[3], 0.95)
      g.rectangle("fill", sx - s * 1.1, sy - s * 2.2, s * 2.2, s * 0.7)

      -- and four wisps, each a quarter of a cycle behind the last, so the
      -- column is continuous rather than a puff that restarts
      c = Interiors.STEAM_COLOR
      local n = Interiors.WISPS
      for i = 0, n - 1 do
        local k = ((now / Interiors.PERIOD) + mug.seed + i / n) % 1
        local hgt = k * Interiors.RISE
        local wx = math.sin((mug.seed + k * 6.2831) * 1.7) * 1.6 * k
        local wsx, wsy = project(mug.x + wx, mug.y + 1 + hgt, mug.z)
        if wsx then
          -- fades IN as it leaves the cup and OUT as it climbs, so no wisp
          -- ever pops on or off -- but it is at FULL strength through the
          -- middle third rather than only touching it at one instant, which
          -- is the difference between steam and a flicker
          local a = math.min(1, k * 6, (1 - k) * 2.2) * Interiors.STEAM_ALPHA
          local d = math.max(1, s * (0.6 + k * 0.8))
          g.setColor(c[1], c[2], c[3], a)
          g.rectangle("fill", wsx - d * 0.5, wsy - d * 0.5, d, d)
        end
      end
    end
  end

  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
end

return Interiors
