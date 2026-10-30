-- Shared scene driving for the profiling probes (profile_bench,
-- gc_budget, cold_cost): boot to free roam, pin the config, put the
-- player on a map, stand still or pace. One copy, so every probe measures
-- the same world -- a number from one probe is only comparable to another
-- if the scene under it was the same.
--
-- The config pin is buildings_perf_probe's (day, weather off, RES rung 2,
-- pipeline level 4, vsync off), for the reasons its header gives: vsync on
-- measures the monitor, and weather/time move the scene under the meter.

local Scenes = {}

-- The bench walk: the towns with Breno's kits plus two plain ones, so a
-- regression in the kit path and one in the plain mesh path both show.
Scenes.MAPS = {
  { id = "PALLET_TOWN", x = 10, y = 11 },
  { id = "LAVENDER_TOWN", x = 10, y = 10 },
  { id = "VERMILION_CITY", x = 10, y = 10 },
  { id = "ROUTE_12", x = 10, y = 15, walk = false },   -- grass, no party
  { id = "CELADON_CITY", x = 10, y = 10 },
}

function Scenes.wait(n) for _ = 1, n do coroutine.yield() end end

function Scenes.tap(game, b)
  game.input.pressQueue[#game.input.pressQueue + 1] = b
  coroutine.yield()
end

-- Straight to free roam, without the title or Oak's speech, and without
-- touching any save: Game:startNewGame{intro=false} is the engine's own
-- "a mod starts a game on its own terms" entry, which builds a fresh
-- in-memory save and pushes the overworld. Nothing writes it to disk --
-- Gen 1 saves only from the START menu or the Hall of Fame -- so a probe
-- run can never clobber the player's slot (tools/profiler/run.py checks
-- the slot timestamps all the same).
--
-- The fresh save has no party, so the walks stay in towns: a wild
-- encounter with nobody to send out is not a scene worth measuring.
function Scenes.boot(game, log)
  local n = 0
  while not (game.stack and game.stack:top()) do
    coroutine.yield(); n = n + 1
    if n > 900 then log("FAIL: the title never came up"); return false end
  end
  local ok, err = pcall(game.startNewGame, game, { intro = false })
  if not ok then log("FAIL: startNewGame:", tostring(err)); return false end
  if game.save and game.save.player then game.save.player.name = "BENCH" end
  n = 0
  while not (game.overworld and game.stack:top() == game.overworld
             and game.overworld.map) do
    coroutine.yield(); n = n + 1
    if n > 600 then
      log("FAIL: no free roam after startNewGame; top screen:",
          Scenes.describe(game.stack:top()))
      Scenes.shot(os.getenv("DS_PROBE_DIR") or ".", "boot_stuck")
      return false
    end
  end
  log("boot: free roam on", tostring(game.overworld.map.id), "after", n, "frames")
  return true
end

-- A screen's identity for a log line: its declared name if it has one,
-- else the first few string fields, which is usually enough to tell a
-- save picker from a dialogue box.
function Scenes.describe(top)
  if type(top) ~= "table" then return tostring(top) end
  local mt = getmetatable(top)
  local name = top.name or top.id or top.kind
               or (mt and type(mt.__index) == "table" and (mt.__index.name or mt.__index.__name))
  if name then return tostring(name) end
  local bits = {}
  for k, v in pairs(top) do
    if type(v) == "string" and #bits < 4 then bits[#bits + 1] = k .. "=" .. v end
  end
  return "{" .. table.concat(bits, " ") .. "}"
end

function Scenes.pin(V, log)
  V.require("DayNight").setting:sync("day")
  V.require("Weather").setting:sync("off")
  V.require("Quality").setting:sync(2)
  require("src.render.Pipelines").setLevel("terrarium_voxel", 4)
  love.window.setVSync(0)
  local ww, wh = love.graphics.getDimensions()
  log(("config: day, weather off, RES 2, level 4, vsync off, %dx%d"):format(ww, wh))
