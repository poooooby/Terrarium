-- Garbage measurement for a probe driver: how many KB of Lua garbage a
-- frame makes, and which wrapped entry point made it.
--
-- The method is the one the particle probes already trust
-- (tests/leaf_fall_probe.lua): stop the collector, read
-- collectgarbage("count") before and after, restart. With the collector
-- stopped every byte allocated stays counted, so the delta IS the
-- allocation -- with it running, a cycle landing mid-frame reads as a
-- negative frame. Windows are short (WINDOW frames) and end in a full
-- collect, so a stopped collector can never run memory away.
--
-- Attribution rides on Perf.trackAlloc: every function the harness wrapped
-- records the KB its calls allocated (inclusive of wrapped callees). What
-- no wrapped function claims is still in the frame total -- the gap
-- between the two is "allocated somewhere unwrapped", which is itself a
-- finding.
--
-- One known lie, from PARTICLES-PLAN.md: collectgarbage("count") also
-- counts LuaJIT's trace objects, so a frame that compiles a new trace
-- reads heavier than the garbage it made. DS_GC_JITOFF=1 runs the window
-- with the JIT off for clean attribution; the report says which mode ran.
-- Compare like with like.
--
--   local GcMeter = dofile(<dir>/GcMeter.lua)
--   local gc = GcMeter.new(H)          -- H from Harness.attach, NO sink
--   gc:window("pallet:stand", 120)     -- yields 120 frames, returns stats

local GcMeter = {}
GcMeter.__index = GcMeter

GcMeter.WINDOW = 120

function GcMeter.new(H)
  local self = setmetatable({}, GcMeter)
  self.H = H
  self.Perf = H.Perf
  self.jitOff = (os.getenv("DS_GC_JITOFF") or "") ~= ""
              and os.getenv("DS_GC_JITOFF") ~= "0"
  self.top = tonumber(os.getenv("DS_GC_TOP") or "") or 12
  self.results = {}   -- array of { name, frames, kbFrame..., labels }
  -- AppleCake's encoding allocates on the main thread; a span it forwards
  -- would be charged for it. GC runs never stream.
  H.Perf.sink = nil
  return self
end

local function sortedCopy(t)
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  table.sort(c)
  return c
end

local function pct(sorted, p)
  local n = #sorted
  if n == 0 then return 0 end
  local i = math.max(1, math.min(n, math.ceil(p * n)))
  return sorted[i]
end

-- Run `frames` driver yields with the collector stopped. `step(i)` (if
-- given) runs before each yield -- the walk input, a camera nudge.
function GcMeter:window(name, frames, step)
  frames = frames or GcMeter.WINDOW
  local Perf = self.Perf
  -- start clean: no garbage from the previous window, and the label
  -- tables reset so this window's attribution is its own
  collectgarbage("collect")
  collectgarbage("collect")
  local savedLabels, savedOrder = Perf.labels, Perf.order
  Perf.labels, Perf.order = {}, {}
  if self.jitOff and jit then jit.off(); jit.flush() end
  Perf.trackAlloc = true
  collectgarbage("stop")

  local per = {}
  local prev = collectgarbage("count")
  for i = 1, frames do
    if step then step(i) end
    coroutine.yield()
    local now = collectgarbage("count")
    per[i] = now - prev
    prev = now
  end

  collectgarbage("restart")
  Perf.trackAlloc = false
  if self.jitOff and jit then jit.on() end
  local labels, order = Perf.labels, Perf.order
  Perf.labels, Perf.order = savedLabels, savedOrder
  collectgarbage("collect")

  local sorted = sortedCopy(per)
  local total = 0
  for i = 1, #per do total = total + per[i] end
  local r = {
    name = name,
    frames = frames,
    kbPerFrame = total / frames,
    p50 = pct(sorted, 0.50),
    p95 = pct(sorted, 0.95),
    worst = sorted[#sorted] or 0,
    jit = not self.jitOff,
    labels = {},
  }
  for _, lbl in ipairs(order) do
    local s = labels[lbl]
    r.labels[#r.labels + 1] = {
      label = lbl,
      kbPerFrame = s.kb / frames,
      callsPerFrame = s.n / frames,
      msPerFrame = s.total * 1000 / frames,
    }
  end
  table.sort(r.labels, function(a, b) return a.kbPerFrame > b.kbPerFrame end)
  self.results[#self.results + 1] = r
  self:logWindow(r, self.top)
  return r
end

function GcMeter:logWindow(r, top)
  local log = self.H.log
  log(("[gc] %-28s %6.1f KB/frame  p50=%6.1f p95=%6.1f worst=%7.1f  (%d frames, jit %s)")
    :format(r.name, r.kbPerFrame, r.p50, r.p95, r.worst, r.frames,
            r.jit and "on" or "off"))
  local claimed = 0
  for i, l in ipairs(r.labels) do
    if i <= (top or 12) then
      log(("[gc]     %-34s %7.2f KB/frame  %5.1f calls  %6.2f ms")
        :format(l.label, l.kbPerFrame, l.callsPerFrame, l.msPerFrame))
    end
  end
  -- top-level labels only would be exact; wrapped callees nest inside
  -- render/update, so "claimed" is an upper bound -- report the biggest
  -- single label against the frame instead of a misleading sum
  local big = r.labels[1]
  if big then claimed = big.kbPerFrame end
  log(("[gc]     largest wrapped span covers %.0f%% of the frame's garbage")
    :format(r.kbPerFrame > 0 and 100 * claimed / r.kbPerFrame or 0))
end

local function q(s) return '"' .. tostring(s):gsub('[%c"\\]', "_") .. '"' end
local function n(x) return ("%.4f"):format(x) end

function GcMeter:toJson(meta)
  local parts = { "{\"meta\":{" }
  local m = {}
  for k, v in pairs(meta or {}) do
    m[#m + 1] = q(k) .. ":" .. (type(v) == "number" and n(v) or q(v))
  end
  table.sort(m)
  parts[#parts + 1] = table.concat(m, ",") .. "},\"windows\":["
  local ws = {}
  for _, r in ipairs(self.results) do
    local ls = {}
    for _, l in ipairs(r.labels) do
      ls[#ls + 1] = ("{\"label\":%s,\"kbPerFrame\":%s,\"callsPerFrame\":%s,\"msPerFrame\":%s}")
        :format(q(l.label), n(l.kbPerFrame), n(l.callsPerFrame), n(l.msPerFrame))
    end
    ws[#ws + 1] = ("{\"name\":%s,\"frames\":%d,\"kbPerFrame\":%s,\"p50\":%s,\"p95\":%s,\"worst\":%s,\"jit\":%s,\"labels\":[%s]}")
      :format(q(r.name), r.frames, n(r.kbPerFrame), n(r.p50), n(r.p95),
              n(r.worst), tostring(r.jit), table.concat(ls, ","))
  end
  parts[#parts + 1] = table.concat(ws, ",") .. "]}"
  return table.concat(parts)
end

function GcMeter:write(path, meta)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(self:toJson(meta)); f:close()
  self.H.log("gc json:", path)
  return true
end

return GcMeter
