-- LOAD FADE: hold the screen black while an interior's 3D model is still
-- being built, then fade the room in -- instead of showing the flat 2D
-- floor for a second or three and popping the diorama in on top of it.
--
-- Only the rooms where that pop was worth hiding: the Pokemon Tower's
-- floors and every Poke Mart (Celadon's department store floors included).
-- tests/cold_cost_probe.lua measured a first visit, no door fade:
--
--   LAVENDER_MART      ~1.0 s of 2D before the room appeared
--   VIRIDIAN_MART      ~1.1 s
--   POKEMON_TOWER_1F   ~2.6 s      POKEMON_TOWER_2F  ~2.8 s
--   any of them again   instant (ChunkMesher keeps recent maps)
--
-- How it shortens the wait as well as hiding it: while the veil is up
-- nothing of the world is on screen, so ChunkMesher gets its COVERED
-- slice (main.lua update) -- the same fat slice a door's fade earns.
--
-- Aesthetics only, like everything here: the veil is a picture laid over
-- the WORLD layer. The game keeps running underneath it -- text boxes and
-- menus the engine draws on top stay visible, input is never touched --
-- and it gives up after MAX_HOLD whatever the builder is doing, so a map
-- that cannot build is never a black screen for good.

local V = ...

local ModSetting = V.require("ModSetting")
local ChunkMesher = V.require("ChunkMesher")

local LoadVeil = {}

LoadVeil.setting = ModSetting.new("loadveil", "ROOM FADE",
                                  { "on", "off" }, { "ON", "OFF" })

function LoadVeil.row() return LoadVeil.setting:row() end

function LoadVeil.enabled()
  local ok, v = pcall(LoadVeil.setting.get, LoadVeil.setting)
  return not ok or v ~= "off"
end

-- Longest the screen is ever held black, and how long the room takes to
-- fade in once it is built. MAX_HOLD is generous for the Tower (its cold
-- build is ~2.7 s at the ordinary slice and shorter under the veil's
-- covered one) and short enough that a stuck build reads as a slow door,
-- not a crash.
LoadVeil.MAX_HOLD = 5.0
LoadVeil.FADE = 0.35

-- Which maps wear it. Gen 1 ids: POKEMON_TOWER_1F..7F, and every Mart --
-- VIRIDIAN_MART .. CINNABAR_MART plus CELADON_MART_1F..5F / _ROOF /
-- _ELEVATOR -- all carry "_MART".
function LoadVeil.wanted(id)
  if type(id) ~= "string" then return false end
  return id:match("^POKEMON_TOWER_") ~= nil or id:find("_MART", 1, true) ~= nil
end

local clock = (love and love.timer and love.timer.getTime) or os.clock

-- state: nil (nothing to do), or { id, phase = "hold" | "fade", t }
local veil = nil
local lastId = nil

local function built(map)
  return ChunkMesher.peek(map, false) ~= nil
end

-- Called once per drawn world frame with the map on screen. Arms the veil
-- on arrival at a wanted map whose room is not built yet; a room that is
-- already built (a revisit) gets no veil at all, so the engine's own door
-- fade is the only fade the player sees.
function LoadVeil.note(map)
  local id = map and map.id
  if id ~= lastId then
    lastId = id
    veil = nil
    if id and LoadVeil.enabled() and LoadVeil.wanted(id) and not built(map) then
      veil = { id = id, phase = "hold", t = clock() }
    end
  end
  if not veil then return end
  local now = clock()
  if veil.phase == "hold" and (built(map) or now - veil.t > LoadVeil.MAX_HOLD) then
    veil.phase, veil.t = "fade", now
  elseif veil.phase == "fade" and now - veil.t >= LoadVeil.FADE then
    veil = nil
  end
end

-- True while the screen is held fully black: the world is hidden, so a
-- build may take the covered slice.
function LoadVeil.holding()
  return veil ~= nil and veil.phase == "hold"
end

-- 0 (no veil) .. 1 (black).
function LoadVeil.alpha()
  if not veil then return 0 end
  if veil.phase == "hold" then return 1 end
  local k = (clock() - veil.t) / LoadVeil.FADE
  if k >= 1 then return 0 end
  -- ease out: most of the room arrives early, the last of the dark lingers
  return (1 - k) * (1 - k)
end

-- A black canvas the size of the scene, for the frames the 3D pass has
-- nothing to hand back (VoxelScene.render returned nil): returning it
-- instead of nil is what keeps the flat 2D floor off the screen.
local blackCanvas, blackW, blackH = nil, 0, 0
function LoadVeil.blank(w, h)
  if not (love.graphics and love.graphics.newCanvas) then return nil end
  if not blackCanvas or blackW ~= w or blackH ~= h then
    local ok, c = pcall(love.graphics.newCanvas, w, h)
    if not ok then return nil end
    blackCanvas, blackW, blackH = c, w, h
  end
  local prev = love.graphics.getCanvas()
  love.graphics.setCanvas(blackCanvas)
  love.graphics.clear(0, 0, 0, 1)
  if prev then love.graphics.setCanvas(prev) else love.graphics.setCanvas() end
  return blackCanvas
end

-- Lay the veil over `canvas` at the current alpha. Returns the canvas, so
-- it chains like the other present() passes.
function LoadVeil.present(canvas)
  local a = LoadVeil.alpha()
  if a <= 0 or not canvas then return canvas end
  local g = love.graphics
  local prev = g.getCanvas()
  local ok = pcall(g.setCanvas, canvas)
  if ok then
    g.push("all")
    g.origin()
    g.setShader()
    g.setColor(0, 0, 0, a)
    local w, h = canvas:getDimensions()
    g.rectangle("fill", 0, 0, w, h)
    g.pop()
  end
  if prev then g.setCanvas(prev) else g.setCanvas() end
  return canvas
end

return LoadVeil
