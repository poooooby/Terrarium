-- Pre-cache: warm what the player is about to see BEFORE they see it.
--
-- Stages, a queue fed by where the player can go next, and a budgeted
-- pump. The one real stage, "bake" (bottom of this file), builds the maps
-- one step away straight into the 3D build cache (lib/BuildCache.lua), so
-- walking or warping into them restores from disk instead of building.
--
-- It warms the CACHE, not ChunkMesher's in-memory meshes, and that is what
-- made it possible: ChunkMesher.setLive drops every queued job for a map
-- outside the live sets, and a door the player has not taken yet is
-- outside them, so a warmed mesh used to be cancelled before it landed
-- (PRECACHE-PLAN.md, step 2). A cache file outlives all of that.
--
-- On whenever the 3D CACHE row is. With it OFF, the old dev gate: the
-- PRECACHE row is only offered while Perf is on (tools/profiler).
--
-- Aesthetics only, like everything here: a stage may build GPU/CPU data
-- the renderer would have built anyway. It must never touch the world,
-- the save, input or anything the game reads back.

local V = ...

local ModSetting = V.require("ModSetting")
local Perf = V.require("Perf")

local PreCache = {}

PreCache.setting = ModSetting.new("precache", "PRECACHE",
                                  { "off", "on" }, { "OFF", "ON" })

function PreCache.row() return PreCache.setting:row() end

-- Offered only during a profiling session: a dev preview, not a feature.
function PreCache.offered() return Perf.enabled end

-- `force` is for a driver: the row is not in the mod-manager schema unless
-- Perf was on at LOAD, and a harness turns Perf on after load.
PreCache.force = false

-- ON for players whenever the 3D build cache is (lib/BuildCache.lua): the
-- one real stage below bakes the maps one step away INTO that cache, so it
-- has nothing to do without it. Otherwise the old dev gate.
local function cacheOn()
  local ok, BuildCache = pcall(V.require, "BuildCache")
  return ok and BuildCache and BuildCache.enabled()
end

function PreCache.enabled()
  if cacheOn() then return true end
  if not Perf.enabled then return false end
  if PreCache.force then return true end
  local ok, v = pcall(PreCache.setting.get, PreCache.setting)
  return ok and v == "on"
end

-- Per-frame budgets. COVERED is a warp's fade or a menu: nothing of the
-- world on screen, so it can spend more -- the same reasoning as
-- ChunkMesher's COVERED_SLICE, and kept well under it so the two together
-- still fit a covered frame. IDLE is what an ordinary visible frame can
-- spare after ChunkMesher's own idle slice.
-- IDLE was 1 ms while the only stage did no work. A real bake of a kit
-- map is seconds of CPU, which at 1 ms a frame would take minutes; 3 ms
-- still sits beside a 3D frame, and the pump only runs at all once the
-- mesher has nothing of its own queued (see pump).
PreCache.IDLE_SLICE = 0.003
PreCache.COVERED_SLICE = 0.008

local clock = (love and love.timer and love.timer.getTime) or os.clock

-- ------------------------------------------------------------- stages
--
-- PreCache.stage{
--   name = "atlas",                    -- unique; also the Perf label suffix
--   key  = function(mapId) -> string|nil   -- the cache key this stage
--                                          -- would fill for that map, or
--                                          -- nil when it has nothing to do
--   done = function(key) -> bool        -- already warm (cheap, no work)
--   warm = function(mapId, key) -> step  -- returns a function that does
--                                          -- one slice and returns true
--                                          -- when the key is warm
-- }
--
-- A step must do a bounded amount of work per call: the pump checks the
-- clock between calls, never inside one.

local stages = {}
local byName = {}

