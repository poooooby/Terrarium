-- The driver-side half of profiling: attaches to a running Terrarium from
-- a POKEPORT_DRIVER probe, turns lib/Perf.lua on, wraps the mod's big
-- per-frame entry points, and (optionally) streams every span into an
-- AppleCake trace you can open in ui.perfetto.dev or about://tracing.
--
-- Driver-side on purpose. A probe runs unsandboxed -- real io, require,
-- love.thread -- while the mod itself would need the manifest's `compute`
-- permission just to start AppleCake's writer thread. So nothing here
-- ships into a player's session: the mod only carries Perf's dark hooks.
--
--   local Harness = dofile(<dir>/Harness.lua)
--   local H = Harness.attach(game, { trace = true, out = OUT })
--   ... per frame: H.frame() ...
--   H.finish("bench")                 -- report + JSON (+ trace copy)
--
-- Wrapping is by table field, so it sees calls that look the function up
-- at call time (`VoxelScene.render(...)`, which is how main.lua calls all
-- of these) and misses any caller that cached a local copy. The attach log
-- lists which wraps took; a missing one is a renamed function, not a bug
-- in the measurement.

local Harness = {}

local function here()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:gsub("\\", "/"):match("^(.*)/[^/]*$") or ".")
end
Harness.DIR = here()

-- module -> entry points. Per-draw-call functions are left out
-- (Voxel3D.draw, ShadowMap.draw and TerrainAtlas.forMap run once per mesh
-- -- 686k and 200k calls in one bench, most of a 90 MB trace): Perf's own note -- a span there costs more than
-- what it measures, and the frame ring covers them in aggregate.
Harness.WRAPS = {
  VoxelScene = { "render", "prefetch" },
  ChunkMesher = { "pump", "request" },
  Trees3D = { "draw" },
  Weather = { "update", "draw", "present" },
  AmbientLife = { "update", "draw", "drawWorld" },
  AmbientSound = { "update" },
  WindFX = { "update", "draw", "drawWorld" },
  RayFX = { "apply" },
  GroundFX = { "update", "step" },
  TiltShift = { "update", "apply" },
  Bloom = { "apply" },
  Water = { "step" },
  WaterBody = { "refresh" },
  PuddleFX = { "step", "draw" },
  Skyline = { "draw", "frame" },
  StreetLamps = { "draw" },
  DayNight = { "update" },
  Structures = { "forMap" },
  Buildings = { "build" },
  -- each kit's model constructor: called once per template (or per
  -- placement), never per frame, and it runs without yielding -- so its
  -- span is pure CPU, and the overrun.* labels point here
  BridgeKit = { "model" }, CryptKit = { "model" }, FenceKit = { "model" },
  LavenderCivicKit = { "model" }, LavenderGroundKit = { "model" },
  LavenderHomeKit = { "model" }, LavenderHouseKit = { "model" },
  LavenderTowerKit = { "model" }, LedgeKit = { "model" }, ReefKit = { "model" },
  RoomKit = { "model" }, ShopKit = { "model" }, TowerKit = { "model" },
  VermilionHomeKit = { "model" }, VermilionHouseKit = { "model" },
  TerrainAtlas = { "forSprite" },
  OverworldBattle = { "update" },
  BattleScene = { "render" },
}

-- What VoxelScene.render calls through module tables, for GARBAGE
-- attribution only (DS_GC_DEEP=1 in gc_budget_probe): render is ~95% of a
-- frame's garbage and its own helpers are locals no wrap can reach, so
-- this splits it by the module calls it makes. Far too hot for a timing
-- run -- Voxel3D.draw alone runs per mesh -- and a GC run is not timed.
Harness.DEEP_WRAPS = {
  Mat4 = { "mul", "translate", "scale", "rotateX", "rotateY", "rotateZ" },
  Voxel3D = { "draw", "drawGroup", "drawWater", "glass", "seams", "casterMatrix",
              "shadowMatrix", "beginScene", "endScene", "beginShadows",
              "endShadows", "shopMats", "reef", "lantern", "packedShade",
              "beginGhost", "endGhost" },
  ShadowMap = { "draw", "drawGroup", "snug", "groundReach", "begin", "finish" },
  ChunkMesher = { "peek", "spriteInBox", "spriteGroups", "flowers", "grass" },
  SpriteBillboards = { "shadowQuad", "mesh" },
  TerrainAtlas = { "forMap" },
  MarioCam = { "camera", "lens", "focusXZ", "viewYaw", "orbitAngle" },
  Sky = { "haze", "dress" },
  DayNight = { "windowLight", "tint", "lampColor" },
  Underpass = { "matches" },
}