end

function Scenes.unpin()
  love.window.setVSync(1)
end

-- The scene is READY when this map's full mesh is cached and nothing is
-- queued or still stamping trees -- not merely when the voxel pass has run
-- once (the old Voxel3D.lampLights test), which is true from the first map
-- on and let a probe screenshot Vermilion's 2D fallback while its kits
-- were still building.
local function ready(game, V, id, guard)
  local ChunkMesher = V.require("ChunkMesher")
  local Trees3D = V.require("Trees3D")
  for f = 1, guard or 1800 do
    local map = game.overworld.map
    if map and map.id == id and ChunkMesher.peek(map, false)
        and ChunkMesher.pending() == 0
        and (Trees3D.buildsInFlight == nil or Trees3D.buildsInFlight() == 0) then
      return f
    end
    coroutine.yield()
  end
  return nil
end
Scenes.ready = ready

local function settle(game, guard)
  local last, stable = nil, 0
  for _ = 1, guard or 1200 do
    local p = game.overworld.player
    local cur = p and (tostring(p.cellX) .. "," .. tostring(p.cellY)) or "?"
    if cur == last then stable = stable + 1 else stable, last = 0, cur end
    if stable >= 45 then return true end
    coroutine.yield()
  end
  return false
end

-- The nearest walkable cell to (x, y) on the loaded map, searched in
-- growing squares -- a hand-picked coordinate that lands on a roof (10,10
-- in Vermilion is the Pokemon Center) puts the camera somewhere no player
-- ever stands.
local function walkableNear(map, x, y)
  if not (map and map.isWalkableCell) then return x, y end
  for r = 0, 12 do
    for dy = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local ok, w = pcall(map.isWalkableCell, map, x + dx, y + dy)
          if ok and w then return x + dx, y + dy end
        end
      end
    end
  end
  return x, y
end

-- Put the player on c = { id, x, y }. `quiet` skips every wait (the
-- cold-cost probe counts the frames straight after the switch itself).
function Scenes.visit(game, V, c, log, quiet)
  local function go(x, y)
    return pcall(function() game.overworld:setMap(c.id, x, y, "down") end)
  end
  local ok, err = go(c.x, c.y)
  if not ok then log(c.id, "FAIL: setMap error", tostring(err)); return false end
  local x, y = walkableNear(game.overworld.map, c.x, c.y)
  if x ~= c.x or y ~= c.y then
    go(x, y)
    c.x, c.y = x, y   -- remembered, so the second pass lands on the same cell
  end
  if quiet then return true end
  if game.overworld.map.id ~= c.id then
    log(("%s FAIL: landed on %s"):format(c.id, tostring(game.overworld.map.id)))
    return false
  end
  if not ready(game, V, c.id) then log(c.id, "FAIL: scene never finished building"); return false end
  settle(game)
  Scenes.wait(60)
  return true
end

-- A step function for GcMeter/bench loops: pace right then left in
-- 48-frame legs, so the player walks (meshes stream, grass crushes, dust
-- kicks) without leaving the map.
function Scenes.pacer(game)
  return function(i)
    local leg = math.floor((i - 1) / 48) % 2
    game.input.pressQueue[#game.input.pressQueue + 1] = leg == 0 and "right" or "left"
  end
end

-- One frame's screenshot to <out>/<name>.png, for the before/after pixel
-- compare (tools/profiler/imgdiff.py). captureScreenshot fires at the end
-- of the frame, so yield once after asking.
function Scenes.shot(out, name)
  local done = false
  love.graphics.captureScreenshot(function(img)
    local ok, data = pcall(function() return img:encode("png"):getString() end)
    if ok and data then
      local f = io.open(out .. "/" .. name .. ".png", "wb")
      if f then f:write(data); f:close() end
    end
    done = true
  end)
  for _ = 1, 3 do
    coroutine.yield()
    if done then break end
  end
end

return Scenes