function PreCache.stage(def)
  assert(type(def) == "table" and def.name and def.key and def.warm,
         "PreCache.stage needs name, key and warm")
  if byName[def.name] then return byName[def.name] end
  def.label = "precache." .. def.name
  stages[#stages + 1] = def
  byName[def.name] = def
  return def
end

-- ------------------------------------------------------------- queue

local queue = {}        -- array of { stage, mapId, key, step }
local queued = {}       -- stage.name .. "\0" .. key -> true
local fromMap = nil     -- the map id the queue was built for
PreCache.stats = { queued = 0, warmed = 0, skipped = 0, dropped = 0 }

-- Where the player can go from `map` in one move: the maps joined across
-- its edges and the destinations of its warps. LAST_MAP is the engine's
-- "back where you came from" marker, not a map.
function PreCache.reachable(map)
  local out, seen = {}, {}
  local def = map and map.def
  if not def then return out end
  for _, c in pairs(def.connections or {}) do
    local id = type(c) == "table" and c.map
    if id and not seen[id] then seen[id] = true; out[#out + 1] = id end
  end
  for _, w in ipairs(def.warps or {}) do
    local id = w.destMap
    if id and id ~= "LAST_MAP" and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  return out
end

-- Called every update with the current map. Rebuilds the queue only when
-- the map changed: what is reachable from here replaces what was
-- reachable from the last map, and anything no longer reachable is
-- dropped rather than finished.
function PreCache.notice(map)
  if not PreCache.enabled() then return end
  local id = map and map.id
  if id == fromMap then return end
  fromMap = id
  PreCache.stats.dropped = PreCache.stats.dropped + #queue
  queue, queued = {}, {}
  for _, dest in ipairs(PreCache.reachable(map)) do
    for _, st in ipairs(stages) do
      local okK, key = pcall(st.key, dest)
      if okK and key then
        local tag = st.name .. "\0" .. key
        local okD, warm = true, false
        if st.done then okD, warm = pcall(st.done, key) end
        if okD and warm then
          PreCache.stats.skipped = PreCache.stats.skipped + 1
        elseif not queued[tag] then
          queued[tag] = true
          queue[#queue + 1] = { stage = st, mapId = dest, key = key }
        end
      end
    end
  end
  PreCache.stats.queued = #queue
end

-- Run queued steps until the slice is spent. A step that errors is
-- dropped (and logged once per stage) rather than retried forever.
local warned = {}
function PreCache.pump(covered)
  if #queue == 0 or not PreCache.enabled() then return end
  -- the map on screen and its neighbours always come first: nothing is
  -- pre-built while the mesher still has a job of its own
  local okC, ChunkMesher = pcall(V.require, "ChunkMesher")
  if okC and ChunkMesher and ChunkMesher.pending() > 0 then return end
  local deadline = clock() + (covered and PreCache.COVERED_SLICE
                              or PreCache.IDLE_SLICE)
  while #queue > 0 and clock() < deadline do
    local job = queue[1]
    local st = job.stage
    local t0 = Perf.now()
    if not job.step then
      local ok, step = pcall(st.warm, job.mapId, job.key)
      job.step = ok and step or false
      if not ok and not warned[st.name] then
        warned[st.name] = true
        print("[precache] " .. st.name .. " warm failed: " .. tostring(step))
      end
    end
    local finished = true
    if job.step then
      local ok, fin = pcall(job.step)
      finished = (not ok) or fin == true
      if not ok and not warned[st.name] then
        warned[st.name] = true
        print("[precache] " .. st.name .. " step failed: " .. tostring(fin))
      end
    end
    Perf.add(st.label, t0)
    if finished then
      table.remove(queue, 1)
      PreCache.stats.warmed = PreCache.stats.warmed + 1
    end
  end
  PreCache.stats.queued = #queue
end

function PreCache.pending() return #queue end

-- For Diag and probes: one line of state.
function PreCache.report()
  local s = PreCache.stats
  return ("precache %s from=%s queued=%d warmed=%d skipped=%d dropped=%d stages=%d")
    :format(PreCache.enabled() and "ON" or "off", tostring(fromMap),
            #queue, s.warmed, s.skipped, s.dropped, #stages)
end

function PreCache.reset()
  queue, queued, fromMap = {}, {}, nil
  PreCache.stats = { queued = 0, warmed = 0, skipped = 0, dropped = 0 }
end

-- ------------------------------------------------------- the bake stage
--
-- "bake": build each map one step away (its connections, then the places
-- its doors lead) straight into the 3D build cache, using what the frame
-- has left over (ChunkMesher.bake). Walking or warping into it then
-- restores in about a second instead of building for several -- and the
-- door fade, when there is one, covers even that.
--
-- `done` asks the cache, so a map already built (on the title's ALL, on an
-- earlier visit, in an earlier session) costs one index lookup. A step is
-- one resume of the bake's coroutine under the build budget; the pump
-- checks the clock between steps.
PreCache.reached = {}
PreCache.stage{
  name = "bake",
  key = function(mapId) return mapId end,
  done = function(key)
    local okB, BuildVeil = pcall(V.require, "BuildVeil")
    if not okB then return true end
    local map = BuildVeil.mapFor(key)
    return (not map) or BuildVeil.current(map)
  end,
  warm = function(mapId)
    local BuildVeil = V.require("BuildVeil")
    local ChunkMesher = V.require("ChunkMesher")
    local Budget = V.require("BuildBudget")
    local map = BuildVeil.mapFor(mapId)
    if not map then return nil end
    local masks = BuildVeil.masksFor(mapId)
    local co = coroutine.create(function() ChunkMesher.bake(map, masks) end)
    return function()
      Budget.begin(co, 0.002)
      local ok, err = coroutine.resume(co)
      Budget.finish()
      if not ok then error(err) end
      if coroutine.status(co) == "dead" then
        PreCache.reached[mapId] = true
        return true
      end
      return false
    end
  end,
}

return PreCache