-- Which export is the mod: TERRARIUM_ID wins, then the ids this fork has
-- shipped under. Returns id, lib (the mod's V namespace).
function Harness.findMod(game)
  local exports = game and game.mods and game.mods.exports
  if not exports then return nil end
  local want = os.getenv("TERRARIUM_ID")
  local ids = want and { want } or { "TERRARIUM2", "TERRARIUM" }
  for _, id in ipairs(ids) do
    local e = exports[id]
    if e and e.lib and e.lib.require then return id, e.lib, e end
  end
  return nil
end

local function openLog(out, name)
  local f = assert(io.open(out .. "/" .. name .. ".log", "w"))
  return function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    f:write(table.concat(parts, " "), "\n")
    f:flush()
  end, f
end

-- opts:
--   out    directory for logs/JSON/trace (default DS_PROBE_DIR or ".")
--   name   log/trace basename (default "profile")
--   trace  true: start an AppleCake session now (needs love.thread)
--   wraps  override Harness.WRAPS
-- label -> true once wrapped. Perf.wrap is not idempotent (a second wrap
-- would wrap the wrapper and count every call twice), and the play driver
-- attaches once per F8 session.
Harness.wrapped = {}

local function attachCore(game, opts)
  opts = opts or {}
  local H = {}
  H.out = opts.out or os.getenv("DS_PROBE_DIR") or "."
  H.name = opts.name or "profile"
  H.log, H.logFile = openLog(H.out, H.name)

  local id, V, exp = Harness.findMod(game)
  if not V then
    H.log("FAIL: no Terrarium export (set TERRARIUM_ID?)")
    return nil, "no mod"
  end
  H.id, H.V = id, V
  H.log("mod:", id, "version:", tostring(exp.version))

  local Perf = V.require("Perf")
  H.Perf = Perf
  Perf.reset()
  Perf.enabled = true

  local took, missed = {}, {}
  for mod, fns in pairs(opts.wraps or Harness.WRAPS) do
    local ok, M = pcall(V.require, mod)
    for _, fn in ipairs(fns) do
      local label = mod .. "." .. fn
      if Harness.wrapped[label] then
        took[#took + 1] = label   -- an earlier session's wrap still stands
      elseif ok and type(M) == "table" and type(M[fn]) == "function"
          and Perf.wrap(M, fn, label) then
        Harness.wrapped[label] = true
        took[#took + 1] = label
      else
        missed[#missed + 1] = label
      end
    end
  end
  table.sort(took); table.sort(missed)
  H.log("wrapped:", table.concat(took, " "))
  if #missed > 0 then H.log("not found:", table.concat(missed, " ")) end
  return H
end

-- ------------------------------------------------------------ AppleCake

local AC = nil
local reuse = {}   -- one profile table per label: no per-span garbage

function Harness.appleCake()
  if AC then return AC end
  AC = dofile(Harness.DIR .. "/applecake_loader.lua")(true)
  return AC
end

-- Forward Perf spans into the trace with their real start times. Perf's
-- clock and AppleCake's are both love.timer.getTime (AppleCake in
-- microseconds), so a span lands exactly where it ran.
local function sink(label, t0)
  local p = reuse[label]
  if p then
    p = AC.profile(label, nil, p)
  else
    p = AC.profile(label)
    reuse[label] = p
  end
  p.start = t0 * 1e6
  AC.stopProfile(p)
end

function Harness.startTrace(self_or_nil)
  local H = self_or_nil
  local ac = Harness.appleCake()
  Harness.traceFile = (H and H.name or "profile") .. ".json"
  ac.beginSession(Harness.traceFile, "Terrarium")
  ac.setThreadName("main")
  Harness.tracing = true
end

-- ---------------------------------------------------------------- frames

local frameProfile = nil
local lastKb = nil

-- Call once per driver yield. Stamps a "frame" span in the trace from the
-- previous call to this one, and graphs Lua memory and its per-frame
-- delta (a negative delta is a collection, not a free lunch).
function Harness.frame()
  if not Harness.tracing then return end
  if frameProfile then AC.stopProfile(frameProfile) end
  frameProfile = AC.profile("frame", nil, frameProfile)
  local kb = collectgarbage("count")
  AC.countMemory("kilobyte")
  if lastKb then
    AC.counter("lua KB delta", { kb = kb - lastKb })
  end
  lastKb = kb
end

function Harness.mark(name)
  if Harness.tracing then AC.mark(name, "p") end
end

-- Copy the finished trace out of the engine's save dir next to the logs:
-- AppleCake's thread writes through love.filesystem, the driver reads it
-- back the same way and writes it with io.
local function copyTrace(H)
  local ok, body = pcall(love.filesystem.read, Harness.traceFile)
  if not (ok and body) then
    H.log("trace: could not read back", Harness.traceFile, "from",
          love.filesystem.getSaveDirectory())
    return nil
  end
  local dest = H.out .. "/" .. Harness.traceFile
  local f = io.open(dest, "wb")
  if not f then return nil end
  f:write(body); f:close()
  return dest
end

function Harness.stopTrace(H)
  if not Harness.tracing then return nil end
  if frameProfile then AC.stopProfile(frameProfile); frameProfile = nil end
  H.Perf.sink = nil
  AC.endSession()
  Harness.tracing = false
  local dest = copyTrace(H)
  if dest then H.log("trace:", dest, "(open in ui.perfetto.dev)") end
  return dest
end

-- Perf.printReport prints through the MOD's print (the sandbox gives the
-- mod its own), which a driver cannot redirect -- so the same report is
-- formatted here from Perf's tables and written to the driver's log.
function Harness.report(H)
  local Perf, log = H.Perf, H.log
  local function line(name, f)
    log(("%-28s n=%5d avg=%6.2f p50=%6.2f p95=%6.2f p99=%6.2f worst=%8.2f >16.7=%4d >33.3=%3d")
      :format(name, f.n, f.avg, f.p50, f.p95, f.p99, f.worst, f.over16, f.over33))
  end
  log("")
  log("---- frames (ms)")
  line("all", Perf.frameStats())
  for _, seg in ipairs(Perf.segments) do line(seg.name, Perf.frameStats(seg.frames)) end
  log("---- labels (ms, by total)")
  local order = {}
  for _, l in ipairs(Perf.order) do order[#order + 1] = l end
  table.sort(order, function(a, b) return Perf.labels[a].total > Perf.labels[b].total end)
  for _, l in ipairs(order) do
    local s = Perf.labels[l]
    log(("%-34s n=%7d total=%10.1f max=%8.2f%s"):format(l, s.n, s.total * 1000,
        s.max * 1000, (s.kb or 0) ~= 0 and ("  kb=%.1f"):format(s.kb) or ""))
  end
end

-- Report to the log, write the Perf JSON beside it, close any
-- trace. meta is stamped into the JSON (machine, config) so two runs can
-- be diffed with what made them different in view.
function Harness.finish(H, meta)
  Harness.stopTrace(H)
  local Perf = H.Perf
  Harness.report(H)
  local m = meta or {}
  m.mod = H.id
  local f = io.open(H.out .. "/" .. H.name .. "_perf.json", "w")
  if f then f:write(Perf.toJson(m)); f:close() end
  H.log("perf json:", H.out .. "/" .. H.name .. "_perf.json")
  Perf.enabled = false
  H.logFile:close()
end

-- Method sugar so a driver can write H:frame(), H:finish(meta), ...
local methods = {
  frame = function() return Harness.frame() end,
  mark = function(_, name) return Harness.mark(name) end,
  startTrace = function(H) return Harness.startTrace(H) end,
  stopTrace = function(H) return Harness.stopTrace(H) end,
  finish = function(H, meta) return Harness.finish(H, meta) end,
}


-- Hook the sink once a trace is running. Separate from startTrace so a GC
-- run (GcMeter) can keep Perf on with NO sink: AppleCake's own encoding
-- allocates, and would be charged to whatever span it forwarded.
function Harness.useSink(H, on)
  H.Perf.sink = (on and Harness.tracing) and sink or nil
end
methods.useSink = Harness.useSink

function Harness.attach(game, opts)
  local H, err = attachCore(game, opts)
  if not H then return nil, err end
  setmetatable(H, { __index = methods })
  if opts and opts.trace then
    Harness.startTrace(H)
    Harness.useSink(H, true)
  end
  return H
end

return Harness
